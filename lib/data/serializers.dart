import 'dart:convert';


import '../models/models.dart';

/// JSON (de)serialization for the models persisted in [AppState].
///
/// Keys are intentionally short and stable — the blob lives in
/// SharedPreferences and only ever read by this app.
extension UserSerialization on User {
  Map<String, dynamic> toJson() => {
        'n': name,
        'e': email,
        'h': headline,
        'p': phone,
        'l': location,
      };

  static User fromJson(Map<String, dynamic> json) => User(
        name: json['n'] as String? ?? '',
        email: json['e'] as String? ?? '',
        headline: json['h'] as String? ?? '',
        phone: json['p'] as String? ?? '',
        location: json['l'] as String? ?? '',
      );
}

extension CareerItemSerialization on CareerItem {
  Map<String, dynamic> toJson() => {
        'id': id,
        't': type.name,
        'ti': title,
        if (subtitle != null) 's': subtitle,
        if (dateRange != null) 'd': dateRange,
        'b': bullets,
        'v': verified,
      };

  static CareerItem fromJson(Map<String, dynamic> json) => CareerItem(
        id: json['id'] as String,
        type: CareerItemType.values.firstWhere((t) => t.name == json['t'],
            orElse: () => CareerItemType.skill),
        title: json['ti'] as String? ?? '',
        subtitle: json['s'] as String?,
        dateRange: json['d'] as String?,
        bullets: [...(json['b'] as List?)?.whereType<String>() ?? const []],
        verified: json['v'] as bool? ?? false,
      );
}

extension ResumeVersionSerialization on ResumeVersion {
  Map<String, dynamic> toJson() => {
        'id': id,
        'l': label,
        'c': createdAt.millisecondsSinceEpoch,
        'cur': isCurrent,
      };

  static ResumeVersion fromJson(Map<String, dynamic> json) => ResumeVersion(
        id: json['id'] as String,
        label: json['l'] as String? ?? '',
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['c'] as int? ?? 0),
        isCurrent: json['cur'] as bool? ?? false,
      );
}

extension ResumeSerialization on Resume {
  Map<String, dynamic> toJson() => {
        'id': id,
        'nm': name,
        'ty': type.name,
        'st': status.name,
        'u': updatedAt.millisecondsSinceEpoch,
        'v': [for (final version in versions) version.toJson()],
        if (targetRole != null) 'tr': targetRole,
        if (targetCompany != null) 'tc': targetCompany,
        'ms': matchScore,
        'tb': tailoredBullets,
      };

  static Resume fromJson(Map<String, dynamic> json) => Resume(
        id: json['id'] as String,
        name: json['nm'] as String? ?? '',
        type: ResumeType.values.firstWhere((t) => t.name == json['ty'],
            orElse: () => ResumeType.master),
        status: ResumeStatus.values.firstWhere((s) => s.name == json['st'],
            orElse: () => ResumeStatus.draft),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(json['u'] as int? ?? 0),
        versions: [
          for (final version in (json['v'] as List?) ?? const [])
            if (version is Map<String, dynamic>)
              ResumeVersionSerialization.fromJson(version),
        ],
        targetRole: json['tr'] as String?,
        targetCompany: json['tc'] as String?,
        matchScore: json['ms'] as int? ?? 0,
        tailoredBullets: [
          ...(json['tb'] as List?)?.whereType<String>() ?? const []
        ],
      );
}

extension ApplicationStatusSerialization on ApplicationStatus {
  static ApplicationStatus fromName(String? name) => ApplicationStatus.values
      .firstWhere((s) => s.name == name, orElse: () => ApplicationStatus.saved);
}

extension ApplicationSerialization on Application {
  Map<String, dynamic> toJson() => {
        'id': id,
        'jt': jobTitle,
        'cn': companyName,
        'st': status.name,
        'ms': matchScore,
        'u': updatedAt.millisecondsSinceEpoch,
        if (location != null) 'l': location,
        'r': remote,
        'ai': appliedByAi,
      };

  static Application fromJson(Map<String, dynamic> json) => Application(
        id: json['id'] as String,
        jobTitle: json['jt'] as String? ?? '',
        companyName: json['cn'] as String? ?? '',
        status: ApplicationStatusSerialization.fromName(json['st'] as String?),
        matchScore: json['ms'] as int? ?? 0,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(json['u'] as int? ?? 0),
        location: json['l'] as String?,
        remote: json['r'] as bool? ?? false,
        appliedByAi: json['ai'] as bool? ?? false,
      );
}

extension JobOpeningSerialization on JobOpening {
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'companyName': companyName,
        'location': location,
        'workMode': workMode,
        'employmentType': employmentType,
        'salaryLabel': salaryLabel,
        'postedAt': postedAt.toIso8601String(),
        'description': description,
        'skills': skills,
        'matchScore': matchScore,
        if (url != null) 'url': url,
        'saved': saved,
      };

  static JobOpening fromJson(Map<String, dynamic> json) => JobOpening(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        companyName: json['companyName'] as String? ?? '',
        location: json['location'] as String? ?? 'Location not specified',
        workMode: json['workMode'] as String? ?? 'On-site',
        employmentType: json['employmentType'] as String? ?? 'Full-time',
        salaryLabel: json['salaryLabel'] as String? ?? 'Competitive salary',
        postedAt: DateTime.tryParse(json['postedAt'] as String? ?? '') ??
            DateTime.now(),
        description: json['description'] as String? ?? '',
        skills: [...(json['skills'] as List?)?.whereType<String>() ?? const []],
        matchScore: json['matchScore'] as int? ?? 50,
        url: json['url'] as String?,
        saved: json['saved'] as bool? ?? false,
      );
}

extension CourseEnrollmentSerialization on CourseEnrollment {
  Map<String, dynamic> toJson() => {
        'cid': courseId,
        'e': enrolledAt.millisecondsSinceEpoch,
        'done': completedLessonIds,
        if (lastLessonId != null) 'll': lastLessonId,
        if (testScore != null) 'ts': testScore,
        'tp': testPassed,
        if (certificateId != null) 'certId': certificateId,
        if (certificateIssuedAt != null)
          'certAt': certificateIssuedAt!.millisecondsSinceEpoch,
        'attemptCount': attemptCount,
        'weakTopics': weakTopics,
      };

  static CourseEnrollment fromJson(Map<String, dynamic> json) =>
      CourseEnrollment(
        courseId: json['cid'] as String? ?? '',
        enrolledAt: DateTime.fromMillisecondsSinceEpoch(json['e'] as int? ?? 0),
        completedLessonIds: [
          ...(json['done'] as List?)?.whereType<String>() ?? const []
        ],
        lastLessonId: json['ll'] as String?,
        testScore: json['ts'] as int? ?? json['testScore'] as int?,
        testPassed: json['tp'] as bool? ?? json['testPassed'] as bool? ?? false,
        certificateId:
            json['certId'] as String? ?? json['certificateId'] as String?,
        certificateIssuedAt: _dateTimeFromStoredValue(
          json['certAt'] ?? json['certificateIssuedAt'],
        ),
        attemptCount: json['attemptCount'] as int? ?? 0,
        weakTopics: List<String>.from(json['weakTopics'] as List? ?? const []),
      );

  static DateTime? _dateTimeFromStoredValue(Object? value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is DateTime) return value;
    return null;
  }
}

String encodeList<T>(List<T> items, Map<String, dynamic> Function(T) toMap) =>
    jsonEncode([for (final item in items) toMap(item)]);
