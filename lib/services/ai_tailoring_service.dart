import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/matching.dart';
import '../models/models.dart';

class AiTailoringException implements Exception {
  const AiTailoringException(this.message, {this.transient = false});

  final String message;

  /// True when a retry may succeed — timeouts, rate limits, server errors,
  /// or a malformed model response. Auto-apply runs several jobs back to
  /// back, so transient Gemini hiccups are retried once instead of failing
  /// the whole run.
  final bool transient;

  @override
  String toString() => message;
}

/// Produces grounded resume suggestions with Gemini 2.5 Flash.
///
/// SECURITY: this service never ships a hardcoded Gemini key. By default it
/// calls the local/production FastAPI proxy (`/v1/tailor`), which holds
/// `GEMINI_API_KEY` server-side. The direct-to-Gemini "embedded" path only
/// activates when a developer explicitly supplies `GEMINI_API_KEY` via
/// `--dart-define` for local testing — it is never on by default, so nothing
/// sensitive is compiled into release builds.
class AiTailoringService {
  AiTailoringService({
    http.Client? client,
    String? proxyUrl,
  })  : _client = client ?? http.Client(),
        _proxyEndpoint = proxyUrl ?? _configuredProxyUrl,
        _useEmbeddedApi = client == null &&
            proxyUrl == null &&
            _embeddedGeminiApiKey.isNotEmpty;

  static const model = 'gemini-2.5-flash';
  static const _configuredApiBaseUrl = String.fromEnvironment(
    'RESUMER_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const _configuredProxyUrl = String.fromEnvironment(
    'RESUMER_AI_PROXY_URL',
    defaultValue: '$_configuredApiBaseUrl/v1/tailor',
  );
  static const _configuredApiKey = String.fromEnvironment('RESUMER_API_KEY');

  // No defaultValue here on purpose — a hardcoded fallback key was
  // previously shipped in source and has been removed. Pass
  // --dart-define=GEMINI_API_KEY=... only for local dev; production must
  // rely on the proxy above, which reads the key from the server's own
  // secret manager.
  static const _embeddedGeminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
  );
  static const _geminiEndpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';

  final http.Client _client;
  final String _proxyEndpoint;
  final bool _useEmbeddedApi;

  bool get isConfigured => _useEmbeddedApi
      ? _embeddedGeminiApiKey.isNotEmpty
      : _proxyEndpoint.isNotEmpty;

  bool get usesSecureProxy => !_useEmbeddedApi && _proxyEndpoint.isNotEmpty;

  Future<MatchReport> tailor({
    required String jobDescription,
    required List<CareerItem> evidence,
  }) async {
    if (!isConfigured) {
      throw const AiTailoringException(
        'Gemini is not configured. Add a secure AI proxy or a development key.',
      );
    }

    final evidencePayload = [
      for (final item in evidence)
        {
          'id': item.id,
          'type': item.type.label,
          'title': item.title,
          'subtitle': item.subtitle,
          'dateRange': item.dateRange,
          'bullets': item.bullets,
          'verified': item.verified,
        },
    ];
    final requestData = {
      'model': model,
      'jobDescription': jobDescription.substring(
        0,
        jobDescription.length.clamp(0, 16000),
      ),
      'careerEvidence': evidencePayload,
    };

    // Gemini latency is variable and the same run hits several jobs back to
    // back, so transient failures are retried once before giving up.
    AiTailoringException? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _attemptTailor(requestData, evidence);
      } on AiTailoringException catch (error) {
        lastError = error;
        if (!error.transient || attempt == 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
    }
    throw lastError!;
  }

  Future<MatchReport> _attemptTailor(
    Map<String, Object> requestData,
    List<CareerItem> evidence,
  ) async {
    final http.Response response;
    try {
      response = await _callProxy(requestData).timeout(
        const Duration(seconds: 45),
      );
    } on TimeoutException {
      throw const AiTailoringException(
        'Gemini took too long to respond. Please try again.',
        transient: true,
      );
    } on http.ClientException {
      throw const AiTailoringException(
        'Could not reach the tailoring service. Check your connection.',
        transient: true,
      );
    } on Exception catch (e) {
      throw AiTailoringException(
        'Network error contacting tailoring service: $e',
        transient: true,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final status = response.statusCode;
      throw AiTailoringException(
        _messageForStatus(status),
        transient: status == 429 || status >= 500,
      );
    }

    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      final payload = _extractPayload(decoded);
      return _parseReport(payload, evidence);
    } on AiTailoringException {
      rethrow;
    } on Object {
      throw const AiTailoringException(
        'Gemini returned an unexpected response. Please try again.',
        transient: true,
      );
    }
  }

  Future<http.Response> _callProxy(Map<String, Object> requestData) {
    if (_useEmbeddedApi) {
      final jobDescription = requestData['jobDescription'] as String;
      final evidence = (requestData['careerEvidence'] as List)
          .whereType<Map<String, Object?>>();
      final prompt = _embeddedPrompt(jobDescription, evidence);
      return _client.post(
        Uri.parse(_geminiEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _embeddedGeminiApiKey,
        },
        body: jsonEncode({
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.2,
            'responseMimeType': 'application/json',
          },
        }),
      );
    }
    return _client.post(
      Uri.parse(_proxyEndpoint),
      headers: {
        'Content-Type': 'application/json',
        if (_configuredApiKey.isNotEmpty) 'X-API-Key': _configuredApiKey,
      },
      body: jsonEncode(requestData),
    );
  }

  String _embeddedPrompt(
    String jobDescription,
    Iterable<Map<String, Object?>> evidence,
  ) {
    final evidenceText = evidence.map((item) => jsonEncode(item)).join('\n');
    return '''You are Resumer, a truthful resume tailoring assistant.
Return JSON only with this exact shape:
{"targetRole":"string","targetCompany":"string","summary":"string","score":0,"requirements":[{"skill":"string","status":"strong|partial|missing","evidence":"string"}],"suggestions":[{"skill":"string","currentBullet":"string","rewrittenBullet":"string","evidenceId":"string"}]}

Rules:
- Use only facts present in CAREER_EVIDENCE. Never invent employers, dates, metrics, tools, responsibilities, or achievements.
- Keep every number in a rewritten bullet exactly supported by its source evidence.
- Identify concrete requirements from the job description and mark strong only when career evidence supports them.
- Suggest at most 8 concise rewrites. If there is no safe rewrite, return an empty suggestions array.

JOB_DESCRIPTION:
$jobDescription

CAREER_EVIDENCE:
$evidenceText''';
  }

  Map<String, dynamic> _extractPayload(Map<String, dynamic> body) {
    if (!body.containsKey('candidates')) return body;
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AiTailoringException(
        'Gemini did not return a tailoring result.',
        transient: true,
      );
    }
    final candidate = candidates.first;
    if (candidate is! Map<String, dynamic>) {
      throw const FormatException('Invalid candidate');
    }
    final content = candidate['content'];
    if (content is! Map<String, dynamic>) {
      throw const FormatException('Missing content');
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      throw const FormatException('Missing parts');
    }
    final firstPart = parts.first;
    if (firstPart is! Map<String, dynamic> || firstPart['text'] is! String) {
      throw const FormatException('Missing text');
    }
    final result = jsonDecode(firstPart['text'] as String);
    if (result is! Map<String, dynamic>) {
      throw const FormatException('Invalid result JSON');
    }
    return result;
  }

  MatchReport _parseReport(
    Map<String, dynamic> payload,
    List<CareerItem> evidence,
  ) {
    final requirementData = payload['requirements'];
    if (requirementData is! List || requirementData.isEmpty) {
      throw const AiTailoringException(
        'Gemini could not identify concrete job requirements.',
        transient: true,
      );
    }
    final requirements = <Requirement>[];
    for (final value in requirementData) {
      if (value is! Map<String, dynamic>) continue;
      final status = _string(value['status']).toLowerCase();
      requirements.add(
        Requirement(
          skill: _string(value['skill'], fallback: 'Role requirement'),
          status: const {'strong', 'partial', 'missing'}.contains(status)
              ? status
              : 'partial',
          evidence: _string(
            value['evidence'],
            fallback: 'No direct supporting evidence found',
          ),
        ),
      );
    }

    final evidenceById = {for (final item in evidence) item.id: item};
    final suggestions = <TailoringSuggestion>[];
    final suggestionData = payload['suggestions'];
    if (suggestionData is List) {
      for (final value in suggestionData.take(8)) {
        if (value is! Map<String, dynamic>) continue;
        final evidenceId = _string(value['evidenceId']);
        final source = evidenceById[evidenceId];
        if (source == null) continue;
        final rewrite = _string(value['rewrittenBullet']);
        if (rewrite.isEmpty) continue;
        final sourceText = [
          source.title,
          source.subtitle ?? '',
          source.dateRange ?? '',
          ...source.bullets,
        ].join(' ');
        final supportedNumbers = _numbersIn(sourceText);
        final rewriteNumbers = _numbersIn(rewrite);
        if (rewriteNumbers
            .any((number) => !supportedNumbers.contains(number))) {
          continue;
        }
        suggestions.add(
          TailoringSuggestion(
            skill: _string(value['skill'], fallback: 'Targeted wording'),
            currentBullet: _string(
              value['currentBullet'],
              fallback:
                  source.bullets.isEmpty ? source.title : source.bullets.first,
            ),
            rewrittenBullet: rewrite,
            evidenceId: evidenceId,
          ),
        );
      }
    }

    final rawScore = payload['score'];
    final score = rawScore is num ? rawScore.round().clamp(0, 100) : 0;
    return MatchReport(
      requirements: requirements,
      score: score,
      backedCount: requirements.where((item) => item.status == 'strong').length,
      totalCount: requirements.length,
      suggestions: suggestions,
      summary: _string(payload['summary']),
      targetRole: _string(payload['targetRole'], fallback: 'Tailored role'),
      targetCompany:
          _string(payload['targetCompany'], fallback: 'Target company'),
      generatedByAi: true,
    );
  }

  String _messageForStatus(int status) => switch (status) {
        400 => 'Gemini could not process this resume and job description.',
        401 ||
        403 =>
          'The Gemini credential is invalid, blocked, or restricted.',
        429 => 'Gemini rate limit reached. Please wait and try again.',
        _ when status >= 500 => 'Gemini is temporarily unavailable.',
        _ => 'Tailoring failed with service error $status.',
      };

  String _string(Object? value, {String fallback = ''}) {
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }

  Set<String> _numbersIn(String value) {
    return RegExp(r'\d+(?:[.,]\d+)?%?')
        .allMatches(value)
        .map((match) => match.group(0)!)
        .toSet();
  }

  void dispose() => _client.close();
}
