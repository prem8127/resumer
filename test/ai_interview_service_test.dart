import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resumer_app/services/ai_interview_service.dart';

void main() {
  test('parses generated interview questions from the secure proxy',
      () async {
    final client = MockClient((request) async {
      expect(request.url.toString(), 'https://example.test/interview');
      final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      expect(requestBody['model'], AiInterviewService.model);
      expect(requestBody['targetRole'], 'Frontend Developer');
      expect(requestBody['questionCount'], 5);
      return http.Response(
        jsonEncode({
          'questions': [
            {'question': 'Tell me about a challenging bug you fixed.', 'focusArea': 'Debugging'},
            {'question': 'How do you approach responsive layouts?', 'focusArea': 'CSS'},
            {'question': 'Describe a time you disagreed with a teammate.', 'focusArea': 'Collaboration'},
            {'question': 'What is your experience with state management?', 'focusArea': 'Architecture'},
            {'question': 'How do you test UI components?', 'focusArea': 'Testing'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final service = AiInterviewService(
      client: client,
      proxyUrl: 'https://example.test/interview',
    );

    final questions = await service.generateQuestions(
      targetRole: 'Frontend Developer',
      experienceLevel: 'Mid-level',
      interviewType: 'Mixed',
      questionCount: 5,
    );

    expect(questions, hasLength(5));
    expect(questions.first.text, 'Tell me about a challenging bug you fixed.');
    expect(questions.first.focusArea, 'Debugging');
    service.dispose();
  });

  test('trims the question list to the requested count', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'questions': [
            {'question': 'Q1'},
            {'question': 'Q2'},
            {'question': 'Q3'},
          ],
        }),
        200,
      );
    });
    final service = AiInterviewService(
      client: client,
      proxyUrl: 'https://example.test/interview',
    );

    final questions = await service.generateQuestions(
      targetRole: 'Backend Developer',
      experienceLevel: 'Senior',
      interviewType: 'Technical',
      questionCount: 2,
    );

    expect(questions, hasLength(2));
    service.dispose();
  });

  test('throws a transient AiInterviewException on server errors', () async {
    final client = MockClient((request) async {
      return http.Response('server error', 500);
    });
    final service = AiInterviewService(
      client: client,
      proxyUrl: 'https://example.test/interview',
    );

    await expectLater(
      service.generateQuestions(
        targetRole: 'Data Analyst',
        experienceLevel: 'Entry-level',
        interviewType: 'HR',
        questionCount: 5,
      ),
      throwsA(isA<AiInterviewException>()
          .having((e) => e.transient, 'transient', isTrue)),
    );
    service.dispose();
  });

  test('throws a non-transient AiInterviewException on bad requests',
      () async {
    final client = MockClient((request) async {
      return http.Response('bad request', 400);
    });
    final service = AiInterviewService(
      client: client,
      proxyUrl: 'https://example.test/interview',
    );

    await expectLater(
      service.generateQuestions(
        targetRole: 'Data Analyst',
        experienceLevel: 'Entry-level',
        interviewType: 'HR',
        questionCount: 5,
      ),
      throwsA(isA<AiInterviewException>()
          .having((e) => e.transient, 'transient', isFalse)),
    );
    service.dispose();
  });
}
