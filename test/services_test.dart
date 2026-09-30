import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resumer_app/data/app_state.dart';
import 'package:resumer_app/data/matching.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fixtures.dart' as fixtures;
import 'package:resumer_app/models/models.dart';
import 'package:resumer_app/services/auth_service.dart';
import 'package:resumer_app/services/job_search_service.dart';
import 'package:resumer_app/services/resume_pdf_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Google sign-in diagnostics', () {
    test('explains when the current web domain is not authorized', () {
      final error = AuthException('Redirect URL is not allowed');
      expect(
        AuthService.signInErrorMessage(error),
        contains('return URL'),
      );
    });

    test('explains when Google sign-in is disabled', () {
      final error = AuthException('Google provider is disabled');
      expect(
        AuthService.signInErrorMessage(error),
        contains('Google sign-in is not enabled'),
      );
    });
  });

  group('Legacy n8n JobSearchService tests', () {
    test(
        'communicates with n8n webhook and maps normalized jobs into JobOpening models',
        () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(
            request.url.toString(), 'http://localhost:5678/webhook/job-search');
        final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(requestBody['location'], 'Bengaluru, India');
        expect(requestBody['limit'], 50);

        return http.Response(
          jsonEncode({
            'success': true,
            'query': {
              'location': 'Bengaluru, India',
              'keywords': ['flutter']
            },
            'total': 2,
            'jobs': [
              {
                'id': 'gh-northstar-1234',
                'externalId': '1234',
                'title': 'Flutter Developer',
                'company': 'Northstar',
                'companyLogo': null,
                'location': 'Remote',
                'city': null,
                'state': null,
                'country': null,
                'remoteType': 'remote',
                'jobType': 'full-time',
                'experienceLevel': '0-2',
                'skills': ['Flutter', 'React', 'API'],
                'salaryMin': 50000,
                'salaryMax': 70000,
                'currency': 'USD',
                'description': 'Build apps with Flutter.',
                'postedAt': '2026-08-19T10:00:00Z',
                'applyUrl': 'https://jobs.example/1234',
                'sourceUrl': 'https://jobs.example/1234',
                'source': 'Northstar',
                'atsProvider': 'greenhouse'
              },
              {
                'id': 'ashby-paperplane-5678',
                'externalId': '5678',
                'title': 'UX Intern',
                'company': 'Paperplane',
                'companyLogo': null,
                'location': 'Bengaluru',
                'city': 'Bengaluru',
                'state': null,
                'country': 'India',
                'remoteType': 'onsite',
                'jobType': 'internship',
                'experienceLevel': 'fresher',
                'skills': ['Figma'],
                'salaryMin': null,
                'salaryMax': null,
                'currency': null,
                'description': 'Design interfaces.',
                'postedAt': '2026-08-18T10:00:00Z',
                'applyUrl': 'https://jobs.example/5678',
                'sourceUrl': 'https://jobs.example/5678',
                'source': 'Paperplane',
                'atsProvider': 'ashby'
              }
            ],
            'meta': {
              'sourcesChecked': 2,
              'sourcesSuccessful': 2,
              'sourcesFailed': 0
            }
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = JobSearchService(
        client: client,
      );

      final jobs = await service.searchJobs(
        location: 'Bengaluru, India',
        limit: 50,
        careerItems: fixtures.demoCareerItems(),
      );

      expect(service.lastSearchSucceeded, isTrue);
      expect(service.sourceLabel, 'Live via n8n');
      expect(jobs, hasLength(2));

      final first = jobs.first;
      expect(first.title, 'Flutter Developer');
      expect(first.companyName, 'Northstar');
      expect(first.workMode, 'Remote');
      expect(first.employmentType, 'Full-time');
      expect(first.salaryLabel, 'USD 50000 – 70000');
      expect(first.skills, contains('Flutter'));
      expect(first.description, 'Build apps with Flutter.');
      expect(first.url, 'https://jobs.example/1234');

      final second = jobs[1];
      expect(second.title, 'UX Intern');
      expect(second.companyName, 'Paperplane');
      expect(second.workMode, 'On-site');
      expect(second.employmentType, 'Internship');
      expect(second.salaryLabel, 'Competitive salary');

      // Test local caching utilities (Section 14)
      final stored = await service.getStoredJobs();
      expect(stored, hasLength(2));
      expect(stored.first.title, 'Flutter Developer');

      final lastSearch = await service.getLastSearch();
      expect(lastSearch?['location'], 'Bengaluru, India');

      await service.clearJobs();
      final afterClear = await service.getStoredJobs();
      expect(afterClear, isEmpty);

      service.dispose();
    });

    test('returns empty results and records error when n8n is offline',
        () async {
      final client = MockClient((request) async {
        throw http.ClientException('offline');
      });
      final service = JobSearchService(
        client: client,
      );

      final jobs = await service.searchJobs(
        location: 'Bengaluru, India',
        careerItems: fixtures.demoCareerItems(),
      );

      expect(service.lastSearchSucceeded, isFalse);
      expect(jobs, isEmpty);
      expect(service.lastError, contains('Could not reach local n8n webhook'));
      service.dispose();
    });
  }, skip: 'Replaced by direct JSearch coverage in jsearch_service_test.dart');

  group('ResumePdfService', () {
    test('builds a valid PDF document for a tailored resume', () async {
      final state = fixtures.fixtureState();
      final resume = state.resumes.first;
      const service = ResumePdfService();

      final bytes = await service.build(state: state, resume: resume);

      expect(bytes.length, greaterThan(1000));
      expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
    });
  });

  group('AppState.applyToJob', () {
    test('records an applied application for the tailored role', () {
      final state = fixtures.fixtureState();
      final before = state.applications.length;

      state.applyToJob(
        jobTitle: 'Product Engineer Intern',
        companyName: 'Fenix Labs',
        matchScore: 86,
        location: 'Bengaluru',
      );

      expect(state.applications.length, before + 1);
      final app = state.applications.first;
      expect(app.status, ApplicationStatus.applied);
      expect(app.jobTitle, 'Product Engineer Intern');
      expect(app.matchScore, 86);
    });

    test('is a no-op when the same role was already applied to', () {
      final state = fixtures.fixtureState();
      state.applyToJob(
        jobTitle: 'SDE Intern',
        companyName: 'CloudNine',
        matchScore: 71,
      );
      final before = state.applications.length;

      state.applyToJob(
        jobTitle: 'SDE Intern',
        companyName: 'CloudNine',
        matchScore: 71,
      );

      expect(state.applications.length, before);
    });
  });

  test('aiApplyToJob still saves a tailored resume and tags the application',
      () {
    final state = fixtures.fixtureState();
    final job = state.jobOpenings.first;
    final report = buildMatchReport(
      jobDescription: job.description,
      evidence: state.careerItems,
    );

    state.aiApplyToJob(job: job, report: report);

    expect(
      state.applications.any(
        (a) => a.jobTitle == job.title && a.appliedByAi,
      ),
      isTrue,
    );
  });

  group('AppState persistence', () {
    test('saving onboarding once means it is never asked again', () async {
      SharedPreferences.setMockInitialValues({});
      final state = fixtures.fixtureState(onboarded: false);

      state.completeOnboarding(
        name: 'Priya Sharma',
        email: 'priya.sharma@example.com',
        phone: '+91 98765 43210',
        location: 'Bengaluru, India',
        headline: 'Aspiring product engineer',
        degree: 'B.Tech, Computer Science & Engineering',
        school: 'IIIT Bengaluru',
        studyPeriod: '2022 — 2026',
        role: 'Software Development Intern',
        company: 'Fenix Labs',
        achievement: 'Built a Flutter onboarding flow.',
        skills: ['Flutter', 'React'],
      );
      await state.save();

      // Simulate an app restart: fresh state, load from storage.
      final restored = AppState();
      await restored.load();

      expect(restored.onboardingCompleted, isTrue,
          reason: 'onboarding must not be asked again');
      expect(restored.user.name, 'Priya Sharma');
      expect(restored.user.email, 'priya.sharma@example.com');
      expect(restored.careerItems.map((c) => c.title),
          contains('B.Tech, Computer Science & Engineering'));
      final master = restored.resumes
          .where((r) => r.type == ResumeType.master)
          .firstOrNull;
      expect(master, isNotNull);
      expect(restored.applications.first.appliedByAi, isTrue);
    });

    test('preferred location and tracker persist across restarts', () async {
      SharedPreferences.setMockInitialValues({});
      final state = fixtures.fixtureState();
      state.setPreferredLocation('Hyderabad, India');
      await state.save();

      final restored = AppState();
      await restored.load();

      expect(restored.preferredLocation, 'Hyderabad, India');
      expect(restored.onboardingCompleted, isTrue);
      expect(restored.applications.first.appliedByAi, isTrue);
    });
  });
}
