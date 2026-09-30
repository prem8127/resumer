import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:resumer_app/services/jsearch_service.dart';
import 'package:resumer_app/services/secure_api_storage.dart';

class _Credentials implements ApiCredentialStore {
  int calls = 0;

  @override
  Future<RapidApiCredentials> getCredentials() async {
    calls++;
    return const RapidApiCredentials(
      apiKey: 'unit-test-key',
      host: 'jsearch.p.rapidapi.com',
    );
  }
}

void main() {
  test('uses exact supported parameters and parses nullable job fields',
      () async {
    final credentials = _Credentials();
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      if (requests == 1) {
        expect(request.url.queryParameters, {
          'query': 'AI internships in India',
          'cursor': 'page-two-cursor',
          'num_pages': '1',
          'country': 'in',
          'date_posted': '3days',
          'work_from_home': 'false',
          'employment_types': 'INTERN,PARTTIME',
        });
      }
      return http.Response(
        jsonEncode({
          'status': 'OK',
          'data': {
            'cursor': 'next-cursor',
            'jobs': [
              {
                'job_id': 'ai-intern-1',
                'job_title': 'AI Intern',
                'employer_name': 'Example AI',
                'employer_logo': null,
                'job_location': 'India',
                'job_is_remote': false,
                'job_highlights': {
                  'Qualifications': ['Python'],
                  'Responsibilities': ['Build models'],
                  'Skills': ['Python', 'ML'],
                },
                'job_apply_link': 'https://example.com/apply',
              }
            ],
          },
        }),
        200,
      );
    });
    final service = JSearchService(
      credentialStore: credentials,
      client: client,
    );

    final first = await service.searchJobs(
      query: 'AI internships',
      location: 'India',
      country: 'IN',
      cursor: 'page-two-cursor',
      datePosted: '3days',
      remoteJobsOnly: false,
      employmentTypes: 'intern,part-time',
    );
    final second = await service.searchJobs(query: 'React developer');

    expect(first.statusCode, 200);
    expect(first.nextCursor, 'next-cursor');
    expect(first.jobs.single.qualifications, ['Python']);
    expect(first.jobs.single.responsibilities, ['Build models']);
    expect(first.jobs.single.skills, ['Python', 'ML']);
    expect(first.jobs.single.salaryMin, isNull);
    expect(second.jobs, hasLength(1));
    expect(requests, 2);
    expect(credentials.calls, 1,
        reason: 'credentials should be initialized once per service instance');
    service.dispose();
  });

  test('connectivity test verifies status, JSON data, and job count', () async {
    final client = MockClient((request) async {
      expect(
          request.url.queryParameters['query'], 'software engineer in India');
      expect(request.url.queryParameters.containsKey('cursor'), isFalse);
      expect(request.url.queryParameters['num_pages'], '1');
      return http.Response(
        jsonEncode({
          'status': 'OK',
          'data': {
            'cursor': 'next-cursor',
            'jobs': [
              {
                'job_id': '1',
                'job_title': 'Software Engineer',
                'employer_name': 'Example',
              },
              {
                'job_id': '2',
                'job_title': 'Backend Engineer',
                'employer_name': 'Example Two',
              },
            ],
          },
        }),
        200,
      );
    });
    final service = JSearchService(
      credentialStore: _Credentials(),
      client: client,
    );

    final result = await service.testConnection();

    expect(result.success, isTrue);
    expect(result.statusCode, 200);
    expect(result.jobCount, 2);
    expect(result.error, isNull);
    service.dispose();
  });

  for (final query in const [
    'software engineer',
    'React developer',
    'internships',
    'AI internships in India',
    'remote Python jobs',
    'frontend developer Bangalore',
  ]) {
    test('preserves supported search text: $query', () async {
      final service = JSearchService(
        credentialStore: _Credentials(),
        client: MockClient((request) async {
          expect(request.url.queryParameters['query'], query);
          return http.Response(
            jsonEncode({
              'status': 'OK',
              'data': {'jobs': [], 'cursor': ''},
            }),
            200,
          );
        }),
      );

      final result = await service.searchJobs(query: query);

      expect(result.statusCode, 200);
      expect(result.jobs, isEmpty);
      service.dispose();
    });
  }

  test('returns a safe no-internet error', () async {
    final service = JSearchService(
      credentialStore: _Credentials(),
      client: MockClient((_) async => throw http.ClientException('offline')),
    );

    final result = await service.testConnection();

    expect(result.success, isFalse);
    expect(result.statusCode, isNull);
    expect(result.error, 'No internet connection. Reconnect and try again.');
    expect(result.error, isNot(contains('unit-test-key')));
    service.dispose();
  });

  for (final testCase in const {
    401: 'Job search authentication failed. Update the app configuration.',
    403: 'Job search access is unavailable for this subscription.',
    429: 'Too many job searches. Please wait a moment and retry.',
    500: 'The job service is temporarily unavailable. Try again shortly.',
    502: 'The job service is temporarily unavailable. Try again shortly.',
    503: 'The job service is temporarily unavailable. Try again shortly.',
  }.entries) {
    test('returns safe connectivity error for HTTP ${testCase.key}', () async {
      final service = JSearchService(
        credentialStore: _Credentials(),
        client: MockClient(
          (_) async => http.Response('response must not leak', testCase.key),
        ),
      );

      final result = await service.testConnection();

      expect(result.success, isFalse);
      expect(result.statusCode, testCase.key);
      expect(result.error, testCase.value);
      expect(result.error, isNot(contains('unit-test-key')));
      service.dispose();
    });
  }

  test('rejects unsupported filters before sending a request', () async {
    final service = JSearchService(
      credentialStore: _Credentials(),
      client: MockClient((_) async => fail('request should not be sent')),
    );

    await expectLater(
      service.searchJobs(
        query: 'developer',
        employmentTypes: 'PERMANENT',
      ),
      throwsA(isA<JSearchException>()),
    );
    await expectLater(
      service.searchJobs(query: 'developer', datePosted: 'yesterday'),
      throwsA(isA<JSearchException>()),
    );
    service.dispose();
  });
}
