import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/course_catalog.dart';
import '../data/influencer_catalog.dart';
import '../models/influencer.dart';
import '../models/models.dart';
import 'auth_service.dart';

enum AppRole { user, influencer, admin, superAdmin }

enum ContentStatus { draft, pendingReview, approved, rejected }

/// Supabase-backed repository for user data, learning content, and media.
class CloudDataService {
  CloudDataService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _db => _client ?? Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;
  String? get currentUid => _uid;
  bool get isAvailable => AuthService.instance.isInitialized && _uid != null;

  Future<AppRole> currentRole() async {
    final uid = _uid;
    if (uid == null) return AppRole.user;
    final row = await _db.from('profiles').select('role').eq('id', uid).maybeSingle();
    return AppRole.values.firstWhere(
      (role) => role.name == row?['role'],
      orElse: () => AppRole.user,
    );
  }

  Future<Map<String, dynamic>?> readUserState(String uid) async {
    final row = await _db.from('user_state').select('state').eq('user_id', uid).maybeSingle();
    if (row == null) return null;
    final state = Map<String, dynamic>.from(row['state'] as Map);
    for (final table in const ['career_items', 'resumes', 'applications']) {
      final rows = await _db.from(table).select('id,data').eq('user_id', uid);
      state[_camel(table)] = [
        for (final item in rows) {...Map<String, dynamic>.from(item['data'] as Map), 'id': item['id']},
      ];
    }
    final enrollments = await _db.from('enrollments').select('course_id,progress').eq('user_id', uid);
    state['courseEnrollments'] = [
      for (final item in enrollments)
        {...Map<String, dynamic>.from(item['progress'] as Map), 'cid': item['course_id']},
    ];
    return state;
  }

  Future<void> writeUserState(String uid, Map<String, dynamic> value) async {
    final state = Map<String, dynamic>.from(value)
      ..remove('careerItems')
      ..remove('resumes')
      ..remove('applications')
      ..remove('courseEnrollments');
    await _db.from('user_state').upsert({'user_id': uid, 'state': state});
    final profile = value['user'];
    if (profile is Map<String, dynamic>) {
      await _db.from('profiles').update({
        'name': profile['n'] ?? '',
        'email': profile['e'] ?? '',
        'headline': profile['h'] ?? '',
      }).eq('id', uid);
    }
    for (final pair in const [
      ('careerItems', 'career_items'),
      ('resumes', 'resumes'),
      ('applications', 'applications'),
    ]) {
      await _replaceUserRecords(uid, pair.$2, value[pair.$1] as List? ?? const []);
    }
    for (final enrollment in (value['courseEnrollments'] as List? ?? const [])) {
      if (enrollment is! Map<String, dynamic>) continue;
      final id = enrollment['cid'];
      if (id is! String || id.isEmpty) continue;
      await _db.from('enrollments').upsert({
        'user_id': uid,
        'course_id': id,
        'progress': enrollment,
      });
    }
  }

  Future<void> _replaceUserRecords(String uid, String table, List records) async {
    final existing = await _db.from(table).select('id').eq('user_id', uid);
    final wanted = <String>{};
    for (final record in records.whereType<Map<String, dynamic>>()) {
      final id = record['id'] ?? record['cid'];
      if (id is! String || id.isEmpty) continue;
      wanted.add(id);
      final data = Map<String, dynamic>.from(record)..remove('id');
      await _db.from(table).upsert({'user_id': uid, 'id': id, 'data': data});
    }
    for (final row in existing) {
      if (!wanted.contains(row['id'])) {
        await _db.from(table).delete().eq('user_id', uid).eq('id', row['id']);
      }
    }
  }

  static String _camel(String value) {
    if (value == 'career_items') return 'careerItems';
    return value;
  }

  Stream<List<Influencer>> watchApprovedInfluencers() => !AuthService.instance.isInitialized
      ? Stream.error(StateError('Supabase is not initialized.'))
      : _db
      .from('influencers')
      .stream(primaryKey: ['id'])
      .eq('status', 'approved')
      .map((rows) => rows.map((row) => Influencer.fromMap(row['id'].toString(), _recordData(row))).toList());

  Stream<List<InfluencerContent>> watchApprovedContentByOwner(String ownerId) =>
      !AuthService.instance.isInitialized
          ? Stream.error(StateError('Supabase is not initialized.'))
          : _db.from('content').stream(primaryKey: ['id']).eq('owner_id', ownerId).eq('status', 'approved').map(
            (rows) => rows.map((row) {
              final data = _recordData(row);
              return InfluencerContent(
                title: data['title'] as String? ?? '',
                platform: data['type'] as String? ?? 'Content',
                durationLabel: 'Published',
                url: data['resourceUrl'] as String?,
              );
            }).toList(),
          );

  Stream<List<Course>> watchApprovedCourses() => !AuthService.instance.isInitialized
      ? Stream.error(StateError('Supabase is not initialized.'))
      : _db
      .from('courses')
      .stream(primaryKey: ['id'])
      .eq('status', 'approved')
      .asyncMap((rows) async => Future.wait(rows.map((row) async {
            final data = _recordData(row);
            final test = await _db.from('course_tests').select('questions').eq('course_id', row['id']).eq('is_final', true).maybeSingle();
            if (test?['questions'] is List) data['finalTest'] = test!['questions'];
            return Course.fromMap(row['id'].toString(), data);
          })));

  Stream<List<Course>> watchCoursesByOwner(String ownerId) => !AuthService.instance.isInitialized
      ? Stream.error(StateError('Supabase is not initialized.'))
      : _db
      .from('courses')
      .stream(primaryKey: ['id'])
      .eq('owner_id', ownerId)
      .asyncMap((rows) async => Future.wait(rows.map((row) async {
            final data = _recordData(row);
            final test = await _db.from('test_answer_keys').select('answers').eq('course_id', row['id']).eq('test_id', 'final').maybeSingle();
            if (test?['answers'] is List) data['finalTest'] = test!['answers'];
            return Course.fromMap(row['id'].toString(), data);
          })));

  Stream<List<Course>> watchManagedCourses(String ownerId) => watchCoursesByOwner(ownerId);

  Stream<List<Course>> watchPublishedCoursesByOwner(String ownerId) => !AuthService.instance.isInitialized
      ? Stream.error(StateError('Supabase is not initialized.'))
      : _db
      .from('courses')
      .stream(primaryKey: ['id'])
      .eq('owner_id', ownerId)
      .eq('status', 'approved')
      .map((rows) => rows.map((row) => Course.fromMap(row['id'].toString(), _recordData(row))).toList());

  Future<int> countCoursesByOwner(String ownerId) async {
    if (!AuthService.instance.isInitialized) return 0;
    final result = await _db.from('courses').select('id').eq('owner_id', ownerId).eq('status', 'approved').count(CountOption.exact);
    return result.count;
  }

  Stream<List<Map<String, dynamic>>> watchRecords(String collection, {String? status, int limit = 100}) {
    if (!AuthService.instance.isInitialized) return Stream.error(StateError('Supabase is not initialized.'));
    return _db.from(_table(collection)).stream(primaryKey: ['id']).limit(limit).map(
          (rows) => rows
              .where((row) => status == null || row['status'] == status)
              .map(_recordData)
              .toList(),
        );
  }

  Future<List<Map<String, dynamic>>> getRecords(String collection) async {
    final rows = await _db.from(_table(collection)).select().limit(1000);
    return rows.map(_recordData).toList();
  }

  Future<Map<String, dynamic>?> getRecord(String collection, String id) async {
    final table = _table(collection);
    final key = table == 'profiles' ? 'id' : 'id';
    final row = await _db.from(table).select().eq(key, id).maybeSingle();
    if (row == null) return null;
    final data = _recordData(row);
    if (table == 'courses') {
      final test = await _db.from('test_answer_keys').select('answers').eq('course_id', id).eq('test_id', 'final').maybeSingle();
      if (test?['answers'] is List) data['finalTest'] = test!['answers'];
    }
    return data;
  }

  Future<int> countRecords(String collection) async {
    final result = await _db.from(_table(collection)).select('id').count(CountOption.exact);
    return result.count;
  }

  Future<int> countOwnedRecords(String collection, String ownerId) async {
    final result = await _db.from(_table(collection)).select('id').eq('owner_id', ownerId).count(CountOption.exact);
    return result.count;
  }

  Future<void> updateRecord(String collection, String id, Map<String, dynamic> changes) async {
    final table = _table(collection);
    if (table == 'profiles') {
      await _db.from(table).update(changes).eq('id', id);
      return;
    }
    if (table == 'influencers') {
      final current = await getRecord(collection, id);
      if (current == null) throw StateError('Record not found.');
      current.addAll(changes);
      await saveOwnedRecord(collection: collection, id: id, data: current, status: current['status'] as String? ?? 'draft');
      return;
    }
    final row = await _db.from(table).select('data').eq('id', id).single();
    final data = Map<String, dynamic>.from(row['data'] as Map)..addAll(changes);
    await _db.from(table).update({'data': data}).eq('id', id);
  }

  Future<void> deleteRecord(String collection, String id) async {
    await _db.from(_table(collection)).delete().eq('id', id);
  }

  Future<void> saveOwnedRecord({
    required String collection,
    required String id,
    required Map<String, dynamic> data,
    String status = 'draft',
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to save learning content.');
    final table = _table(collection);
    final existing = await _db.from(table).select('id,owner_id').eq('id', id).maybeSingle();
    final ownerId = existing?['owner_id'] as String?;
    if (ownerId != null && ownerId != uid && !await _isAdmin()) {
      throw StateError('You do not own this record.');
    }
    final record = Map<String, dynamic>.from(data)
      ..remove('ownerId')
      ..remove('status')
      ..remove('verified');
    final finalTest = table == 'courses' ? record.remove('finalTest') as List? : null;
    final row = <String, dynamic>{'data': record, 'status': status};
    if (table == 'courses' || table == 'content' || table == 'influencers') {
      row['owner_id'] = ownerId ?? uid;
    }
    if (existing == null) {
      row['id'] = table == 'influencers' ? id : id;
      await _db.from(table).insert(row);
    } else {
      await _db.from(table).update(row).eq('id', id);
    }
    if (finalTest != null) {
      await _saveFinalTest(id, finalTest);
    }
  }

  Future<void> _saveFinalTest(String courseId, List questions) async {
    final answers = questions.whereType<Map<String, dynamic>>().toList();
    await _db.from('course_tests').upsert({
      'course_id': courseId,
      'id': 'final',
      'is_final': true,
      'questions': [
        for (final question in answers)
          Map<String, dynamic>.from(question)..remove('correctIndex'),
      ],
    });
    await _db.from('test_answer_keys').upsert({
      'course_id': courseId,
      'test_id': 'final',
      'answers': answers,
    });
  }

  Future<void> submitForReview({required String collection, required String id}) async {
    await _db.from(_table(collection)).update({'status': 'pendingReview'}).eq('id', id);
  }

  Future<void> moderateContent({required String collection, required String id, required bool approved}) async {
    if (!await _isAdmin()) throw StateError('Admin access is required to review content.');
    final table = _table(collection);
    await _db.from(table).update({'status': approved ? 'approved' : 'rejected'}).eq('id', id);
    if (table == 'influencers' && approved) await _db.from(table).update({'verified': true}).eq('id', id);
  }

  Future<void> setVerified(String id, bool verified) async {
    if (!await _isAdmin()) throw StateError('Admin access is required.');
    await _db.from('influencers').update({'verified': verified}).eq('id', id);
  }

  Future<void> setUserRole(String id, AppRole role) async {
    await _db.rpc('admin_set_user_role', params: {'target_id': id, 'target_role': role.name});
  }

  Future<bool> _isAdmin() async {
    final role = await currentRole();
    return role == AppRole.admin || role == AppRole.superAdmin;
  }

  Future<({int courses, int influencers})> importStarterCatalog() async {
    if (!await _isAdmin()) throw StateError('Admin access is required to import the catalog.');
    final uid = _uid!;
    var courseCount = 0;
    var influencerCount = 0;
    for (final course in kCourseCatalog) {
      if (await getRecord('courses', course.id) != null) continue;
      final courseData = course.toMap();
      final finalTest = courseData.remove('finalTest') as List? ?? const [];
      final data = courseData..remove('ownerId')..remove('status');
      await _db.from('courses').insert({'id': course.id, 'owner_id': uid, 'data': data, 'status': 'approved'});
      if (finalTest.isNotEmpty) await _saveFinalTest(course.id, finalTest);
      courseCount++;
    }
    for (final influencer in kInfluencerCatalog) {
      if (await getRecord('influencers', influencer.id) != null) continue;
      await _db.from('influencers').insert({'id': influencer.id, 'owner_id': uid, 'data': influencer.toMap(), 'status': 'approved'});
      influencerCount++;
    }
    return (courses: courseCount, influencers: influencerCount);
  }

  Future<int> secureExistingCourseTests() async => 0;

  Future<void> saveEnrollmentProgress({required String courseId, required Map<String, dynamic> progress}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to save course progress.');
    const keys = {'cid', 'e', 'done', 'll'};
    final clean = Map<String, dynamic>.fromEntries(progress.entries.where((entry) => keys.contains(entry.key)));
    await _db.from('enrollments').upsert({'user_id': uid, 'course_id': courseId, 'progress': clean});
  }

  Future<void> recordTestAttempt({required String courseId, required int score, required int questionCount, required List<String> weakTopics}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to save test attempts.');
    await _db.from('test_attempts').insert({
      'user_id': uid,
      'course_id': courseId,
      'score': score.clamp(0, 100),
      'question_count': questionCount,
      'weak_topics': weakTopics.take(20).toList(),
    });
  }

  Future<String> upload({required String path, required Uint8List bytes, required String contentType}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in before uploading files.');
    final isPublic = path.startsWith('influencers/$uid/') || path.startsWith('course-assets/$uid/');
    if (!isPublic && !path.startsWith('users/$uid/')) throw StateError('Uploads must be scoped to the signed-in user.');
    final bucket = isPublic ? 'public-assets' : 'private-user-files';
    final storagePath = '$uid/${path.split('/').skip(2).join('/')}';
    await _db.storage.from(bucket).uploadBinary(storagePath, bytes, fileOptions: FileOptions(contentType: contentType, upsert: true));
    return isPublic
        ? _db.storage.from(bucket).getPublicUrl(storagePath)
        : await _db.storage.from(bucket).createSignedUrl(storagePath, 86400);
  }

  static String _table(String name) => switch (name) {
        'users' => 'profiles',
        'influencers' => 'influencers',
        'courses' => 'courses',
        'content' => 'content',
        'careerItems' || 'career_items' => 'career_items',
        'resumes' => 'resumes',
        'applications' => 'applications',
        _ => throw ArgumentError.value(name, 'collection', 'Unsupported table'),
      };

  static Map<String, dynamic> _recordData(Map<String, dynamic> row) {
    final data = row['data'] is Map ? Map<String, dynamic>.from(row['data'] as Map) : Map<String, dynamic>.from(row);
    if (row.containsKey('id')) data['id'] = row['id'];
    if (row.containsKey('owner_id')) data['ownerId'] = row['owner_id'];
    if (row.containsKey('status')) data['status'] = row['status'];
    if (row.containsKey('verified')) data['verified'] = row['verified'];
    return data;
  }
}
