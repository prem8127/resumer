import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resumer_app/services/job_search_service.dart';
import 'package:resumer_app/services/secure_api_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

class _FakeCredentialStore implements ApiCredentialStore {
  int reads = 0;

  @override
  Future<RapidApiCredentials> getCredentials() async {
    reads++;
    return const RapidApiCredentials(
      apiKey: 'test-key-never-log',
      host: 'jsearch.p.rapidapi.com',
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('maps JSearch data into the existing JobOpening feed and cache',
      () async {
    final credentials = _FakeCredentialStore();
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.host, 'jsearch.p.rapidapi.com');
      expect(request.url.path, '/search-v2');
      expect(request.url.queryParameters['query'],
          'software engineer in Hyderabad, India');
      expect(request.url.queryParameters['country'], 'in');
      expect(request.url.queryParameters.containsKey('cursor'), isFalse);
      expect(request.url.queryParameters['num_pages'], '1');
      expect(request.url.queryParameters['date_posted'], 'week');
      expect(request.url.queryParameters['work_from_home'], 'true');
      expect(
          request.url.queryParameters['employment_types'], 'FULLTIME,INTERN');
      expect(request.headers['X-RapidAPI-Host'], 'jsearch.p.rapidapi.com');
      expect(request.headers['X-RapidAPI-Key'], isNotEmpty);

      return http.Response(
        jsonEncode({
          'status': 'OK',
          'data': {
            'cursor': 'next-page-cursor',
            'jobs': [
              {
                'job_id': 'job-101',
                'job_title': 'Software Engineer',
                'employer_name': 'Postman',
                'job_location': 'Hyderabad, Telangana, India',
                'job_city': 'Hyderabad',
                'job_state': 'Telangana',
                'job_country': 'IN',
                'job_is_remote': true,
                'job_employment_type': 'FULLTIME',
                'job_posted_at_datetime_utc': '2026-09-15T08:00:00Z',
                'job_min_salary': 1200000,
                'job_max_salary': 1800000,
                'job_salary_currency': 'INR',
                'job_salary_period': 'YEAR',
                'job_description': 'Build Flutter and React applications.',
                'job_required_skills': ['Flutter', 'React'],
                'job_apply_link': 'https://jobs.example/101',
                'job_google_link': 'https://google.example/jobs/101',
                'job_publisher': 'Example Jobs',
              },
            ],
          },
        }),
        200,
      );
    });
    final service = JobSearchService(
      client: client,
      credentialStore: credentials,
    );

    final jobs = await service.searchJobs(
      query: 'software engineer',
      location: 'Hyderabad, India',
      country: 'IN',
      datePosted: 'week',
      remoteJobsOnly: true,
      employmentTypes: 'FULLTIME,INTERN',
      careerItems: demoCareerItems(),
    );

    expect(service.lastSearchSucceeded, isTrue);
    expect(service.lastStatusCode, 200);
    expect(service.hasMore, isTrue);
    expect(service.sourceLabel, 'Live via JSearch');
    expect(credentials.reads, 1);
    expect(jobs, hasLength(1));
    expect(jobs.single.id, 'job-101');
    expect(jobs.single.companyName, 'Postman');
    expect(jobs.single.workMode, 'Remote');
    expect(jobs.single.salaryLabel, 'INR 1200000 – 1800000 / year');
    expect(jobs.single.url, 'https://jobs.example/101');

    final stored = await service.getStoredJobs();
    expect(stored, hasLength(1));
    expect(stored.single.id, 'job-101');
    final lastSearch = await service.getLastSearch();
    expect(lastSearch?['page'], 1);
    expect(lastSearch?['remoteJobsOnly'], isTrue);
    service.dispose();
  });

  test('keeps API errors safe for the UI', () async {
    final client =
        MockClient((_) async => http.Response('secret response', 429));
    final service = JobSearchService(
      client: client,
      credentialStore: _FakeCredentialStore(),
    );

    final jobs = await service.searchJobs(query: 'React developer');

    expect(jobs, isEmpty);
    expect(service.lastSearchSucceeded, isFalse);
    expect(service.lastStatusCode, 429);
    expect(service.lastError,
        'Too many job searches. Please wait a moment and retry.');
    expect(service.lastError, isNot(contains('test-key')));
    service.dispose();
  });

  test('respects the existing widget-test override without credentials',
      () async {
    JobSearchService.debugSearchOverride = (_) async => [demoGoogleJob()];
    final service = JobSearchService();

    final jobs = await service.searchJobs(query: 'software engineer');

    expect(jobs.single.companyName, 'Google');
    expect(service.lastSearchSucceeded, isTrue);
    JobSearchService.debugSearchOverride = null;
    service.dispose();
  });
}
