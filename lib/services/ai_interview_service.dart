import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class AiInterviewException implements Exception {
  const AiInterviewException(this.message, {this.transient = false});

  final String message;

  /// True when a retry may succeed — timeouts, rate limits, server errors,
  /// or a malformed model response.
  final bool transient;

  @override
  String toString() => message;
}

/// A single AI-generated interview question.
class InterviewQuestion {
  const InterviewQuestion({required this.text, this.focusArea});

  final String text;

  /// The skill or theme the question probes (e.g. "System design"), when the
  /// model supplied one.
  final String? focusArea;
}

/// AI-generated feedback on a completed interview transcript.
class InterviewAnalysis {
  const InterviewAnalysis({required this.score, required this.summary});

  /// Overall performance score, 0-100.
  final int score;

  /// A short written summary/result of how the candidate did.
  final String summary;
}

/// Generates mock-interview questions with Gemini 2.5 Flash.
///
/// SECURITY: this service never ships a hardcoded Gemini key. By default it
/// calls the local/production FastAPI proxy (`/v1/interview`), which holds
/// `GEMINI_API_KEY` server-side. The direct-to-Gemini "embedded" path only
/// activates when a developer explicitly supplies `GEMINI_API_KEY` via
/// `--dart-define` for local testing — it is never on by default, so nothing
/// sensitive is compiled into release builds.
class AiInterviewService {
  AiInterviewService({
    http.Client? client,
    String? proxyUrl,
    String? analysisProxyUrl,
  })  : _client = client ?? http.Client(),
        _proxyEndpoint = proxyUrl ?? _configuredProxyUrl,
        _analysisEndpoint = analysisProxyUrl ?? _configuredAnalysisProxyUrl,
        _useEmbeddedApi = client == null &&
            proxyUrl == null &&
            _embeddedGeminiApiKey.isNotEmpty;

  static const model = 'gemini-2.5-flash';
  static const _configuredApiBaseUrl = String.fromEnvironment(
    'RESUMER_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const _configuredProxyUrl = String.fromEnvironment(
    'RESUMER_AI_INTERVIEW_PROXY_URL',
    defaultValue: '$_configuredApiBaseUrl/v1/interview',
  );
  static const _configuredAnalysisProxyUrl = String.fromEnvironment(
    'RESUMER_AI_INTERVIEW_ANALYSIS_PROXY_URL',
    defaultValue: '$_configuredApiBaseUrl/v1/interview/analyze',
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
  final String _analysisEndpoint;
  final bool _useEmbeddedApi;

  bool get isConfigured => _useEmbeddedApi
      ? _embeddedGeminiApiKey.isNotEmpty
      : _proxyEndpoint.isNotEmpty;

  bool get usesSecureProxy => !_useEmbeddedApi && _proxyEndpoint.isNotEmpty;

  Future<List<InterviewQuestion>> generateQuestions({
    required String targetRole,
    required String experienceLevel,
    required String interviewType,
    required int questionCount,
  }) async {
    if (!isConfigured) {
      throw const AiInterviewException(
        'Gemini is not configured. Add a secure AI proxy or a development key.',
      );
    }

    final requestData = {
      'model': model,
      'targetRole': targetRole,
      'experienceLevel': experienceLevel,
      'interviewType': interviewType,
      'questionCount': questionCount,
    };

    AiInterviewException? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _attemptGenerate(requestData);
      } on AiInterviewException catch (error) {
        lastError = error;
        if (!error.transient || attempt == 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
    }
    throw lastError!;
  }

  /// Scores a completed interview transcript and returns a short summary.
  ///
  /// [questions] and [answers] must be the same length and in the order the
  /// interview was conducted; an empty/unanswered question is fine and is
  /// noted as such to the model.
  Future<InterviewAnalysis> analyzeInterview({
    required String targetRole,
    required String interviewType,
    required List<String> questions,
    required List<String> answers,
  }) async {
    if (!isConfigured) {
      throw const AiInterviewException(
        'Gemini is not configured. Add a secure AI proxy or a development key.',
      );
    }

    final requestData = {
      'model': model,
      'targetRole': targetRole,
      'interviewType': interviewType,
      'transcript': [
        for (var i = 0; i < questions.length; i++)
          {
            'question': questions[i],
            'answer': i < answers.length ? answers[i] : '',
          },
      ],
    };

    AiInterviewException? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _attemptAnalyze(requestData);
      } on AiInterviewException catch (error) {
        lastError = error;
        if (!error.transient || attempt == 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 1200));
      }
    }
    throw lastError!;
  }

  Future<InterviewAnalysis> _attemptAnalyze(
    Map<String, Object> requestData,
  ) async {
    final http.Response response;
    try {
      response = await _callAnalysisProxy(requestData).timeout(
        const Duration(seconds: 45),
      );
    } on TimeoutException {
      throw const AiInterviewException(
        'Gemini took too long to respond. Please try again.',
        transient: true,
      );
    } on http.ClientException {
      throw const AiInterviewException(
        'Could not reach the interview service. Check your connection.',
        transient: true,
      );
    } on Exception catch (e) {
      throw AiInterviewException(
        'Network error contacting interview service: $e',
        transient: true,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final status = response.statusCode;
      throw AiInterviewException(
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
      return _parseAnalysis(payload);
    } on AiInterviewException {
      rethrow;
    } on Object {
      throw const AiInterviewException(
        'Gemini returned an unexpected response. Please try again.',
        transient: true,
      );
    }
  }

  Future<http.Response> _callAnalysisProxy(Map<String, Object> requestData) {
    if (_useEmbeddedApi) {
      final prompt = _embeddedAnalysisPrompt(
        targetRole: requestData['targetRole'] as String,
        interviewType: requestData['interviewType'] as String,
        transcript: requestData['transcript'] as List,
      );
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
            'temperature': 0.3,
            'responseMimeType': 'application/json',
          },
        }),
      );
    }
    return _client.post(
      Uri.parse(_analysisEndpoint),
      headers: {
        'Content-Type': 'application/json',
        if (_configuredApiKey.isNotEmpty) 'X-API-Key': _configuredApiKey,
      },
      body: jsonEncode(requestData),
    );
  }

  String _embeddedAnalysisPrompt({
    required String targetRole,
    required String interviewType,
    required List transcript,
  }) {
    final buffer = StringBuffer();
    for (var i = 0; i < transcript.length; i++) {
      final entry = transcript[i];
      final question = entry is Map ? entry['question'] : '';
      final answer = entry is Map ? entry['answer'] : '';
      final answerText =
          (answer is String && answer.trim().isNotEmpty) ? answer : '(no answer given)';
      buffer.writeln('Q${i + 1}: $question\nA${i + 1}: $answerText\n');
    }
    return '''You are Resumer's AI interview coach. Score the candidate's mock $interviewType interview for the role of $targetRole.
Return JSON only with this exact shape:
{"score": <integer 0-100>, "summary": "string"}

Rules:
- "score" reflects overall performance across clarity, relevance, and depth of the answers. Unanswered questions should lower the score.
- "summary" is 2-4 sentences describing the candidate's performance, key strengths, and what to improve. Write it directly to the candidate ("you").
- Do not invent facts the candidate did not say.

Transcript:
$buffer''';
  }

  InterviewAnalysis _parseAnalysis(Map<String, dynamic> payload) {
    final rawScore = payload['score'];
    final score = switch (rawScore) {
      final int value => value,
      final double value => value.round(),
      final String value => int.tryParse(value.trim()) ?? -1,
      _ => -1,
    };
    final summary = _string(payload['summary']);
    if (score < 0 || score > 100 || summary.isEmpty) {
      throw const AiInterviewException(
        'Gemini returned an unusable interview analysis. Please try again.',
        transient: true,
      );
    }
    return InterviewAnalysis(score: score.clamp(0, 100), summary: summary);
  }

  Future<List<InterviewQuestion>> _attemptGenerate(
    Map<String, Object> requestData,
  ) async {
    final http.Response response;
    try {
      response = await _callProxy(requestData).timeout(
        const Duration(seconds: 45),
      );
    } on TimeoutException {
      throw const AiInterviewException(
        'Gemini took too long to respond. Please try again.',
        transient: true,
      );
    } on http.ClientException {
      throw const AiInterviewException(
        'Could not reach the interview service. Check your connection.',
        transient: true,
      );
    } on Exception catch (e) {
      throw AiInterviewException(
        'Network error contacting interview service: $e',
        transient: true,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final status = response.statusCode;
      throw AiInterviewException(
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
      final requestedCount = requestData['questionCount'] as int;
      return _parseQuestions(payload, requestedCount);
    } on AiInterviewException {
      rethrow;
    } on Object {
      throw const AiInterviewException(
        'Gemini returned an unexpected response. Please try again.',
        transient: true,
      );
    }
  }

  Future<http.Response> _callProxy(Map<String, Object> requestData) {
    if (_useEmbeddedApi) {
      final prompt = _embeddedPrompt(
        targetRole: requestData['targetRole'] as String,
        experienceLevel: requestData['experienceLevel'] as String,
        interviewType: requestData['interviewType'] as String,
        questionCount: requestData['questionCount'] as int,
      );
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
            'temperature': 0.6,
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

  String _embeddedPrompt({
    required String targetRole,
    required String experienceLevel,
    required String interviewType,
    required int questionCount,
  }) {
    return '''You are Resumer's AI interview coach, running a mock $interviewType interview.
Return JSON only with this exact shape:
{"questions":[{"question":"string","focusArea":"string"}]}

Rules:
- Generate exactly $questionCount questions.
- Target role: $targetRole.
- Candidate experience level: $experienceLevel.
- Match question difficulty and depth to the experience level.
- For a "technical" interview, ask concrete role-specific technical questions.
- For a "behavioral" interview, ask questions that invite a STAR-style answer.
- For a "hr" interview, focus on motivation, culture fit, and communication.
- For a "mixed" interview, blend behavioral, technical, and HR questions.
- Keep each question a single, clear sentence.
- "focusArea" is a short 1-3 word label for the skill or theme the question probes.''';
  }

  Map<String, dynamic> _extractPayload(Map<String, dynamic> body) {
    if (!body.containsKey('candidates')) return body;
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AiInterviewException(
        'Gemini did not return any interview questions.',
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

  List<InterviewQuestion> _parseQuestions(
    Map<String, dynamic> payload,
    int requestedCount,
  ) {
    final questionData = payload['questions'];
    if (questionData is! List || questionData.isEmpty) {
      throw const AiInterviewException(
        'Gemini could not generate interview questions for this role.',
        transient: true,
      );
    }
    final questions = <InterviewQuestion>[];
    for (final value in questionData) {
      if (value is! Map<String, dynamic>) continue;
      final text = _string(value['question']);
      if (text.isEmpty) continue;
      questions.add(
        InterviewQuestion(
          text: text,
          focusArea: _string(value['focusArea']).isEmpty
              ? null
              : _string(value['focusArea']),
        ),
      );
    }
    if (questions.isEmpty) {
      throw const AiInterviewException(
        'Gemini returned no usable interview questions. Please try again.',
        transient: true,
      );
    }
    return questions.take(requestedCount).toList();
  }

  String _messageForStatus(int status) => switch (status) {
        400 => 'Gemini could not process this interview request.',
        401 ||
        403 =>
          'The Gemini credential is invalid, blocked, or restricted.',
        429 => 'Gemini rate limit reached. Please wait and try again.',
        _ when status >= 500 => 'Gemini is temporarily unavailable.',
        _ => 'Question generation failed with service error $status.',
      };

  String _string(Object? value, {String fallback = ''}) {
    return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
  }

  void dispose() => _client.close();
}
