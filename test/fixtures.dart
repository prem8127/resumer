import 'package:shared_preferences/shared_preferences.dart';

import 'package:resumer_app/data/app_state.dart';
import 'package:resumer_app/models/models.dart';
import 'package:resumer_app/services/job_search_service.dart';

/// Inline fixtures replacing the old bundled mock data — the app itself
/// ships no demo content anymore.

const User demoUser = User(
  name: 'Priya Sharma',
  email: 'priya.sharma@example.com',
  headline: 'Final-year CS student · aspiring product engineer',
  phone: '+91 98765 43210',
  location: 'Bengaluru, India',
);

List<CareerItem> demoCareerItems() => const [
      CareerItem(
        id: 'edu-1',
        type: CareerItemType.education,
        title: 'B.Tech, Computer Science & Engineering',
        subtitle: 'IIIT Bengaluru',
        dateRange: '2022 — 2026',
        verified: true,
      ),
      CareerItem(
        id: 'exp-1',
        type: CareerItemType.experience,
        title: 'Software Development Intern',
        subtitle: 'Fenix Labs',
        dateRange: 'Jan 2026 — Apr 2026',
        bullets: [
          'Built a Flutter onboarding flow that lifted activation by 18%.'
        ],
        verified: true,
      ),
      CareerItem(
        id: 'skill-flutter',
        type: CareerItemType.skill,
        title: 'Flutter',
        verified: true,
      ),
      CareerItem(
        id: 'skill-react',
        type: CareerItemType.skill,
        title: 'React',
        verified: true,
      ),
    ];

Resume demoMasterResume() {
  final now = DateTime.now();
  return Resume(
    id: 'res-master',
    name: 'Priya Sharma — Master',
    type: ResumeType.master,
    status: ResumeStatus.ready,
    updatedAt: now,
    versions: [
      ResumeVersion(
          id: 'v1', label: 'Initial version', createdAt: now, isCurrent: true),
    ],
  );
}

JobOpening demoGoogleJob() => JobOpening(
      id: 'job-google-1',
      title: 'Software Engineering Intern (Summer 2027)',
      companyName: 'Google',
      location: 'Bengaluru · Hybrid',
      workMode: 'Hybrid',
      employmentType: 'Internship',
      salaryLabel: '₹85k – ₹1.2L / mo',
      postedAt: DateTime.now().subtract(const Duration(hours: 2)),
      matchScore: 94,
      skills: const ['React', 'TypeScript', 'Algorithms', 'REST APIs'],
      description:
          'Join Google engineering teams to build high-scale web platforms '
          'using React, TypeScript, and distributed backend services.',
      url: 'https://www.google.com/about/careers/applications/jobs/results/',
    );

JobOpening demoAmazonJob() => JobOpening(
      id: 'job-amazon-1',
      title: 'SDE Intern — AWS Cloud Platform',
      companyName: 'Amazon',
      location: 'Hyderabad · Hybrid',
      workMode: 'Hybrid',
      employmentType: 'Internship',
      salaryLabel: '₹80k – ₹1.1L / mo',
      postedAt: DateTime.now().subtract(const Duration(hours: 5)),
      matchScore: 90,
      skills: const ['Java', 'TypeScript', 'AWS'],
      description: 'Work with AWS teams on cloud infrastructure services.',
      url: 'https://www.amazon.jobs/en/search',
    );

Application demoAiApplication({String company = 'Northstar'}) {
  return Application(
    id: 'app-ai-seed',
    jobTitle: 'Frontend Engineer Intern',
    companyName: company,
    status: ApplicationStatus.applied,
    matchScore: 88,
    updatedAt: DateTime.now(),
    location: 'Bengaluru',
    appliedByAi: true,
  );
}

/// A fully populated signed-in state mirroring what a real user has after
/// completing onboarding.
AppState fixtureState({
  bool onboarded = true,
  bool authenticated = true,
  String? preferredLocation = 'Bengaluru, India',
}) {
  final state = AppState();
  state
    ..user = demoUser
    ..isAuthenticated = authenticated
    ..onboardingCompleted = onboarded
    ..preferredLocation = preferredLocation;
  state.careerItems.addAll(demoCareerItems());
  state.resumes.add(demoMasterResume());
  state.applications.add(demoAiApplication());
  state.jobOpenings.addAll([demoGoogleJob(), demoAmazonJob()]);
  return state;
}

/// Points the Explore job search at fixture jobs so widget tests never touch
/// the network. Always call [resetScraperOverride] in tearDown.
void installScraperOverride() {
  JobSearchService.debugSearchOverride =
      (_) async => [demoGoogleJob(), demoAmazonJob()];
}

void resetScraperOverride() {
  JobSearchService.debugSearchOverride = null;
}

/// SharedPreferences is backed by an empty in-memory store in tests; set the
/// mock initial values before any AppState.load()/save().
void installMockPreferences() {
  SharedPreferences.setMockInitialValues({});
}
