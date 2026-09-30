import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb_auth;

import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/cloud_data_service.dart';
import 'course_catalog.dart';
import 'matching.dart';
import 'serializers.dart';

/// The app's repository.
///
/// Holds all state and exposes mutations. Screens read it through [AppScope]
/// and rebuild automatically when it notifies. Everything the user creates —
/// profile, career vault, master and tailored resumes, tracker, preferences —
/// is persisted locally on every change and restored on launch, so onboarding
/// and login are only ever asked once. Job feeds are refreshed from JSearch
/// each session.
class AppState extends ChangeNotifier {
  AppState()
      : user = const User(name: '', email: '', headline: ''),
        careerItems = [],
        resumes = [],
        applications = [],
        jobOpenings = [],
        courseEnrollments = [] {
    _observedAuthUid = AuthService.instance.currentUser?.id;
    _watchAuth();
  }

  static const String _storageKey = 'resumer_state_v1';
  static const String _storageOwnerKey = 'resumer_state_owner_v1';
  final CloudDataService _cloud = CloudDataService();

  StreamSubscription<sb_auth.User?>? _authSubscription;
  String? _observedAuthUid;

  /// Restores everything persisted from previous sessions. Safe to call when
  /// nothing was saved yet — the state simply stays empty.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = AuthService.instance.currentUser?.id;
    final raw = uid == null
        ? prefs.getString(_storageKey)
        : prefs.getString('${_storageKey}_$uid') ??
            (prefs.getString(_storageOwnerKey) == null ||
                    prefs.getString(_storageOwnerKey) == uid
                ? prefs.getString(_storageKey)
                : null);
    if (raw != null) {
      try {
        final map = jsonDecode(raw);
        if (map is Map<String, dynamic>) _restoreState(map);
      } on Object {
        // Corrupted local cache; try the authenticated cloud copy below.
      }
    }
    if (uid != null) {
      try {
        final cloudState = await _cloud.readUserState(uid);
        if (cloudState != null) _restoreState(cloudState);
      } on Object {
        // Local cache remains available when the cloud cannot be reached.
      }
    }
  }

  void _restoreState(Map<String, dynamic> map) {
    try {
      final savedUser = map['user'];
      if (savedUser is Map<String, dynamic>) {
        user = UserSerialization.fromJson(savedUser);
      }
      careerItems
        ..clear()
        ..addAll([
          for (final item in (map['careerItems'] as List?) ?? const [])
            if (item is Map<String, dynamic>)
              CareerItemSerialization.fromJson(item),
        ]);
      resumes
        ..clear()
        ..addAll([
          for (final resume in (map['resumes'] as List?) ?? const [])
            if (resume is Map<String, dynamic>)
              ResumeSerialization.fromJson(resume),
        ]);
      applications
        ..clear()
        ..addAll([
          for (final application in (map['applications'] as List?) ?? const [])
            if (application is Map<String, dynamic>)
              ApplicationSerialization.fromJson(application),
        ]);
      courseEnrollments
        ..clear()
        ..addAll([
          for (final enrollment
              in (map['courseEnrollments'] as List?) ?? const [])
            if (enrollment is Map<String, dynamic>)
              CourseEnrollmentSerialization.fromJson(enrollment),
        ]);

      darkMode = map['darkMode'] as bool? ?? false;
      notificationsEnabled = map['notifications'] as bool? ?? true;
      onboardingCompleted = map['onboarded'] as bool? ?? false;
      autoApplyEnabled = map['autoApply'] as bool? ?? false;
      preferredLocation = map['preferredLocation'] as String?;
      planId = PlanId.values.firstWhere(
        (p) => p.name == map['plan'],
        orElse: () => PlanId.free,
      );
    } on Object {
      // Ignore malformed snapshots and retain whatever data was restored.
    }
  }

  Timer? _saveDebounceTimer;

  /// Persists the full user-owned state. Never throws — if storage is
  /// unavailable the app simply continues in memory.
  Future<void> save() async {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = null;
    final uid = AuthService.instance.currentUser?.id;
    final snapshot = <String, dynamic>{
      'user': user.toJson(),
      'careerItems': [for (final item in careerItems) item.toJson()],
      'resumes': [for (final resume in resumes) resume.toJson()],
      'applications': [
        for (final application in applications) application.toJson(),
      ],
      'courseEnrollments': [
        for (final enrollment in courseEnrollments) enrollment.toJson(),
      ],
      'darkMode': darkMode,
      'notifications': notificationsEnabled,
      'onboarded': onboardingCompleted,
      'autoApply': autoApplyEnabled,
      'preferredLocation': preferredLocation,
      'plan': planId.name,
    };
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        uid == null ? _storageKey : '${_storageKey}_$uid',
        jsonEncode(snapshot),
      );
      if (uid != null) {
        await prefs.setString(_storageOwnerKey, uid);
        try {
          await _cloud.writeUserState(uid, snapshot);
        } on Object {
          // Keep the local cache authoritative until cloud access is restored.
        }
      }
    } on Object {
      // Storage unavailable — keep going in memory.
    }
  }

  /// Notifies listeners and schedules an async state save.
  void _commit() {
    notifyListeners();
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 150), () {
      unawaited(save());
    });
  }

  /// Keeps [isAuthenticated] in sync with the Supabase session and prefills
  /// name/email from the Google account so onboarding only asks for the rest.
  void _watchAuth() {
    _authSubscription?.cancel();
    _authSubscription =
        AuthService.instance.authStateChanges.listen((authUser) {
      final uid = authUser?.id;
      if (uid != _observedAuthUid) {
        _observedAuthUid = uid;
        unawaited(_switchAccount(authUser));
      } else {
        applyAuthUser(authUser);
      }
    });
  }

  Future<void> _switchAccount(sb_auth.User? authUser) async {
    _saveDebounceTimer?.cancel();
    user = const User(name: '', email: '', headline: '');
    careerItems.clear();
    resumes.clear();
    applications.clear();
    courseEnrollments.clear();
    darkMode = false;
    notificationsEnabled = true;
    onboardingCompleted = false;
    autoApplyEnabled = false;
    preferredLocation = null;
    planId = PlanId.free;
    isAuthenticated = authUser != null;
    if (authUser != null) await load();
    applyAuthUser(authUser);
  }

  void applyAuthUser(sb_auth.User? authUser) {
    isAuthenticated = authUser != null;
    if (authUser != null) {
      // Only prefill empty fields — never clobber names/emails the user has
      // edited in their profile (which is persisted by updateUser).
      final metadata = authUser.userMetadata ?? const <String, dynamic>{};
      final googleName =
          (metadata['full_name'] as String? ?? metadata['name'] as String? ?? '')
              .trim();
      user = user.copyWith(
        name: googleName.isNotEmpty && user.name.isEmpty ? googleName : null,
        email: authUser.email != null && user.email.isEmpty ? authUser.email : null,
      );
    }
    _commit();
  }

  User user;
  final List<CareerItem> careerItems;
  final List<Resume> resumes;
  final List<Application> applications;
  final List<JobOpening> jobOpenings;
  final List<CourseEnrollment> courseEnrollments;

  bool darkMode = false;
  bool notificationsEnabled = true;
  bool isAuthenticated = false;
  bool onboardingCompleted = false;
  PlanId planId = PlanId.free;

  /// When true, the AI auto-apply feature is enabled: open internships and
  /// jobs are tailored with the source master resume and applied automatically,
  /// and each such application is tagged as applied by AI.
  bool autoApplyEnabled = false;

  /// True when [jobOpenings] currently reflect live roles fetched by the
  /// in-app Dart agent rather than bundled demo openings.
  bool jobsAreLive = false;

  /// The user's preferred location for the Explore feed. When set, it is added
  /// to the JSearch query.
  String? preferredLocation;

  // ---- Derived values -----------------------------------------------------

  int get readyResumeCount =>
      resumes.where((r) => r.status == ResumeStatus.ready).length;

  int get activeApplicationCount =>
      applications.where((a) => a.status != ApplicationStatus.rejected).length;

  int get needsAttentionCount =>
      applications.where((a) => a.status.needsAction).length;

  int get offerCount =>
      applications.where((a) => a.status == ApplicationStatus.offer).length;

  int get interviewCount =>
      applications.where((a) => a.status == ApplicationStatus.interview).length;

  double get profileCompletion {
    const Map<CareerItemType, int> weights = {
      CareerItemType.education: 20,
      CareerItemType.experience: 30,
      CareerItemType.project: 20,
      CareerItemType.skill: 15,
      CareerItemType.course: 15,
    };
    var score = 0;
    for (final entry in weights.entries) {
      final count = careerItems.where((item) => item.type == entry.key).length;
      score += count > 0 ? entry.value : 0;
    }
    return score.clamp(0, 100).toDouble();
  }

  /// Recommended next action — mirrors the web platform's logic.
  String nextActionLabel() {
    if (resumes.isEmpty) return 'Create your first resume';
    if (readyResumeCount == 0) return 'Finish a resume';
    if (applications.isEmpty) return 'Track your first application';
    return 'Tailor a resume for a new role';
  }

  String nextActionDetail() {
    if (resumes.isEmpty) {
      return 'Upload a resume or add projects, internships, and skills as you go.';
    }
    if (readyResumeCount == 0) {
      return 'Open your resume and add the missing sections to make it ready.';
    }
    if (applications.isEmpty) {
      return 'Save the first role you apply to and watch it progress.';
    }
    return 'Paste a job description and get a transparent match report in minutes.';
  }

  // ---- Mutations ----------------------------------------------------------

  /// Signs the user out of Supabase; the auth listener flips
  /// [isAuthenticated] back to false.
  Future<void> logout() async {
    await AuthService.instance.signOut();
    applyAuthUser(null);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    if (_saveDebounceTimer?.isActive ?? false) {
      _saveDebounceTimer?.cancel();
      unawaited(save());
    }
    super.dispose();
  }

  void toggleDarkMode() {
    darkMode = !darkMode;
    _commit();
  }

  void toggleNotifications() {
    notificationsEnabled = !notificationsEnabled;
    _commit();
  }

  void setAutoApplyEnabled(bool enabled) {
    autoApplyEnabled = enabled;
    _commit();
  }

  void updateUser({
    required String name,
    required String email,
    required String phone,
    required String location,
    required String headline,
  }) {
    user = user.copyWith(
      name: name,
      email: email,
      phone: phone,
      location: location,
      headline: headline,
    );
    _commit();
  }

  void setPlan(PlanId id) {
    planId = id;
    _commit();
  }

  void completeOnboarding({
    required String name,
    required String email,
    required String phone,
    required String location,
    required String headline,
    required String degree,
    required String school,
    required String studyPeriod,
    required String role,
    required String company,
    required String achievement,
    required List<String> skills,
  }) {
    user = user.copyWith(
      name: name,
      email: email,
      phone: phone,
      location: location,
      headline: headline,
    );
    careerItems.removeWhere((item) => item.id.startsWith('basic-'));
    careerItems.insertAll(0, [
      CareerItem(
        id: 'basic-education',
        type: CareerItemType.education,
        title: degree,
        subtitle: school,
        dateRange: studyPeriod,
        verified: true,
      ),
      CareerItem(
        id: 'basic-experience',
        type: CareerItemType.experience,
        title: role,
        subtitle: company,
        bullets: achievement.isEmpty ? const [] : [achievement],
        verified: true,
      ),
      for (final skill in skills)
        CareerItem(
          id: 'basic-skill-${skill.toLowerCase().replaceAll(' ', '-')}',
          type: CareerItemType.skill,
          title: skill,
          verified: true,
        ),
    ]);
    final masterIndex = resumes.indexWhere(
      (resume) => resume.type == ResumeType.master,
    );
    if (masterIndex == -1) {
      resumes.insert(
        0,
        Resume(
          id: 'basic-${DateTime.now().microsecondsSinceEpoch}',
          name: '$name — Master',
          type: ResumeType.master,
          status: ResumeStatus.ready,
          updatedAt: DateTime.now(),
          versions: [
            ResumeVersion(
              id: 'basic-v-${DateTime.now().microsecondsSinceEpoch}',
              label: 'Basic resume created',
              createdAt: DateTime.now(),
              isCurrent: true,
            ),
          ],
        ),
      );
    } else {
      resumes[masterIndex] = resumes[masterIndex].copyWith(
        name: '$name — Master',
        updatedAt: DateTime.now(),
      );
    }
    onboardingCompleted = true;
    _commit();
  }

  void toggleJobSaved(String id) {
    final index = jobOpenings.indexWhere((job) => job.id == id);
    if (index == -1) return;
    jobOpenings[index] = jobOpenings[index].copyWith(
      saved: !jobOpenings[index].saved,
    );
    _commit();
  }

  /// Replaces the discoverable job feed, e.g. with live roles fetched from the
  /// web. [live] records whether the new feed came from a real source.
  void replaceJobOpenings(List<JobOpening> jobs, {bool live = false}) {
    final savedIds = {
      for (final job in jobOpenings)
        if (job.saved) job.id,
    };
    jobOpenings
      ..clear()
      ..addAll([
        for (final job in jobs)
          savedIds.contains(job.id) ? job.copyWith(saved: true) : job,
      ]);
    jobsAreLive = live;
    _commit();
  }

  /// Appends a page of jobs while deduplicating by JSearch ID, then URL.
  void appendJobOpenings(List<JobOpening> jobs, {bool live = true}) {
    final knownIds = jobOpenings.map((job) => job.id).toSet();
    final knownUrls = jobOpenings
        .map((job) => job.url)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toSet();
    for (final job in jobs) {
      if (knownIds.contains(job.id) ||
          (job.url != null && knownUrls.contains(job.url))) {
        continue;
      }
      jobOpenings.add(job);
      knownIds.add(job.id);
      if (job.url != null) knownUrls.add(job.url!);
    }
    jobsAreLive = live;
    _commit();
  }

  /// Sets (or clears) the preferred location used to search nearby roles.
  void setPreferredLocation(String? location) {
    final trimmed = location?.trim();
    preferredLocation = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    _commit();
  }

  /// Flips the local session gate directly, e.g. for flows that bypass the
  /// Auth listener (restored sessions, tests).
  void setAuthenticated(bool value) {
    if (isAuthenticated == value) return;
    isAuthenticated = value;
    _commit();
  }

  void trackJob(JobOpening job) {
    final exists = applications.any(
      (application) =>
          application.jobTitle == job.title &&
          application.companyName == job.companyName,
    );
    if (exists) return;
    addApplication(
      jobTitle: job.title,
      companyName: job.companyName,
      status: ApplicationStatus.saved,
      matchScore: job.matchScore,
      location: job.location,
      remote: job.workMode.toLowerCase() == 'remote',
    );
  }

  /// Records a submitted application for a role, typically from a tailored
  /// resume review. No-op when an application for the same role already exists.
  void applyToJob({
    required String jobTitle,
    required String companyName,
    required int matchScore,
    String? location,
    bool remote = false,
    bool appliedByAi = false,
  }) {
    final exists = applications.any(
      (application) =>
          application.jobTitle == jobTitle &&
          application.companyName == companyName,
    );
    if (exists) return;
    applications.insert(
      0,
      Application(
        id: 'app-${DateTime.now().microsecondsSinceEpoch}',
        jobTitle: jobTitle,
        companyName: companyName,
        status: ApplicationStatus.applied,
        matchScore: matchScore,
        updatedAt: DateTime.now(),
        location: location,
        remote: remote,
        appliedByAi: appliedByAi,
      ),
    );
    _commit();
  }

  /// Applies to a job on the user's behalf: saves a tailored resume derived
  /// from the master resume and records an application tagged as applied by AI.
  void aiApplyToJob({required JobOpening job, required MatchReport report}) {
    final exists = applications.any(
      (application) =>
          application.jobTitle == job.title &&
          application.companyName == job.companyName,
    );
    if (exists) return;

    final master =
        resumes.where((r) => r.type == ResumeType.master).firstOrNull;
    if (master != null) {
      saveTailoredResume(
        sourceResumeId: master.id,
        matchScore: report.score,
        targetRole: job.title,
        targetCompany: job.companyName,
        tailoredBullets: [
          for (final suggestion in report.suggestions)
            suggestion.rewrittenBullet,
        ],
      );
    }
    applications.insert(
      0,
      Application(
        id: 'ai-app-${DateTime.now().microsecondsSinceEpoch}',
        jobTitle: job.title,
        companyName: job.companyName,
        status: ApplicationStatus.applied,
        matchScore: report.score,
        updatedAt: DateTime.now(),
        location: job.location,
        remote: job.workMode.toLowerCase() == 'remote',
        appliedByAi: true,
      ),
    );
    _commit();
  }

  void createResume(String name, ResumeType type) {
    resumes.insert(
      0,
      Resume(
        id: 'res-${DateTime.now().microsecondsSinceEpoch}',
        name: name,
        type: type,
        status: ResumeStatus.draft,
        updatedAt: DateTime.now(),
        versions: [
          ResumeVersion(
            id: 'v-${DateTime.now().microsecondsSinceEpoch}',
            label: 'New draft',
            createdAt: DateTime.now(),
            isCurrent: true,
          ),
        ],
      ),
    );
    _commit();
  }

  /// Updates content that belongs to one resume from the preview editor.
  /// Empty target fields are stored as null so previously tailored metadata
  /// can be cleared as well as added.
  void updateResumeDetails({
    required String resumeId,
    required String name,
    required String targetRole,
    required String targetCompany,
    required List<String> tailoredBullets,
  }) {
    final index = resumes.indexWhere((resume) => resume.id == resumeId);
    if (index == -1) return;

    final current = resumes[index];
    resumes[index] = Resume(
      id: current.id,
      name: name.trim().isEmpty ? current.name : name.trim(),
      type: current.type,
      status: current.status,
      updatedAt: DateTime.now(),
      versions: current.versions,
      targetRole: targetRole.trim().isEmpty ? null : targetRole.trim(),
      targetCompany: targetCompany.trim().isEmpty ? null : targetCompany.trim(),
      matchScore: current.matchScore,
      tailoredBullets: tailoredBullets
          .map((bullet) => bullet.trim())
          .where((bullet) => bullet.isNotEmpty)
          .toList(),
    );
    _commit();
  }

  /// Imports fields extracted from a user-selected resume into the local
  /// career evidence and updates the current master resume.
  void importParsedResume({
    required String name,
    required String email,
    required String phone,
    required String location,
    required String headline,
    required String degree,
    required String school,
    required String graduation,
    required String role,
    required String company,
    required String experience,
    required List<String> skills,
    required List<String> bullets,
  }) {
    user = user.copyWith(
      name: name.isNotEmpty ? name : null,
      email: email.isNotEmpty ? email : null,
      phone: phone.isNotEmpty ? phone : null,
      location: location.isNotEmpty ? location : null,
      headline: headline.isNotEmpty ? headline : null,
    );
    careerItems.removeWhere((item) => item.id.startsWith('imported-'));
    final now = DateTime.now();
    var itemIndex = 0;
    void addItem(
      CareerItemType type,
      String title, {
      String? subtitle,
      String? dateRange,
      List<String> itemBullets = const [],
    }) {
      if (title.trim().isEmpty) return;
      careerItems.add(CareerItem(
        id: 'imported-${type.name}-${now.microsecondsSinceEpoch}-${itemIndex++}',
        type: type,
        title: title.trim(),
        subtitle: subtitle?.trim().isEmpty == true ? null : subtitle?.trim(),
        dateRange: dateRange?.trim().isEmpty == true ? null : dateRange?.trim(),
        bullets: itemBullets,
        verified: true,
      ));
    }

    addItem(CareerItemType.education, degree,
        subtitle: school, dateRange: graduation);
    final experienceBullets = <String>[
      if (experience.trim().isNotEmpty) experience.trim(),
      ...bullets.where((bullet) =>
          bullet.trim().isNotEmpty && bullet.trim() != experience.trim()),
    ];
    addItem(CareerItemType.experience, role,
        subtitle: company, itemBullets: experienceBullets);
    for (final skill in skills) {
      addItem(CareerItemType.skill, skill);
    }

    final resume = Resume(
      id: 'res-${now.microsecondsSinceEpoch}',
      name: '${name.isNotEmpty ? name : 'Imported'} — Master',
      type: ResumeType.master,
      status: ResumeStatus.ready,
      updatedAt: now,
      versions: [
        ResumeVersion(
          id: 'v-${now.microsecondsSinceEpoch}',
          label: 'Imported resume',
          createdAt: now,
          isCurrent: true,
        )
      ],
    );
    final existingMaster =
        resumes.indexWhere((item) => item.type == ResumeType.master);
    if (existingMaster == -1) {
      resumes.insert(0, resume);
    } else {
      resumes[existingMaster] = resume.copyWith(name: resume.name);
    }
    _commit();
  }

  /// Marks a resume as ready with a fresh current version and a match score.
  void finalizeTailored(String resumeId, int matchScore) {
    final index = resumes.indexWhere((r) => r.id == resumeId);
    if (index == -1) return;
    final resume = resumes[index];
    final versions = [
      for (final version in resume.versions)
        ResumeVersion(
          id: version.id,
          label: version.label,
          createdAt: version.createdAt,
          isCurrent: false,
        ),
      ResumeVersion(
        id: 't-${DateTime.now().microsecondsSinceEpoch}',
        label: 'Tailored $matchScore% match',
        createdAt: DateTime.now(),
        isCurrent: true,
      ),
    ];
    resumes[index] = resume.copyWith(
      status: ResumeStatus.ready,
      matchScore: matchScore,
      updatedAt: DateTime.now(),
      versions: versions,
    );
    _commit();
  }

  /// Saves a tailored resume derived from [sourceResumeId] and returns the id
  /// of the saved tailored resume, or null when the source was not found.
  String? saveTailoredResume({
    required String sourceResumeId,
    required int matchScore,
    required String targetRole,
    required String targetCompany,
    required List<String> tailoredBullets,
  }) {
    final sourceIndex =
        resumes.indexWhere((resume) => resume.id == sourceResumeId);
    if (sourceIndex == -1) return null;
    final source = resumes[sourceIndex];
    final now = DateTime.now();
    String savedId;
    if (source.type == ResumeType.tailored) {
      savedId = source.id;
      resumes[sourceIndex] = source.copyWith(
        status: ResumeStatus.ready,
        matchScore: matchScore,
        updatedAt: now,
        targetRole: targetRole,
        targetCompany: targetCompany,
        tailoredBullets: tailoredBullets,
        versions: [
          for (final version in source.versions)
            ResumeVersion(
              id: version.id,
              label: version.label,
              createdAt: version.createdAt,
              isCurrent: false,
            ),
          ResumeVersion(
            id: 'ai-${now.microsecondsSinceEpoch}',
            label: 'Gemini tailored · $matchScore% match',
            createdAt: now,
            isCurrent: true,
          ),
        ],
      );
    } else {
      // Upsert: re-tailoring (or exporting after tailoring) the same target
      // role must update the existing tailored resume instead of stacking
      // duplicates in the list.
      final existingIndex = resumes.indexWhere(
        (resume) =>
            resume.type == ResumeType.tailored &&
            resume.targetRole == targetRole &&
            resume.targetCompany == targetCompany,
      );
      final now2 = DateTime.now();
      if (existingIndex != -1) {
        final existing = resumes[existingIndex];
        savedId = existing.id;
        resumes[existingIndex] = existing.copyWith(
          status: ResumeStatus.ready,
          matchScore: matchScore,
          updatedAt: now,
          tailoredBullets: tailoredBullets,
          versions: [
            for (final version in existing.versions)
              ResumeVersion(
                id: version.id,
                label: version.label,
                createdAt: version.createdAt,
                isCurrent: false,
              ),
            ResumeVersion(
              id: 'ai-${now.microsecondsSinceEpoch}',
              label: 'Gemini tailored from ${source.name}',
              createdAt: now2,
              isCurrent: true,
            ),
          ],
        );
      } else {
        savedId = 'tailored-${now.microsecondsSinceEpoch}';
        resumes.insert(
          0,
          Resume(
            id: savedId,
            name: '$targetRole — $targetCompany',
            type: ResumeType.tailored,
            status: ResumeStatus.ready,
            updatedAt: now,
            targetRole: targetRole,
            targetCompany: targetCompany,
            matchScore: matchScore,
            tailoredBullets: tailoredBullets,
            versions: [
              ResumeVersion(
                id: 'ai-${now.microsecondsSinceEpoch}',
                label: 'Gemini tailored from ${source.name}',
                createdAt: now,
                isCurrent: true,
              ),
            ],
          ),
        );
      }
    }
    _commit();
    return savedId;
  }

  void deleteResume(String id) {
    resumes.removeWhere((r) => r.id == id);
    _commit();
  }

  void addApplication({
    required String jobTitle,
    required String companyName,
    required ApplicationStatus status,
    required int matchScore,
    String? location,
    bool remote = false,
  }) {
    applications.insert(
      0,
      Application(
        id: 'app-${DateTime.now().microsecondsSinceEpoch}',
        jobTitle: jobTitle,
        companyName: companyName,
        status: status,
        matchScore: matchScore,
        updatedAt: DateTime.now(),
        location: location,
        remote: remote,
      ),
    );
    _commit();
  }

  void updateApplicationStatus(String id, ApplicationStatus status) {
    final index = applications.indexWhere((a) => a.id == id);
    if (index == -1) return;
    applications[index] = applications[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    _commit();
  }

  void deleteApplication(String id) {
    applications.removeWhere((a) => a.id == id);
    _commit();
  }

  // ---- Courses / learning --------------------------------------------------

  /// The user's enrollment record for [courseId], if any.
  CourseEnrollment? enrollmentFor(String courseId) {
    for (final enrollment in courseEnrollments) {
      if (enrollment.courseId == courseId) return enrollment;
    }
    return null;
  }

  bool isEnrolled(String courseId) => enrollmentFor(courseId) != null;

  /// Progress through [course], 0.0–1.0, based on completed lessons.
  double courseProgress(Course course) {
    if (course.lessons.isEmpty) return 0;
    final enrollment = enrollmentFor(course.id);
    if (enrollment == null) return 0;
    final completed = enrollment.completedLessonIds
        .where((id) => course.lessons.any((l) => l.id == id))
        .length;
    return (completed / course.lessons.length).clamp(0, 1).toDouble();
  }

  bool isCourseComplete(Course course) => courseProgress(course) >= 1.0;

  /// Enrolls the user in [course] if not already enrolled. Returns the
  /// resulting enrollment.
  CourseEnrollment enrollInCourse(Course course) {
    final existing = enrollmentFor(course.id);
    if (existing != null) return existing;
    final enrollment =
        CourseEnrollment(courseId: course.id, enrolledAt: DateTime.now());
    courseEnrollments.add(enrollment);
    _saveCourseProgress(enrollment);
    _commit();
    return enrollment;
  }

  /// Marks [lessonId] complete for [courseId] and remembers it as the last
  /// lesson viewed. Auto-enrolls if needed.
  void markLessonComplete(String courseId, String lessonId) {
    final index = courseEnrollments.indexWhere((e) => e.courseId == courseId);
    if (index == -1) {
      courseEnrollments.add(CourseEnrollment(
        courseId: courseId,
        enrolledAt: DateTime.now(),
        completedLessonIds: [lessonId],
        lastLessonId: lessonId,
      ));
    } else {
      final current = courseEnrollments[index];
      if (!current.completedLessonIds.contains(lessonId)) {
        courseEnrollments[index] = current.copyWith(
          completedLessonIds: [...current.completedLessonIds, lessonId],
          lastLessonId: lessonId,
        );
      } else {
        courseEnrollments[index] = current.copyWith(lastLessonId: lessonId);
      }
    }
    _saveCourseProgress(courseEnrollments
        .firstWhere((enrollment) => enrollment.courseId == courseId));
    _commit();
  }

  /// Every enrolled course, most recently touched first.
  List<Course> get enrolledCourses {
    final byRecency = [...courseEnrollments]
      ..sort((a, b) => b.enrolledAt.compareTo(a.enrolledAt));
    return [
      for (final enrollment in byRecency)
        if (courseById(enrollment.courseId) != null)
          courseById(enrollment.courseId)!,
    ];
  }

  /// Records a final-exam attempt. Pass mark is 60%. On a first pass, issues
  /// a certificate and adds it to the career vault (career profile) so it
  /// flows straight into resumes, matching the "Added to career profile" step.
  void recordTestResult({
    required Course course,
    required int correctCount,
    List<String> incorrectTopics = const [],
    bool issueCertificate = true,
  }) {
    final scorePercent = course.finalTest.isEmpty
        ? 0
        : ((correctCount / course.finalTest.length) * 100).round();
    final passed = scorePercent >= 60;
    unawaited(_cloud
        .recordTestAttempt(
          courseId: course.id,
          score: scorePercent,
          questionCount: course.finalTest.length,
          weakTopics: incorrectTopics,
        )
        .catchError((Object _) {}));
    final index = courseEnrollments.indexWhere((e) => e.courseId == course.id);
    if (index == -1) return;
    var enrollment = courseEnrollments[index];
    final alreadyCertified = enrollment.hasCertificate || !issueCertificate;
    enrollment = enrollment.copyWith(
      testScore: scorePercent,
      testPassed: passed,
      attemptCount: enrollment.attemptCount + 1,
      weakTopics: incorrectTopics.toSet().toList(),
    );

    if (passed && !alreadyCertified) {
      final certificateId = 'RES-'
          '${course.id.substring(0, course.id.length.clamp(0, 3)).toUpperCase()}'
          '-${DateTime.now().millisecondsSinceEpoch % 100000}';
      final issuedAt = DateTime.now();
      enrollment = enrollment.copyWith(
        certificateId: certificateId,
        certificateIssuedAt: issuedAt,
      );
      careerItems.insert(
        0,
        CareerItem(
          id: 'course-cert-${course.id}',
          type: CareerItemType.course,
          title: course.title,
          subtitle: 'Certificate of completion · Score $scorePercent%',
          dateRange: '${issuedAt.day}/${issuedAt.month}/${issuedAt.year}',
          verified: true,
        ),
      );
    }

    courseEnrollments[index] = enrollment;
    _saveCourseProgress(enrollment);
    _commit();
  }

  /// Applies a result already graded and persisted by the trusted backend.
  void recordVerifiedTestResult({
    required Course course,
    required int scorePercent,
    required List<String> incorrectTopics,
    String? certificateId,
    DateTime? certificateIssuedAt,
  }) {
    final index = courseEnrollments.indexWhere((e) => e.courseId == course.id);
    if (index == -1) return;
    var enrollment = courseEnrollments[index];
    final issueCertificate =
        certificateId != null && !enrollment.hasCertificate;
    enrollment = enrollment.copyWith(
      testScore: scorePercent,
      testPassed: scorePercent >= 60,
      attemptCount: enrollment.attemptCount + 1,
      weakTopics: incorrectTopics.toSet().toList(),
      certificateId: issueCertificate ? certificateId : null,
      certificateIssuedAt: issueCertificate ? certificateIssuedAt : null,
    );
    if (issueCertificate) {
      final issuedAt = certificateIssuedAt ?? DateTime.now();
      careerItems.insert(
        0,
        CareerItem(
          id: 'course-cert-${course.id}',
          type: CareerItemType.course,
          title: course.title,
          subtitle: 'Verified certificate · Score $scorePercent%',
          dateRange: '${issuedAt.day}/${issuedAt.month}/${issuedAt.year}',
          verified: true,
        ),
      );
    }
    courseEnrollments[index] = enrollment;
    _saveCourseProgress(enrollment);
    _commit();
  }

  void _saveCourseProgress(CourseEnrollment enrollment) {
    unawaited(_cloud
        .saveEnrollmentProgress(
          courseId: enrollment.courseId,
          progress: enrollment.toJson(),
        )
        .catchError((Object _) {}));
  }

  void addCareerItem(CareerItem item) {
    careerItems.add(item);
    _commit();
  }

  /// Saves a finished AI mock interview into the career vault as evidence,
  /// mirroring the "Added to career profile" step used for course
  /// certificates. [score] and [summary] come from AI analysis of the
  /// transcript and may be null when that analysis failed — the raw
  /// question/answer transcript is still recorded so the user's answers are
  /// never lost.
  CareerItem recordInterviewResult({
    required String targetRole,
    required String interviewType,
    required List<String> questions,
    required List<String> answers,
    int? score,
    String? summary,
  }) {
    final completedAt = DateTime.now();
    final subtitle = score != null
        ? '$interviewType interview · Score $score%'
        : '$interviewType interview · AI scoring unavailable';
    final bullets = <String>[
      if (summary != null && summary.trim().isNotEmpty) summary.trim(),
      for (var i = 0; i < questions.length; i++)
        if (i < answers.length && answers[i].trim().isNotEmpty)
          'Q: ${questions[i]} — A: ${answers[i].trim()}',
    ];
    final item = CareerItem(
      id: 'interview-${completedAt.microsecondsSinceEpoch}',
      type: CareerItemType.interview,
      title: targetRole,
      subtitle: subtitle,
      dateRange: '${completedAt.day}/${completedAt.month}/${completedAt.year}',
      bullets: bullets,
      verified: true,
    );
    addCareerItem(item);
    return item;
  }

  void upsertCareerItem(CareerItem item) {
    final index = careerItems.indexWhere((existing) => existing.id == item.id);
    if (index == -1) {
      careerItems.insert(0, item);
    } else {
      careerItems[index] = item;
    }
    _commit();
  }

  void removeCareerItem(String id) {
    careerItems.removeWhere((item) => item.id == id);
    _commit();
  }
}

/// Inherited accessor so screens rebuild when [AppState] notifies.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope(
      {super.key, required AppState super.notifier, required super.child});

  static AppState of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope not found in widget tree');
    return scope!.notifier!;
  }
}
