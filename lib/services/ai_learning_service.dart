import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'auth_service.dart';

class AiLearningService {
  AiLearningService({http.Client? client, String? endpoint})
      : _client = client ?? http.Client(),
        _endpoint = endpoint ?? _defaultEndpoint;

  static const _baseUrl = String.fromEnvironment(
    'RESUMER_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );
  static const _defaultEndpoint = '$_baseUrl/v1/learning/questions';
  static const _gradingEndpoint = '$_baseUrl/v1/learning/grade';
  final http.Client _client;
  final String _endpoint;

  Future<List<CourseTestQuestion>> generateQuestions({
    required String courseTitle,
    required String topic,
    required String context,
    List<String> weakTopics = const [],
    int count = 5,
    bool finalTest = false,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null)
      throw StateError('Sign in to generate practice questions.');
    final token = AuthService.instance.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Could not verify the current Supabase session.');
    }
    final response = await _client
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'courseTitle': courseTitle,
            'topic': topic,
            'context': context.substring(0, context.length.clamp(0, 12000)),
            'weakTopics': weakTopics.take(20).toList(),
            'count': count.clamp(1, 15),
            'finalTest': finalTest,
          }),
        )
        .timeout(const Duration(seconds: 45));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
          'Question generation service returned ${response.statusCode}.');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic>)
      throw const FormatException('Invalid response');
    final payload = _extractPayload(decoded);
    final items = payload['questions'];
    if (items is! List) throw const FormatException('Questions missing');
    return [
      for (final item in items)
        if (item is Map<String, dynamic> &&
            item['question'] is String &&
            item['options'] is List &&
            (item['options'] as List).length == 4 &&
            item['correctIndex'] is int)
          CourseTestQuestion(
            question: item['question'] as String,
            options: List<String>.from(item['options'] as List),
            correctIndex: item['correctIndex'] as int,
            topic: item['topic'] as String? ?? topic,
          ),
    ];
  }

  Future<Map<String, dynamic>> gradeFinalTest({
    required String courseId,
    required List<int> answers,
  }) async {
    final user = AuthService.instance.currentUser;
    if (user == null) throw StateError('Sign in to submit the final test.');
    final token = AuthService.instance.accessToken;
    if (token == null || token.isEmpty) {
      throw StateError('Could not verify the current Supabase session.');
    }
    final response = await _client
        .post(
          Uri.parse(_gradingEndpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'courseId': courseId, 'answers': answers}),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Final test service returned ${response.statusCode}.');
    }
    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! Map<String, dynamic> || decoded['score'] is! int) {
      throw const FormatException('Invalid final test result.');
    }
    return decoded;
  }

  Map<String, dynamic> _extractPayload(Map<String, dynamic> body) {
    final candidates = body['candidates'];
    if (candidates is! List || candidates.isEmpty) return body;
    final parts = (candidates.first as Map)['content']?['parts'];
    if (parts is! List || parts.isEmpty || parts.first['text'] is! String) {
      throw const FormatException('Question response has no generated text');
    }
    final parsed = jsonDecode(parts.first['text'] as String);
    if (parsed is! Map<String, dynamic>)
      throw const FormatException('Invalid generated JSON');
    return parsed;
  }
}
