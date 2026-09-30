/// A null-safe, API-facing representation of a JSearch job result.
class Job {
  const Job({
    required this.id,
    required this.title,
    required this.company,
    this.companyLogo,
    this.location,
    this.city,
    this.state,
    this.country,
    required this.isRemote,
    this.employmentType,
    this.postedAt,
    this.salaryMin,
    this.salaryMax,
    this.salaryCurrency,
    this.salaryPeriod,
    this.description,
    this.qualifications = const [],
    this.responsibilities = const [],
    this.skills = const [],
    this.jobUrl,
    this.applyUrl,
    this.source,
  });

  final String id;
  final String title;
  final String company;
  final String? companyLogo;
  final String? location;
  final String? city;
  final String? state;
  final String? country;
  final bool isRemote;
  final String? employmentType;
  final String? postedAt;
  final double? salaryMin;
  final double? salaryMax;
  final String? salaryCurrency;
  final String? salaryPeriod;
  final String? description;
  final List<String> qualifications;
  final List<String> responsibilities;
  final List<String> skills;
  final String? jobUrl;
  final String? applyUrl;
  final String? source;

  factory Job.fromJSearchJson(Map<String, dynamic> json) {
    final highlights = _map(json['job_highlights']);
    return Job(
      id: _string(json['job_id']) ?? '',
      title: _string(json['job_title']) ?? '',
      company: _string(json['employer_name']) ?? '',
      companyLogo: _string(json['employer_logo']),
      location: _string(json['job_location']),
      city: _string(json['job_city']),
      state: _string(json['job_state']),
      country: _string(json['job_country']),
      isRemote: json['job_is_remote'] == true ||
          _string(json['work_arrangement'])?.toLowerCase() == 'remote',
      employmentType: _string(json['job_employment_type']),
      postedAt: _string(
        json['job_posted_at_datetime_utc'] ?? json['job_posted_at'],
      ),
      salaryMin: _double(json['job_min_salary']),
      salaryMax: _double(json['job_max_salary']),
      salaryCurrency: _string(json['job_salary_currency']),
      salaryPeriod: _string(json['job_salary_period']),
      description: _string(json['job_description']),
      qualifications: _stringList(highlights?['Qualifications']),
      responsibilities: _stringList(highlights?['Responsibilities']),
      skills: _stringList(
        json['required_technologies'] ??
            json['job_required_skills'] ??
            highlights?['Skills'],
      ),
      jobUrl: _validWebUrl(json['job_google_link']),
      applyUrl: _validWebUrl(json['job_apply_link']),
      source: _string(json['job_publisher']),
    );
  }

  /// JSearch's stable ID, with its returned URLs as documented fallbacks.
  String? get deduplicationKey {
    if (id.trim().isNotEmpty) return 'id:${id.trim()}';
    if (applyUrl != null) return 'url:$applyUrl';
    if (jobUrl != null) return 'url:$jobUrl';
    return null;
  }

  static Map<String, dynamic>? _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  static String? _string(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _double(Object? value) {
    if (value is num) return value.toDouble();
    return value is String ? double.tryParse(value) : null;
  }

  static List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return [
      for (final item in value)
        if (_string(item) case final text?) text,
    ];
  }

  static String? _validWebUrl(Object? value) {
    final text = _string(value);
    final uri = text == null ? null : Uri.tryParse(text);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    return uri.toString();
  }
}
