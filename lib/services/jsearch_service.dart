import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/job.dart';
import 'auth_service.dart';
import 'secure_api_storage.dart';

enum JSearchErrorKind {
  configuration,
  authentication,
  subscription,
  rateLimit,
  server,
  network,
  invalidResponse,
  unknown,
}

class JSearchException implements Exception {
  const JSearchException({
    required this.kind,
    required this.message,
    this.statusCode,
  });

  final JSearchErrorKind kind;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class JSearchResponse {
  const JSearchResponse({
    required this.statusCode,
    required this.jobs,
    this.nextCursor,
  });

  final int statusCode;
  final List<Job> jobs;
  final String? nextCursor;
}

class JSearchConnectionResult {
  const JSearchConnectionResult({
    required this.success,
    this.statusCode,
    this.jobCount = 0,
    this.error,
  });

  final bool success;
  final int? statusCode;
  final int jobCount;
  final String? error;
}

/// Direct HTTPS client for the RapidAPI JSearch v5 search endpoint.
class JSearchService {
  JSearchService({
    ApiCredentialStore? credentialStore,
    http.Client? client,
    Uri? endpoint,
    this.useBackend = false,
    Uri? backendBaseUrl,
  })  : _credentialStore = credentialStore ?? SecureApiStorage.instance,
        _client = client ?? http.Client(),
        _ownsClient = client == null,
        _endpoint =
            endpoint ?? Uri.https('jsearch.p.rapidapi.com', '/search-v2'),
        _backendBaseUrl = backendBaseUrl ?? Uri.parse(_configuredApiBaseUrl);

  static const _configuredApiBaseUrl = String.fromEnvironment(
    'RESUMER_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const Set<String> supportedDatePosted = {
    'all',
    'today',
    '3days',
    'week',
    'month',
  };
  static const Set<String> supportedEmploymentTypes = {
    'FULLTIME',
    'CONTRACTOR',
    'PARTTIME',
    'INTERN',
  };

  final ApiCredentialStore _credentialStore;
  final http.Client _client;
  final bool _ownsClient;
  final Uri _endpoint;
  final bool useBackend;
  final Uri _backendBaseUrl;
  Future<RapidApiCredentials>? _credentials;

  /// Executes a search using only parameters supported by JSearch.
  ///
  /// JSearch expects location inside [query], so [location] is appended as
  /// natural query text. [country] remains the API's two-letter country code.
  Future<JSearchResponse> searchJobs({
    required String query,
    String? location,
    String? country,
    String? cursor,
    int numPages = 1,
    String? datePosted,
    bool? remoteJobsOnly,
    String? employmentTypes,
  }) async {
    final normalizedQuery = _queryWithLocation(query, location);
    if (normalizedQuery.isEmpty) {
      throw const JSearchException(
        kind: JSearchErrorKind.invalidResponse,
        message: 'Enter a job title, skill, or keyword to search.',
      );
    }
    if (numPages < 1 || numPages > 20) {
      throw const JSearchException(
        kind: JSearchErrorKind.invalidResponse,
        message: 'The number of pages is outside the supported range.',
      );
    }

    final normalizedDate = datePosted?.trim().toLowerCase();
    if (normalizedDate != null &&
        normalizedDate.isNotEmpty &&
        !supportedDatePosted.contains(normalizedDate)) {
      throw const JSearchException(
        kind: JSearchErrorKind.invalidResponse,
        message: 'The selected date filter is not supported.',
      );
    }
    final normalizedEmployment = _normalizeEmploymentTypes(employmentTypes);

    final queryParameters = <String, String>{
      'query': normalizedQuery,
      'num_pages': '$numPages',
      if (cursor != null && cursor.trim().isNotEmpty) 'cursor': cursor.trim(),
      if (country != null && country.trim().isNotEmpty)
        'country': country.trim().toLowerCase(),
      if (normalizedDate != null && normalizedDate.isNotEmpty)
        'date_posted': normalizedDate,
      if (remoteJobsOnly != null) 'work_from_home': remoteJobsOnly.toString(),
      if (normalizedEmployment != null)
        'employment_types': normalizedEmployment,
    };

    try {
      final Uri requestUri;
      final Map<String, String> headers = {'Accept': 'application/json'};
      if (useBackend) {
        final accessToken = AuthService.instance.accessToken;
        if (accessToken == null || accessToken.isEmpty) {
          throw const JSearchException(
            kind: JSearchErrorKind.authentication,
            message: 'Sign in to search jobs.',
            statusCode: 401,
          );
        }
        requestUri = _backendBaseUrl
            .resolve('/v1/jobs/search')
            .replace(queryParameters: queryParameters);
        headers['Authorization'] = 'Bearer $accessToken';
      } else {
        final credentials =
            await (_credentials ??= _credentialStore.getCredentials());
        requestUri = _endpoint.replace(queryParameters: queryParameters);
        headers['X-RapidAPI-Key'] = credentials.apiKey;
        headers['X-RapidAPI-Host'] = credentials.host;
      }
      final response = await _client
          .get(requestUri, headers: headers)
          .timeout(const Duration(seconds: 30));

      _throwForStatus(response.statusCode);

      final Object? decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } on FormatException {
        throw const JSearchException(
          kind: JSearchErrorKind.invalidResponse,
          message: 'The job service returned an unreadable response.',
          statusCode: 200,
        );
      }
      if (decoded is! Map) {
        throw const JSearchException(
          kind: JSearchErrorKind.invalidResponse,
          message: 'The job service returned an unexpected response.',
          statusCode: 200,
        );
      }

      final rawData = decoded['data'];
      final List<dynamic>? rawJobs;
      final String? nextCursor;
      if (rawData is Map && rawData['jobs'] is List) {
        rawJobs = rawData['jobs'] as List;
        nextCursor = rawData['cursor'] is String &&
                (rawData['cursor'] as String).trim().isNotEmpty
            ? (rawData['cursor'] as String).trim()
            : null;
      } else if (rawData is List) {
        // Backward-compatible parsing for recorded v1 fixtures only.
        rawJobs = rawData;
        nextCursor = null;
      } else {
        throw const JSearchException(
          kind: JSearchErrorKind.invalidResponse,
          message: 'The job service returned an unexpected response.',
          statusCode: 200,
        );
      }

      final jobs = <Job>[];
      for (final item in rawJobs) {
        if (item is Map) {
          final job = Job.fromJSearchJson(item.cast<String, dynamic>());
          // Title and employer are required for the existing job-card UI.
          if (job.title.isNotEmpty && job.company.isNotEmpty) jobs.add(job);
        }
      }
      return JSearchResponse(
        statusCode: response.statusCode,
        jobs: jobs,
        nextCursor: nextCursor,
      );
    } on ApiConfigurationException catch (error) {
      throw JSearchException(
        kind: JSearchErrorKind.configuration,
        message: error.message,
      );
    } on JSearchException {
      rethrow;
    } on TimeoutException {
      throw const JSearchException(
        kind: JSearchErrorKind.network,
        message: 'The job search timed out. Check your connection and retry.',
      );
    } on http.ClientException {
      throw const JSearchException(
        kind: JSearchErrorKind.network,
        message: 'No internet connection. Reconnect and try again.',
      );
    } on Object {
      throw const JSearchException(
        kind: JSearchErrorKind.unknown,
        message: 'Job search is temporarily unavailable. Try again shortly.',
      );
    }
  }

  /// Safe first-run connectivity check. No credentials are included in its
  /// result or error text.
  Future<JSearchConnectionResult> testConnection() async {
    try {
      final response = await searchJobs(
        query: 'software engineer in India',
        numPages: 1,
      );
      return JSearchConnectionResult(
        success: true,
        statusCode: response.statusCode,
        jobCount: response.jobs.length,
      );
    } on JSearchException catch (error) {
      return JSearchConnectionResult(
        success: false,
        statusCode: error.statusCode,
        error: error.message,
      );
    }
  }

  static String _queryWithLocation(String query, String? location) {
    final normalizedQuery = query.trim();
    final normalizedLocation = location?.trim() ?? '';
    if (normalizedLocation.isEmpty ||
        normalizedQuery
            .toLowerCase()
            .contains(normalizedLocation.toLowerCase())) {
      return normalizedQuery;
    }
    if (normalizedQuery.isEmpty) return normalizedLocation;
    return '$normalizedQuery in $normalizedLocation';
  }

  static String? _normalizeEmploymentTypes(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value
        .split(',')
        .map((item) => item.trim().toUpperCase().replaceAll('-', ''))
        .where((item) => item.isNotEmpty)
        .toSet();
    if (normalized.isEmpty ||
        normalized.any((item) => !supportedEmploymentTypes.contains(item))) {
      throw const JSearchException(
        kind: JSearchErrorKind.invalidResponse,
        message: 'The selected employment type is not supported.',
      );
    }
    return normalized.join(',');
  }

  static void _throwForStatus(int statusCode) {
    switch (statusCode) {
      case 200:
        return;
      case 401:
        throw const JSearchException(
          kind: JSearchErrorKind.authentication,
          message:
              'Job search authentication failed. Update the app configuration.',
          statusCode: 401,
        );
      case 403:
        throw const JSearchException(
          kind: JSearchErrorKind.subscription,
          message: 'Job search access is unavailable for this subscription.',
          statusCode: 403,
        );
      case 429:
        throw const JSearchException(
          kind: JSearchErrorKind.rateLimit,
          message: 'Too many job searches. Please wait a moment and retry.',
          statusCode: 429,
        );
      case 500:
      case 502:
      case 503:
        throw JSearchException(
          kind: JSearchErrorKind.server,
          message:
              'The job service is temporarily unavailable. Try again shortly.',
          statusCode: statusCode,
        );
      default:
        throw JSearchException(
          kind: JSearchErrorKind.unknown,
          message: 'Job search failed. Please try again.',
          statusCode: statusCode,
        );
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
