/// Domain models for the Resumer companion app.
///
/// These are pure Dart — no Flutter imports — so the data layer can be
/// swapped for a real API later without touching the UI.
library;

/// A single person using the app.
class User {
  const User({
    required this.name,
    required this.email,
    required this.headline,
    this.phone = '',
    this.location = '',
  });

  final String name;
  final String email;
  final String headline;
  final String phone;
  final String location;

  String get firstName => name.split(' ').first;
  String get initials => name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0])
      .take(2)
      .join()
      .toUpperCase();

  User copyWith({
    String? name,
    String? email,
    String? headline,
    String? phone,
    String? location,
  }) {
    return User(
      name: name ?? this.name,
      email: email ?? this.email,
      headline: headline ?? this.headline,
      phone: phone ?? this.phone,
      location: location ?? this.location,
    );
  }
}

/// A discoverable role shown on the home feed.
class JobOpening {
  const JobOpening({
    required this.id,
    required this.title,
    required this.companyName,
    required this.location,
    required this.workMode,
    required this.employmentType,
    required this.salaryLabel,
    required this.postedAt,
    required this.description,
    required this.skills,
    required this.matchScore,
    this.url,
    this.companyLogoUrl,
    this.saved = false,
  });

  final String id;
  final String title;
  final String companyName;
  final String location;
  final String workMode;
  final String employmentType;
  final String salaryLabel;
  final DateTime postedAt;
  final String description;
  final List<String> skills;
  final int matchScore;

  /// Direct link to the posting on the source board, used to open the
  /// application page in the browser.
  final String? url;
  final String? companyLogoUrl;
  final bool saved;

  JobOpening copyWith({bool? saved, String? url, String? companyLogoUrl}) {
    return JobOpening(
      id: id,
      title: title,
      companyName: companyName,
      location: location,
      workMode: workMode,
      employmentType: employmentType,
      salaryLabel: salaryLabel,
      postedAt: postedAt,
      description: description,
      skills: skills,
      matchScore: matchScore,
      url: url ?? this.url,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      saved: saved ?? this.saved,
    );
  }
}

enum ResumeType { master, tailored }

extension ResumeTypeX on ResumeType {
  String get label => this == ResumeType.master ? 'Master' : 'Tailored';

  String get hint => this == ResumeType.master
      ? 'Your full career history — the source of truth.'
      : 'A focused resume shaped for one specific role.';
}

enum ResumeStatus { draft, ready }

extension ResumeStatusX on ResumeStatus {
  String get label => this == ResumeStatus.ready ? 'Ready' : 'Draft';
}

/// A version snapshot of a resume (history is preserved like the web app).
class ResumeVersion {
  const ResumeVersion({
    required this.id,
    required this.label,
    required this.createdAt,
    this.isCurrent = false,
  });

  final String id;
  final String label;
  final DateTime createdAt;
  final bool isCurrent;
}

class Resume {
  const Resume({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.updatedAt,
    required this.versions,
    this.targetRole,
    this.targetCompany,
    this.matchScore = 0,
    this.tailoredBullets = const [],
  });

  final String id;
  final String name;
  final ResumeType type;
  final ResumeStatus status;
  final DateTime updatedAt;
  final List<ResumeVersion> versions;

  /// Target role/company for tailored resumes.
  final String? targetRole;
  final String? targetCompany;

  /// AI match score 0–100 for tailored resumes.
  final int matchScore;

  /// AI suggestions explicitly accepted by the user for this version.
  final List<String> tailoredBullets;

  Resume copyWith({
    String? name,
    ResumeStatus? status,
    int? matchScore,
    DateTime? updatedAt,
    List<ResumeVersion>? versions,
    List<String>? tailoredBullets,
    String? targetRole,
    String? targetCompany,
  }) {
    return Resume(
      id: id,
      name: name ?? this.name,
      type: type,
      status: status ?? this.status,
      updatedAt: updatedAt ?? this.updatedAt,
      versions: versions ?? this.versions,
      targetRole: targetRole ?? this.targetRole,
      targetCompany: targetCompany ?? this.targetCompany,
      matchScore: matchScore ?? this.matchScore,
      tailoredBullets: tailoredBullets ?? this.tailoredBullets,
    );
  }
}

enum ApplicationStatus {
  saved,
  preparing,
  applied,
  assessment,
  interview,
  offer,
  rejected,
}

extension ApplicationStatusX on ApplicationStatus {
  String get label => switch (this) {
        ApplicationStatus.saved => 'Saved',
        ApplicationStatus.preparing => 'Preparing',
        ApplicationStatus.applied => 'Applied',
        ApplicationStatus.assessment => 'Assessment',
        ApplicationStatus.interview => 'Interview',
        ApplicationStatus.offer => 'Offer',
        ApplicationStatus.rejected => 'Rejected',
      };

  /// Whether this application still needs the candidate's attention.
  bool get needsAction => switch (this) {
        ApplicationStatus.saved ||
        ApplicationStatus.preparing ||
        ApplicationStatus.assessment ||
        ApplicationStatus.interview =>
          true,
        _ => false,
      };
}

class Application {
  const Application({
    required this.id,
    required this.jobTitle,
    required this.companyName,
    required this.status,
    required this.matchScore,
    required this.updatedAt,
    this.location,
    this.remote = false,
    this.appliedByAi = false,
  });

  final String id;
  final String jobTitle;
  final String companyName;
  final ApplicationStatus status;
  final int matchScore;
  final DateTime updatedAt;
  final String? location;
  final bool remote;

  /// True when the application was submitted automatically by AI auto-apply.
  final bool appliedByAi;

  Application copyWith({
    ApplicationStatus? status,
    DateTime? updatedAt,
    bool? appliedByAi,
  }) {
    return Application(
      id: id,
      jobTitle: jobTitle,
      companyName: companyName,
      status: status ?? this.status,
      matchScore: matchScore,
      updatedAt: updatedAt ?? this.updatedAt,
      location: location,
      remote: remote,
      appliedByAi: appliedByAi ?? this.appliedByAi,
    );
  }
}

enum CareerItemType {
  education,
  experience,
  project,
  skill,
  course,
  interview,
}

extension CareerItemTypeX on CareerItemType {
  String get label => switch (this) {
        CareerItemType.education => 'Education',
        CareerItemType.experience => 'Experience',
        CareerItemType.project => 'Projects',
        CareerItemType.skill => 'Skills',
        CareerItemType.course => 'Courses',
        CareerItemType.interview => 'Interviews',
      };

  String get iconHint => switch (this) {
        CareerItemType.education => 'School',
        CareerItemType.experience => 'Briefcase',
        CareerItemType.project => 'Rocket',
        CareerItemType.skill => 'Bolt',
        CareerItemType.course => 'Award',
        CareerItemType.interview => 'Mic',
      };
}

/// A piece of evidence in the career vault — the grounding boundary for AI
/// suggestions. Nothing invented.
class CareerItem {
  const CareerItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.dateRange,
    this.bullets = const [],
    this.verified = false,
  });

  final String id;
  final CareerItemType type;
  final String title;
  final String? subtitle;
  final String? dateRange;
  final List<String> bullets;
  final bool verified;
}

enum PlanId { free, pro }

class Plan {
  const Plan({
    required this.id,
    required this.name,
    required this.priceLabel,
    required this.features,
  });

  final PlanId id;
  final String name;
  final String priceLabel;
  final List<String> features;
}

class CreditPack {
  const CreditPack({
    required this.id,
    required this.name,
    required this.credits,
    required this.priceLabel,
    required this.description,
  });

  final String id;
  final String name;
  final int credits;
  final String priceLabel;
  final String description;
}

// ---------------------------------------------------------------------------
// Courses / learning
// ---------------------------------------------------------------------------

/// A single multiple-choice question in a course's final exam.
class CourseTestQuestion {
  const CourseTestQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.topic = '',
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String topic;
}

/// A course lesson with optional hosted video and downloadable resources.
class CourseLesson {
  const CourseLesson({
    required this.id,
    required this.title,
    required this.durationLabel,
    required this.content,
    this.keyPoints = const [],
    this.videoUrl,
    this.resources = const [],
    this.moduleName = '',
  });

  final String id;
  final String title;

  /// e.g. "12 min" — shown next to the lesson in the list.
  final String durationLabel;

  /// The lesson body, shown in the reader.
  final String content;

  /// Short bullet takeaways shown under the reader (mirrors the "Notes" tab).
  final List<String> keyPoints;
  final String? videoUrl;
  final List<Map<String, String>> resources;
  final String moduleName;
}

/// A course catalog record, serialized for published Supabase content.
class Course {
  const Course({
    required this.id,
    required this.title,
    required this.category,
    required this.instructor,
    required this.level,
    required this.priceLabel,
    required this.rating,
    required this.studentsLabel,
    required this.description,
    required this.lessons,
    this.finalTest = const [],
    this.isFree = false,
    this.status = 'approved',
    this.ownerId,
    this.moduleNames = const [],
  });

  final String id;
  final String title;
  final String category;
  final String instructor;
  final String level;
  final String priceLabel;
  final double rating;
  final String studentsLabel;
  final String description;
  final List<CourseLesson> lessons;
  final List<CourseTestQuestion> finalTest;
  final bool isFree;
  final String status;
  final String? ownerId;
  final List<String> moduleNames;

  Course copyWith({
    String? title,
    String? category,
    String? instructor,
    String? description,
    List<CourseLesson>? lessons,
    List<CourseTestQuestion>? finalTest,
    List<String>? moduleNames,
    String? status,
  }) =>
      Course(
        id: id,
        title: title ?? this.title,
        category: category ?? this.category,
        instructor: instructor ?? this.instructor,
        level: level,
        priceLabel: priceLabel,
        rating: rating,
        studentsLabel: studentsLabel,
        description: description ?? this.description,
        lessons: lessons ?? this.lessons,
        finalTest: finalTest ?? this.finalTest,
        isFree: isFree,
        status: status ?? this.status,
        ownerId: ownerId,
        moduleNames: moduleNames ?? this.moduleNames,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'category': category,
        'instructor': instructor,
        'level': level,
        'priceLabel': priceLabel,
        'rating': rating,
        'studentsLabel': studentsLabel,
        'description': description,
        'lessons': [
          for (final lesson in lessons)
            {
              'id': lesson.id,
              'title': lesson.title,
              'durationLabel': lesson.durationLabel,
              'content': lesson.content,
              'keyPoints': lesson.keyPoints,
              if (lesson.videoUrl != null) 'videoUrl': lesson.videoUrl,
              'resources': lesson.resources,
              'moduleName': lesson.moduleName,
            },
        ],
        'lessonIds': [for (final lesson in lessons) lesson.id],
        'finalTest': [
          for (final question in finalTest)
            {
              'question': question.question,
              'options': question.options,
              'correctIndex': question.correctIndex,
              'topic': question.topic,
            },
        ],
        'isFree': isFree,
        'status': status,
        if (ownerId != null) 'ownerId': ownerId,
        'moduleNames': moduleNames,
      };

  static Course fromMap(String id, Map<String, dynamic> map) => Course(
        id: id,
        title: map['title'] as String? ?? '',
        category: map['category'] as String? ?? 'General',
        instructor: map['instructor'] as String? ?? '',
        level: map['level'] as String? ?? 'Beginner',
        priceLabel: map['priceLabel'] as String? ?? 'Free',
        rating: (map['rating'] as num?)?.toDouble() ?? 0,
        studentsLabel: map['studentsLabel'] as String? ?? '',
        description: map['description'] as String? ?? '',
        lessons: [
          for (final item in map['lessons'] as List? ?? const [])
            if (item is Map<String, dynamic>)
              CourseLesson(
                id: item['id'] as String? ?? '',
                title: item['title'] as String? ?? '',
                durationLabel: item['durationLabel'] as String? ?? '',
                content: item['content'] as String? ?? '',
                keyPoints:
                    List<String>.from(item['keyPoints'] as List? ?? const []),
                videoUrl: item['videoUrl'] as String?,
                resources: [
                  for (final resource in item['resources'] as List? ?? const [])
                    if (resource is Map) Map<String, String>.from(resource),
                ],
                moduleName: item['moduleName'] as String? ?? '',
              ),
        ],
        finalTest: [
          for (final item in map['finalTest'] as List? ?? const [])
            if (item is Map<String, dynamic>)
              CourseTestQuestion(
                question: item['question'] as String? ?? '',
                options:
                    List<String>.from(item['options'] as List? ?? const []),
                correctIndex: item['correctIndex'] as int? ?? -1,
                topic: item['topic'] as String? ?? '',
              ),
        ],
        isFree: map['isFree'] as bool? ?? false,
        status: map['status'] as String? ?? 'draft',
        ownerId: map['ownerId'] as String?,
        moduleNames: List<String>.from(map['moduleNames'] as List? ?? const []),
      );
}

/// The user's progress through one enrolled course. Persisted locally.
class CourseEnrollment {
  const CourseEnrollment({
    required this.courseId,
    required this.enrolledAt,
    this.completedLessonIds = const [],
    this.lastLessonId,
    this.testScore,
    this.testPassed = false,
    this.certificateId,
    this.certificateIssuedAt,
    this.attemptCount = 0,
    this.weakTopics = const [],
  });

  final String courseId;
  final DateTime enrolledAt;
  final List<String> completedLessonIds;
  final String? lastLessonId;

  /// Score 0–100 from the most recent final-exam attempt.
  final int? testScore;
  final bool testPassed;

  /// Set once the exam is passed; certificate is issued exactly once.
  final String? certificateId;
  final DateTime? certificateIssuedAt;
  final int attemptCount;
  final List<String> weakTopics;

  bool get hasCertificate => certificateId != null;

  CourseEnrollment copyWith({
    List<String>? completedLessonIds,
    String? lastLessonId,
    int? testScore,
    bool? testPassed,
    String? certificateId,
    DateTime? certificateIssuedAt,
    int? attemptCount,
    List<String>? weakTopics,
  }) {
    return CourseEnrollment(
      courseId: courseId,
      enrolledAt: enrolledAt,
      completedLessonIds: completedLessonIds ?? this.completedLessonIds,
      lastLessonId: lastLessonId ?? this.lastLessonId,
      testScore: testScore ?? this.testScore,
      testPassed: testPassed ?? this.testPassed,
      certificateId: certificateId ?? this.certificateId,
      certificateIssuedAt: certificateIssuedAt ?? this.certificateIssuedAt,
      attemptCount: attemptCount ?? this.attemptCount,
      weakTopics: weakTopics ?? this.weakTopics,
    );
  }
}

/// Human review product — ₹499 one-time detailed review.
const String humanReviewName = 'Human resume review';
const String humanReviewPrice = '₹499';
const String humanReviewDescription =
    'A detailed review of your tailored resume by an experienced reviewer within 48 hours.';
