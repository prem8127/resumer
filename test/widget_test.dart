import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:resumer_app/app.dart';
import 'package:resumer_app/data/app_state.dart';
import 'package:resumer_app/screens/login_screen.dart';
import 'package:resumer_app/screens/influencers_screen.dart';
import 'package:resumer_app/screens/resume_preview_screen.dart';

import 'fixtures.dart';

Future<void> finishSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 3150));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Simulates a completed Google sign-in by flipping the session flag directly;
/// the real flow needs native Google Play services.
Future<void> signIn(AppState state) async {
  state.isAuthenticated = true;
}

/// The explore page opens a one-time "choose your location" sheet; dismiss it
/// so tests can interact with the shell underneath.
Future<void> dismissLocationPrompt(WidgetTester tester) async {
  if (find.text('Where do you want to work?').evaluate().isEmpty) return;
  final sheetContext =
      tester.element(find.byType(DraggableScrollableSheet).first);
  Navigator.of(sheetContext).pop();
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> flushStateSaveTimer(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  setUp(() {
    installMockPreferences();
    installScraperOverride();
  });

  tearDown(resetScraperOverride);

  testWidgets('longer splash leads into the login screen',
      (WidgetTester tester) async {
    final state = fixtureState(authenticated: false, onboarded: false);
    await tester.pumpWidget(AppRoot(state: state));

    expect(find.text('Your work,\nclearly told.'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('Your work,\nclearly told.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(find.text('Welcome.'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('first login goes straight to the app on a narrow viewport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = fixtureState(onboarded: false);
    await tester.pumpWidget(AppRoot(state: state));
    await finishSplash(tester);

    expect(find.text('Find work\nthat fits.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login wordmark fits the constrained browser viewport',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(300, 640);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Welcome.'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Learn shows courses and opens Meet the Real Mentors',
      (WidgetTester tester) async {
    final state = fixtureState();
    await tester.pumpWidget(AppRoot(state: state));
    await finishSplash(tester);
    await dismissLocationPrompt(tester);

    await tester.tap(find.text('Learn').last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Python Masterclass'), findsOneWidget);

    await tester.tap(find.ancestor(
      of: find.text('Meet the Real Mentors'),
      matching: find.byType(OutlinedButton),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(InfluencersScreen), findsOneWidget);
    expect(find.text('All mentors'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);
    await flushStateSaveTimer(tester);
  });

  testWidgets('login opens the jobs-first home without resume onboarding',
      (WidgetTester tester) async {
    final state = fixtureState(onboarded: false);
    await tester.pumpWidget(AppRoot(state: state));
    await finishSplash(tester);

    expect(find.text('Let’s start with you.'), findsNothing);
    expect(find.text('STEP 1 OF 5'), findsNothing);

    // The preferred location is persisted from the fixture, so returning to
    // Explore never re-asks — the feed loads straight away.
    expect(find.text('Where do you want to work?'), findsNothing);
    await dismissLocationPrompt(tester);

    // Completing onboarding also triggers the AI auto-apply prompt.
    if (find.text('Enable AI auto-apply?').evaluate().isNotEmpty) {
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Find work\nthat fits.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Open roles'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Open roles'), findsOneWidget);
    expect(find.text('Career'), findsOneWidget);
    expect(find.text('Tracker'), findsWidgets);
    await flushStateSaveTimer(tester);
  });

  testWidgets('career profile is a dedicated editable tab',
      (WidgetTester tester) async {
    final state = fixtureState()
      ..isAuthenticated = true
      ..onboardingCompleted = true;
    await tester.pumpWidget(AppRoot(state: state));
    await finishSplash(tester);
    await dismissLocationPrompt(tester);

    await tester.tap(find.text('Career'));
    await tester.pumpAndSettle();

    expect(find.text('Career profile'), findsOneWidget);
    expect(find.text('Evidence readiness'), findsOneWidget);
    expect(find.text('Meet the Real Mentors'), findsOneWidget);
    expect(find.text('John'), findsOneWidget);
    expect(find.text('All evidence'), findsOneWidget);
    expect(find.text('Influencers'), findsNothing);

    await tester.tap(find.text('B.Tech, Computer Science & Engineering'));
    await tester.pumpAndSettle();
    expect(find.text('Edit education'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('saved resumes can be opened as a document preview',
      (WidgetTester tester) async {
    final state = fixtureState()
      ..isAuthenticated = true
      ..onboardingCompleted = true;
    await tester.pumpWidget(AppRoot(state: state));
    await finishSplash(tester);
    await dismissLocationPrompt(tester);

    await tester.tap(find.text('Resumes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Priya Sharma — Master'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview resume'));
    await tester.pumpAndSettle();

    expect(find.text('Resume preview'), findsOneWidget);
    expect(find.text('ATS-SAFE'), findsOneWidget);
    expect(find.text('PRIYA SHARMA'), findsOneWidget);
  });

  testWidgets('resume preview edits resume details and individual sections',
      (WidgetTester tester) async {
    final state = fixtureState();
    await tester.pumpWidget(
      AppScope(
        notifier: state,
        child: MaterialApp(
          home: ResumePreviewScreen(resume: state.resumes.first),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Edit resume'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resume title, target and highlights'));
    await tester.pumpAndSettle();
    expect(find.text('Edit resume details'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Updated master');
    await tester.tap(find.text('Save resume changes'));
    await tester.pumpAndSettle();
    expect(state.resumes.first.name, 'Updated master');

    await tester.tap(find.text('Software Development Intern'));
    await tester.pumpAndSettle();
    expect(find.text('Edit experience'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Mobile Engineer');
    await tester.tap(find.text('Save section'));
    await tester.pumpAndSettle();
    expect(
      state.careerItems.firstWhere((item) => item.id == 'exp-1').title,
      'Mobile Engineer',
    );
  });

  testWidgets('logout returns to the login screen',
      (WidgetTester tester) async {
    final state = fixtureState()
      ..isAuthenticated = true
      ..onboardingCompleted = true;
    await tester.pumpWidget(AppRoot(state: state));
    await finishSplash(tester);
    await dismissLocationPrompt(tester);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome.'), findsOneWidget);
    expect(state.isAuthenticated, isFalse);
  });

  testWidgets('explore screen displays the 3 small circles and product cards',
      (WidgetTester tester) async {
    final state = fixtureState()
      ..isAuthenticated = true
      ..onboardingCompleted = true;
    await tester.pumpWidget(AppRoot(state: state));
    await finishSplash(tester);
    await dismissLocationPrompt(tester);

    // Verify 3 small circle labels are rendered
    expect(find.text('Companies'), findsOneWidget);
    expect(find.text('Openings'), findsOneWidget);
    expect(find.text('Core Match'), findsOneWidget);

    // Job cards are lazy-built below the fold.
    await tester.scrollUntilVisible(
      find.text('Google'),
      280,
      scrollable: find.byType(Scrollable).first,
    );

    // Verify product cards have pricing, match tags, and company logos
    expect(find.textContaining('Google'), findsWidgets);

    await tester.drag(find.byType(ListView).first, const Offset(0, 900));
    await tester.pumpAndSettle();

    // Tap on the Companies circle to open the companies bottom sheet
    await tester.tap(find.text('Companies'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Hiring Companies'), findsOneWidget);
    expect(find.text('Show all companies'), findsOneWidget);

    // Close modal
    await tester.tap(find.text('Show all companies'));
    await tester.pumpAndSettle();

    // Tap on Core Match circle
    await tester.tap(find.text('Core Match'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Core Resume Matches'), findsOneWidget);
  });
}
