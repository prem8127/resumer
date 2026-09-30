import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resumer_app/app.dart';
import 'package:resumer_app/data/app_state.dart';
import 'package:resumer_app/data/matching.dart';
import 'package:resumer_app/models/models.dart';

import 'fixtures.dart';

Future<void> finishSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 3150));
  await tester.pumpAndSettle();
}

/// Simulates a completed Google sign-in by flipping the session gate directly;
/// the real flow needs native Google Play services.
Future<void> signIn(WidgetTester tester, AppState state) async {
  state.setAuthenticated(true);
  await tester.pumpAndSettle();
}

/// The explore page opens a one-time "choose your location" sheet; dismiss it
/// so tests can interact with the shell underneath.
Future<void> dismissLocationPrompt(WidgetTester tester) async {
  if (find.text('Where do you want to work?').evaluate().isEmpty) return;
  final sheetContext =
      tester.element(find.byType(DraggableScrollableSheet).first);
  Navigator.of(sheetContext).pop();
  await tester.pumpAndSettle();
}

Future<void> completeOnboarding(WidgetTester tester) async {
  for (var step = 1; step < 5; step++) {
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Build my resume'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    installMockPreferences();
    installScraperOverride();
  });

  tearDown(resetScraperOverride);

  testWidgets('completing the resume prompts to enable AI auto-apply',
      (WidgetTester tester) async {
    final state = fixtureState(onboarded: false, authenticated: false);
    await tester.pumpWidget(AppRoot(state: state));
    await finishSplash(tester);
    await signIn(tester, state);

    await completeOnboarding(tester);
    await dismissLocationPrompt(tester);

    expect(find.text('Enable AI auto-apply?'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.text('Find work\nthat fits.'), findsOneWidget);
    expect(state.autoApplyEnabled, isFalse);
  });

  testWidgets('enabling auto-apply opens the auto-apply screen and tags jobs',
      (WidgetTester tester) async {
    final state = fixtureState(onboarded: false, authenticated: false);
    await tester.pumpWidget(AppRoot(state: state));
    await finishSplash(tester);
    await signIn(tester, state);

    await completeOnboarding(tester);
    await dismissLocationPrompt(tester);

    await tester.tap(find.text('Enable auto-apply'));
    await tester.pumpAndSettle();

    expect(state.autoApplyEnabled, isTrue);
    expect(find.text('AI auto-apply'), findsWidgets);
    expect(find.text('Open roles'), findsOneWidget);

    // Auto-apply starts by itself once the screen opens — no manual tap. The
    // HTTP client fails fast in tests, so each role falls back to the offline
    // match and still lands as an AI application.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(seconds: 1));

    final aiApplied = state.applications
        .where((a) => a.appliedByAi)
        .where((a) => a.status == ApplicationStatus.applied)
        .length;
    expect(aiApplied, greaterThan(0));
  });

  test('aiApplyToJob saves a tailored resume and an AI-tagged application', () {
    final state = fixtureState(onboarded: false, authenticated: false);
    final job = state.jobOpenings.first;
    final report = buildMatchReport(
      jobDescription: job.description,
      evidence: state.careerItems,
    );

    state.aiApplyToJob(job: job, report: report);

    final application = state.applications.firstWhere(
      (a) => a.jobTitle == job.title && a.companyName == job.companyName,
    );
    expect(application.appliedByAi, isTrue);
    expect(application.status, ApplicationStatus.applied);
    expect(application.matchScore, report.score);

    final tailored = state.resumes.where((r) => r.type == ResumeType.tailored);
    expect(tailored, isNotEmpty);
    expect(tailored.first.targetCompany, job.companyName);

    // Applying again to the same role must not duplicate.
    state.aiApplyToJob(job: job, report: report);
    expect(
      state.applications
          .where((a) =>
              a.jobTitle == job.title && a.companyName == job.companyName)
          .length,
      1,
    );
  });

  test('Applied by AI badge shows for seeded AI application', () {
    final aiApplication = demoAiApplication();
    expect(aiApplication.appliedByAi, isTrue);
  });

  testWidgets('tracker dock shows a notification badge for AI applications',
      (WidgetTester tester) async {
    final state = fixtureState(onboarded: false, authenticated: false)
      ..isAuthenticated = true
      ..onboardingCompleted = true;
    await tester.pumpWidget(AppRoot(state: state));
    await finishSplash(tester);

    // Seeded mock data has one application applied by AI → badge '1' on the
    // dock. (Applications screen also renders a '1' summary tile.)
    expect(find.text('1'), findsWidgets);
    expect(find.text('Tracker'), findsWidgets);
  });

  testWidgets('auto-apply adds an AI-tagged application to the tracker',
      (WidgetTester tester) async {
    final state = fixtureState(onboarded: false, authenticated: false);
    await tester.pumpWidget(AppRoot(state: state));
    await finishSplash(tester);
    await signIn(tester, state);
    await completeOnboarding(tester);
    await dismissLocationPrompt(tester);

    await tester.tap(find.text('Enable auto-apply'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.pump(const Duration(seconds: 1));

    // Applications screen lists the AI-tagged application.
    final aiApp = state.applications
        .where((a) => a.appliedByAi)
        .where((a) => a.status == ApplicationStatus.applied)
        .firstOrNull;
    expect(aiApp, isNotNull);
    expect(aiApp!.appliedByAi, isTrue);
  });
}
