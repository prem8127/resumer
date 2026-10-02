import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/serializers.dart';
import '../models/job.dart';
import '../models/models.dart';
import 'jsearch_service.dart';
import 'secure_api_storage.dart';

/// UI-facing job-search coordinator.
///
/// It preserves the app's existing [JobOpening] feed contract while delegating
/// all direct HTTPS access and credential reads to [JSearchService].
class JobSearchService {
  JobSearchService({
    JSearchService? jsearchService,
    http.Client? client,
    ApiCredentialStore? credentialStore,
  })  : _jsearch = jsearchService ??
            JSearchService(
              client: client,
              credentialStore: credentialStore,
              useBackend: client == null && credentialStore == null,
            ),
        _ownsJSearchService = jsearchService == null;

  static const _storageKeyJobs = 'resumer_cached_jobs_v2';
  static const _storageKeySearch = 'resumer_last_search_v2';

  /// Test seam retained for widget tests so they never access the network.
  static Future<List<JobOpening>> Function(Map<String, dynamic> params)?
      debugSearchOverride;

  final JSearchService _jsearch;
  final bool _ownsJSearchService;

  bool lastSearchSucceeded = false;
  String? lastError;
  int? lastStatusCode;
  int lastTotalFound = 0;
  int lastPageJobCount = 0;
  String? _nextCursor;

  bool get hasMore => _nextCursor != null;

  String get sourceLabel =>
      lastSearchSucceeded ? 'Live via JSearch' : 'Offline / Cached';

  Future<List<JobOpening>> searchJobs({
    String? query,
    String? location,
    String? country,
    int page = 1,
    int numPages = 1,
    String? datePosted,
    bool? remoteJobsOnly,
    String? employmentTypes,
    List<String> keywords = const [],
    List<String> jobTypes = const [],
    List<String> experienceLevels = const [],
    bool? remote,
    int limit = 10,
    List<CareerItem> careerItems = const [],
  }) async {
    lastSearchSucceeded = false;
    lastError = null;
    lastStatusCode = null;
    lastPageJobCount = 0;

    final effectiveQuery = (query?.trim().isNotEmpty ?? false)
        ? query!.trim()
        : keywords
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .join(' ');
    final effectiveEmploymentTypes = employmentTypes ??
        (jobTypes.isEmpty
            ? null
            : jobTypes
                .map(_jsearchEmploymentType)
                .whereType<String>()
                .join(','));
    final effectiveRemote = remoteJobsOnly ?? remote;
    final requestParams = <String, dynamic>{
      'query': effectiveQuery.isEmpty ? 'jobs' : effectiveQuery,
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      if (country != null && country.trim().isNotEmpty)
        'country': country.trim(),
      'page': page,
      'numPages': numPages,
      if (datePosted != null) 'datePosted': datePosted,
      if (effectiveRemote != null) 'remoteJobsOnly': effectiveRemote,
      if (effectiveEmploymentTypes != null &&
          effectiveEmploymentTypes.isNotEmpty)
        'employmentTypes': effectiveEmploymentTypes,
    };
    unawaited(saveLastSearch(requestParams));

    final override = debugSearchOverride;
    if (override != null) {
      final jobs = await override(requestParams);
      lastSearchSucceeded = true;
      lastTotalFound = jobs.length;
      lastPageJobCount = jobs.length;
      return jobs;
    }

    try {
      if (page == 1) _nextCursor = null;
      final response = await _jsearch.searchJobs(
        query: requestParams['query'] as String,
        location: location,
        country: country,
        cursor: page > 1 ? _nextCursor : null,
        numPages: numPages,
        datePosted: datePosted,
        remoteJobsOnly: effectiveRemote,
        employmentTypes: effectiveEmploymentTypes,
      );
      final evidenceTokens = _extractEvidenceTokens(careerItems);
      final jobs = <JobOpening>[];
      final seen = <String>{};
      for (final job in response.jobs) {
        final dedupKey = job.deduplicationKey;
        if (dedupKey == null || !seen.add(dedupKey)) continue;
        final opening = _toJobOpening(job, evidenceTokens);
        if (opening != null) jobs.add(opening);
      }

      lastSearchSucceeded = true;
      lastStatusCode = response.statusCode;
      lastTotalFound = jobs.length;
      lastPageJobCount = response.jobs.length;
      _nextCursor = response.nextCursor;
      if (page == 1) unawaited(saveJobs(jobs));
      return jobs;
    } on JSearchException catch (error) {
      lastError = error.message;
      lastStatusCode = error.statusCode;
      return const [];
    }
  }

  JobOpening? _toJobOpening(Job job, Set<String> evidenceTokens) {
    final id = job.id.trim().isNotEmpty
        ? job.id.trim()
        : (job.applyUrl ?? job.jobUrl ?? '');
    if (id.isEmpty || job.title.isEmpty || job.company.isEmpty) return null;

    final location = job.location ??
        [job.city, job.state, job.country]
            .whereType<String>()
            .where((part) => part.trim().isNotEmpty)
            .join(', ');
    final description =
        job.description ?? 'Description not provided by source.';
    return JobOpening(
      id: id,
      title: job.title,
      companyName: job.company,
      location: location.isEmpty ? 'Location not provided' : location,
      workMode: job.isRemote ? 'Remote' : 'On-site',
      employmentType: job.employmentType ?? 'Type not provided',
      salaryLabel: _salaryLabel(job),
      postedAt: DateTime.tryParse(job.postedAt ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      description: description,
      skills: job.skills,
      matchScore: _calculateScore(
        job.title,
        description,
        job.skills,
        evidenceTokens,
      ),
      url: job.applyUrl ?? job.jobUrl,
      companyLogoUrl: job.companyLogo,
    );
  }

  static String _salaryLabel(Job job) {
    final currency = job.salaryCurrency;
    final period = job.salaryPeriod;
    final suffix = period == null ? '' : ' / ${period.toLowerCase()}';
    if (job.salaryMin != null && job.salaryMax != null) {
      return '${currency ?? ''} ${_number(job.salaryMin!)} – ${_number(job.salaryMax!)}$suffix'
          .trim();
    }
    if (job.salaryMin != null) {
      return '${currency ?? ''} ${_number(job.salaryMin!)}+$suffix'.trim();
    }
    if (job.salaryMax != null) {
      return 'Up to ${currency ?? ''} ${_number(job.salaryMax!)}$suffix'
          .replaceAll(RegExp(r' +'), ' ')
          .trim();
    }
    return 'Salary not provided';
  }

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  static String? _jsearchEmploymentType(String value) {
    return switch (value.trim().toLowerCase()) {
      'full-time' || 'fulltime' => 'FULLTIME',
      'part-time' || 'parttime' => 'PARTTIME',
      'contract' || 'contractor' => 'CONTRACTOR',
      'intern' || 'internship' => 'INTERN',
      _ => null,
    };
  }

  int _calculateScore(
    String title,
    String description,
    List<String> skills,
    Set<String> evidenceTokens,
  ) {
    final text = '$title $description ${skills.join(' ')}'.toLowerCase();
    final matches = evidenceTokens.where(text.contains).length;
    return math.min(99, 50 + matches * 7);
  }

  Set<String> _extractEvidenceTokens(List<CareerItem> items) {
    return {
      for (final item in items)
        ...'${item.title} ${item.subtitle ?? ''} ${item.bullets.join(' ')}'
            .toLowerCase()
            .split(RegExp(r'[^a-z0-9+#.]+'))
            .where((token) => token.length > 2),
    };
  }

  Future<void> saveJobs(List<JobOpening> jobs) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _storageKeyJobs,
        encodeList<JobOpening>(jobs, (job) => job.toJson()),
      );
    } on Object {
      // Best-effort cache. Credentials are never stored here.
    }
  }

  Future<List<JobOpening>> getStoredJobs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKeyJobs);
      final decoded = raw == null ? null : jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final item in decoded)
          if (item is Map<String, dynamic>)
            JobOpeningSerialization.fromJson(item),
      ];
    } on Object {
      return const [];
    }
  }

  Future<void> clearJobs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKeyJobs);
    } on Object {
      // Best-effort cache cleanup.
    }
  }

  Future<Map<String, dynamic>?> getLastSearch() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKeySearch);
      final decoded = raw == null ? null : jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on Object {
      return null;
    }
  }

  Future<void> saveLastSearch(Map<String, dynamic> query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKeySearch, jsonEncode(query));
    } on Object {
      // Best-effort persistence of non-sensitive search preferences.
    }
  }

  void dispose() {
    if (_ownsJSearchService) _jsearch.dispose();
  }
}
