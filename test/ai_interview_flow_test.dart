import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:resumer_app/data/app_state.dart';
import 'package:resumer_app/models/models.dart';
import 'package:resumer_app/screens/ai_interview_screen.dart';
import 'package:resumer_app/screens/career_profile_screen.dart';
import 'package:resumer_app/screens/resumes_screen.dart';
import 'package:resumer_app/services/ai_interview_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // The real app always renders AiInterviewScreen inside the AppScope set up
  // in AppRoot, so tests reproduce that here — it's what lets the screen
  // save the finished interview into the career profile.
  Widget wrap(AppState state, Widget child) => AppScope(
        notifier: state,
        child: MaterialApp(home: child),
      );

  testWidgets('interview screen shows loading then questions', (tester) async {
    final state = AppState();
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'questions': [
            {'question': 'Tell me about yourself.', 'focusArea': 'Intro'},
            {'question': 'Why this role?', 'focusArea': 'Motivation'},
          ],
        }),
        200,
      );
    });
    final service = AiInterviewService(
      client: client,
      proxyUrl: 'https://example.test/interview',
    );

    await tester.pumpWidget(wrap(
      state,
      AiInterviewScreen(
        targetRole: 'Product Designer',
        experienceLevel: 'Mid-level',
        interviewType: 'Behavioral',
        questionCount: 2,
        service: service,
      ),
    ));

    // Loading state first.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Question 1/2'), findsOneWidget);
    expect(find.text('Tell me about yourself.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'My answer here.');
    await tester.tap(find.text('Next question'));
    await tester.pumpAndSettle();

    expect(find.text('Question 2/2'), findsOneWidget);
    expect(find.text('Why this role?'), findsOneWidget);

    await tester.tap(find.text('Finish interview'));
    await tester.pumpAndSettle();

    expect(find.text('Interview complete'), findsOneWidget);
    expect(
        find.textContaining('You answered 1 of 2 questions'), findsOneWidget);

    // The interview is saved as career evidence as soon as it finishes, even
    // though this mock server has no AI-scoring endpoint to score it with.
    final saved = state.careerItems
        .where((item) => item.type == CareerItemType.interview)
        .toList();
    expect(saved, hasLength(1));
    expect(saved.first.title, 'Product Designer');
    expect(saved.first.bullets,
        contains('Q: Tell me about yourself. — A: My answer here.'));

    // Let AppState's debounced persistence finish before the widget test tears
    // down its fake clock.
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('interview screen shows an error state with retry',
      (tester) async {
    final state = AppState();
    final client = MockClient((request) async {
      return http.Response('server error', 500);
    });
    final service = AiInterviewService(
      client: client,
      proxyUrl: 'https://example.test/interview',
    );

    await tester.pumpWidget(wrap(
      state,
      AiInterviewScreen(
        targetRole: 'Data Analyst',
        experienceLevel: 'Entry-level',
        interviewType: 'HR',
        questionCount: 5,
        service: service,
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.text('Could not generate questions'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
      'answers are still saved to the career profile when AI scoring fails',
      (tester) async {
    final state = AppState();
    final client = MockClient((request) async {
      // Always answers with a valid question list — this stands in for a
      // proxy that has no /analyze route configured, so analysis parsing
      // will fail every time (no score/summary in the payload).
      return http.Response(
        jsonEncode({
          'questions': [
            {'question': 'Describe a recent project.'},
          ],
        }),
        200,
      );
    });
    final service = AiInterviewService(
      client: client,
      proxyUrl: 'https://example.test/interview',
    );

    await tester.pumpWidget(wrap(
      state,
      AiInterviewScreen(
        targetRole: 'Backend Engineer',
        experienceLevel: 'Senior',
        interviewType: 'Technical',
        questionCount: 1,
        service: service,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Shipped a payments API.');
    await tester.tap(find.text('Finish interview'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining("Couldn't score this interview right now"),
      findsOneWidget,
    );

    final saved = state.careerItems
        .where((item) => item.type == CareerItemType.interview)
        .toList();
    expect(saved, hasLength(1));
    expect(saved.first.subtitle, contains('AI scoring unavailable'));
    expect(
      saved.first.bullets,
      contains('Q: Describe a recent project. — A: Shipped a payments API.'),
    );
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets(
      '"View Career Profile" opens the existing CareerProfileScreen with '
      'the saved interview', (tester) async {
    final state = AppState();
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'questions': [
            {'question': 'Tell me about yourself.'},
          ],
        }),
        200,
      );
    });
    final service = AiInterviewService(
      client: client,
      proxyUrl: 'https://example.test/interview',
    );

    await tester.pumpWidget(wrap(
      state,
      AiInterviewScreen(
        targetRole: 'Product Designer',
        experienceLevel: 'Mid-level',
        interviewType: 'Behavioral',
        questionCount: 1,
        service: service,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'My answer here.');
    await tester.tap(find.text('Finish interview'));
    await tester.pumpAndSettle();

    // The CTA only appears once the interview has actually been recorded as
    // career evidence.
    expect(find.text('View Career Profile'), findsOneWidget);
    expect(find.text('Tailor your resume'), findsOneWidget);
    expect(find.byType(CareerProfileScreen), findsNothing);

    await tester.tap(find.text('View Career Profile'));
    await tester.pumpAndSettle();

    // The existing CareerProfileScreen is reused as-is (not rebuilt), and
    // shows the interview that was just saved.
    expect(find.byType(CareerProfileScreen), findsOneWidget);
    expect(find.text('Product Designer'), findsWidgets);
  });

  testWidgets(
      '"Tailor your resume" is a next-step CTA that opens the existing '
      'ResumesScreen', (tester) async {
    final state = AppState();
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({
          'questions': [
            {'question': 'Tell me about yourself.'},
          ],
        }),
        200,
      );
    });
    final service = AiInterviewService(
      client: client,
      proxyUrl: 'https://example.test/interview',
    );

    await tester.pumpWidget(wrap(
      state,
      AiInterviewScreen(
        targetRole: 'Backend Engineer',
        experienceLevel: 'Senior',
        interviewType: 'Technical',
        questionCount: 1,
        service: service,
      ),
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Shipped a payments API.');
    await tester.tap(find.text('Finish interview'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tailor your resume'));
    await tester.pumpAndSettle();

    expect(find.byType(ResumesScreen), findsOneWidget);
  });
}
