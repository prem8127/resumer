import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/influencer.dart';
import '../models/models.dart';
import '../services/cloud_data_service.dart';
import '../services/ai_learning_service.dart';

class CreatorStudioScreen extends StatefulWidget {
  const CreatorStudioScreen({super.key});

  @override
  State<CreatorStudioScreen> createState() => _CreatorStudioScreenState();
}

class _CreatorStudioScreenState extends State<CreatorStudioScreen> {
  final CloudDataService _cloud = CloudDataService();
  String get _uid => Supabase.instance.client.auth.currentUser!.id;
  bool _busy = false;

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _editProfile() async {
    final current = await _cloud.getRecord('influencers', _uid);
    final profile = Influencer.fromMap(
        _uid,
        current ??
            {
              'name': Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'] ?? '',
              'headline': '',
              'bio': '',
            });
    if (!mounted) return;
    final name = TextEditingController(text: profile.name);
    final headline = TextEditingController(text: profile.headline);
    final bio = TextEditingController(text: profile.bio);
    final expertise = TextEditingController(text: profile.expertise.join(', '));
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Creator profile'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name')),
            TextField(
                controller: headline,
                decoration: const InputDecoration(labelText: 'Headline')),
            TextField(
                controller: bio,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Bio')),
            TextField(
                controller: expertise,
                decoration: const InputDecoration(
                    labelText: 'Expertise, comma separated')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context,
                  [name.text, headline.text, bio.text, expertise.text]),
              child: const Text('Save draft')),
        ],
      ),
    );
    if (values == null) return;
    await _run(() => _cloud.saveOwnedRecord(
          collection: 'influencers',
          id: _uid,
          status: profile.status == 'approved' ? 'draft' : profile.status,
          data: profile.copyWithProfile(values),
        ));
  }

  Future<void> _createPost() async {
    final title = TextEditingController();
    final description = TextEditingController();
    PlatformFile? file;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, redraw) => AlertDialog(
                title: const Text('New content'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title')),
                  TextField(
                      controller: description,
                      decoration: const InputDecoration(
                          labelText: 'Description or resource link')),
                  TextButton.icon(
                    onPressed: () async {
                      final result = await FilePicker.pickFile(
                        type: FileType.custom,
                        allowedExtensions: [
                          'mp4',
                          'mov',
                          'pdf',
                          'png',
                          'jpg',
                          'jpeg',
                          'webp',
                          'gif',
                          'zip',
                          'txt',
                        ],
                      );
                      if (result != null) redraw(() => file = result);
                    },
                    icon: const Icon(Icons.upload_file_outlined),
                    label: Text(
                        file?.name ?? 'Attach image, video, PDF or resource'),
                  ),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _run(() async {
                          final id = _newId();
                          String? url;
                          if (file != null) {
                            url = await _cloud.upload(
                              path:
                                  'influencers/$_uid/content/$id/${file!.name}',
                              bytes: await file!.readAsBytes(),
                              contentType: _mime(file!.name),
                            );
                          }
                          await _cloud.saveOwnedRecord(
                              collection: 'content',
                              id: id,
                              data: {
                                'title': title.text.trim(),
                                'description': description.text.trim(),
                                'resourceUrl': url ?? description.text.trim(),
                                'fileName': file?.name,
                                'type': _kind(file?.name),
                                'influencerId': _uid,
                              });
                        });
                      },
                      child: const Text('Save draft')),
                ],
              )),
    );
  }

  Future<void> _uploadProfileImage(String field) async {
    final file = await FilePicker.pickFile(
      type: FileType.image,
    );
    if (file == null) return;
    await _run(() async {
      final url = await _cloud.upload(
        path: 'influencers/$_uid/profile/${_newId()}-${file.name}',
        bytes: await file.readAsBytes(),
        contentType: _mime(file.name),
      );
      await _cloud.saveOwnedRecord(
        collection: 'influencers',
        id: _uid,
        data: {field: url},
      );
    });
  }

  Future<void> _createCourse() async {
    final title = TextEditingController();
    final category = TextEditingController();
    final description = TextEditingController();
    final level = TextEditingController(text: 'Beginner');
    final lessonTitle = TextEditingController();
    final lessonBody = TextEditingController();
    final lessonVideo = TextEditingController();
    final module = TextEditingController(text: 'Module 1');
    final question = TextEditingController();
    final options = TextEditingController();
    final topic = TextEditingController();
    final answer = TextEditingController(text: '1');
    PlatformFile? lessonAsset;
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, redraw) => AlertDialog(
                title: const Text('New course'),
                content: SizedBox(
                    width: 480,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextField(
                          controller: title,
                          decoration:
                              const InputDecoration(labelText: 'Course title')),
                      TextField(
                          controller: category,
                          decoration:
                              const InputDecoration(labelText: 'Category')),
                      TextField(
                          controller: level,
                          decoration:
                              const InputDecoration(labelText: 'Level')),
                      TextField(
                          controller: description,
                          maxLines: 2,
                          decoration:
                              const InputDecoration(labelText: 'Description')),
                      const Divider(),
                      TextField(
                          controller: module,
                          decoration:
                              const InputDecoration(labelText: 'Module')),
                      TextField(
                          controller: lessonTitle,
                          decoration: const InputDecoration(
                              labelText: 'First lesson title')),
                      TextField(
                          controller: lessonBody,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Lesson content')),
                      TextField(
                          controller: lessonVideo,
                          decoration: const InputDecoration(
                              labelText: 'Lesson video URL (optional)')),
                      TextButton.icon(
                        onPressed: () async {
                          final result = await FilePicker.pickFile(
                            type: FileType.custom,
                            allowedExtensions: [
                              'mp4',
                              'mov',
                              'pdf',
                              'png',
                              'jpg',
                              'jpeg',
                              'zip'
                            ],
                          );
                          if (result != null)
                            redraw(() => lessonAsset = result);
                        },
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(lessonAsset?.name ??
                            'Upload lesson media or resource'),
                      ),
                      const Divider(),
                      TextField(
                          controller: question,
                          decoration: const InputDecoration(
                              labelText: 'Final test question')),
                      TextField(
                          controller: options,
                          decoration: const InputDecoration(
                              labelText: 'Options, separated by |')),
                      TextField(
                          controller: answer,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Correct option number (1 based)')),
                      TextField(
                          controller: topic,
                          decoration: const InputDecoration(
                              labelText: 'Question topic')),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Save draft')),
                ],
              )),
    );
    if (create != true) return;
    final choices = options.text
        .split('|')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final answerIndex = int.tryParse(answer.text.trim()) ?? 1;
    await _run(() async {
      final id = _newId();
      String? assetUrl;
      if (lessonAsset != null) {
        assetUrl = await _cloud.upload(
          path: 'course-assets/$_uid/$id/${lessonAsset!.name}',
          bytes: await lessonAsset!.readAsBytes(),
          contentType: _mime(lessonAsset!.name),
        );
      }
      final course = Course(
        id: id,
        title: title.text.trim(),
        category:
            category.text.trim().isEmpty ? 'General' : category.text.trim(),
        instructor: Supabase.instance.client.auth.currentUser?.userMetadata?['full_name'] ?? 'Creator',
        level: level.text.trim(),
        priceLabel: 'Free',
        rating: 0,
        studentsLabel: 'New course',
        description: description.text.trim(),
        lessons: lessonTitle.text.trim().isEmpty
            ? const []
            : [
                CourseLesson(
                  id: _newId(),
                  title: lessonTitle.text.trim(),
                  durationLabel: 'Lesson',
                  content: lessonBody.text.trim(),
                  videoUrl: _mime(lessonAsset?.name ?? '').startsWith('video/')
                      ? assetUrl
                      : lessonVideo.text.trim().isEmpty
                          ? null
                          : lessonVideo.text.trim(),
                  resources: assetUrl != null &&
                          !_mime(lessonAsset?.name ?? '').startsWith('video/')
                      ? [
                          {
                            'title': lessonAsset!.name,
                            'url': assetUrl,
                          },
                        ]
                      : const [],
                  moduleName: module.text.trim(),
                )
              ],
        finalTest: question.text.trim().isEmpty || choices.length < 2
            ? const []
            : [
                CourseTestQuestion(
                  question: question.text.trim(),
                  options: choices,
                  correctIndex: (answerIndex - 1).clamp(0, choices.length - 1),
                  topic: topic.text.trim().isEmpty
                      ? module.text.trim()
                      : topic.text.trim(),
                ),
              ],
        moduleNames: [module.text.trim()],
        status: 'draft',
        ownerId: _uid,
      );
      await _cloud.saveOwnedRecord(
          collection: 'courses', id: id, data: course.toMap());
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Draft saved.')));
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $error')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mime(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      'heic' => 'image/heic',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'pdf' => 'application/pdf',
      'zip' => 'application/zip',
      'txt' => 'text/plain',
      _ => 'application/octet-stream',
    };
  }

  String _kind(String? name) {
    if (name == null) return 'link';
    final type = _mime(name);
    if (type.startsWith('image/')) return 'image';
    if (type.startsWith('video/')) return 'video';
    if (type == 'application/pdf') return 'pdf';
    return 'resource';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Creator Studio')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Edit creator profile'),
              onTap: _busy ? null : _editProfile),
          ListTile(
              leading: const Icon(Icons.account_circle_outlined),
              title: const Text('Upload profile photo'),
              onTap:
                  _busy ? null : () => _uploadProfileImage('profilePhotoUrl')),
          ListTile(
              leading: const Icon(Icons.panorama_outlined),
              title: const Text('Upload cover photo'),
              onTap: _busy ? null : () => _uploadProfileImage('coverPhotoUrl')),
          ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Create course'),
              onTap: _busy ? null : _createCourse),
          ListTile(
              leading: const Icon(Icons.post_add_outlined),
              title: const Text('Create post or resource'),
              onTap: _busy ? null : _createPost),
          ListTile(
              leading: const Icon(Icons.send_outlined),
              title: const Text('Submit drafts for review'),
              onTap: _busy ? null : _submitDrafts),
          if (_busy) const LinearProgressIndicator(),
          _creatorStats(),
          const Divider(),
          const Text('Your courses',
              style: TextStyle(fontWeight: FontWeight.w700)),
          StreamBuilder<List<Course>>(
            stream: _cloud.watchManagedCourses(_uid),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return const ListTile(
                    title: Text('Courses could not be loaded.'));
              if (!snapshot.hasData) return const LinearProgressIndicator();
              if (snapshot.data!.isEmpty)
                return const ListTile(title: Text('No courses yet.'));
              return Column(children: [
                for (final course in snapshot.data!)
                  ExpansionTile(
                    title: Text(course.title),
                    subtitle: Text(
                        '${course.status} · ${course.lessons.length} lessons · ${course.finalTest.length} test questions'),
                    trailing: Wrap(children: [
                      IconButton(
                        tooltip: 'Add lesson',
                        icon: const Icon(Icons.playlist_add_outlined),
                        onPressed: () => _addLesson(course),
                      ),
                      IconButton(
                        tooltip: 'Add test question',
                        icon: const Icon(Icons.quiz_outlined),
                        onPressed: () => _addQuestion(course),
                      ),
                      IconButton(
                        tooltip: 'Generate AI final test',
                        icon: const Icon(Icons.auto_awesome_outlined),
                        onPressed: () => _generateCourseTest(course),
                      ),
                      IconButton(
                          tooltip: 'Submit course for review',
                          icon: const Icon(Icons.send_outlined),
                          onPressed: () => _run(() => _cloud.submitForReview(
                              collection: 'courses', id: course.id))),
                    ]),
                    children: [
                      for (final lesson in course.lessons)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.play_lesson_outlined),
                          title: Text(lesson.title),
                          subtitle: Text(lesson.moduleName),
                          trailing: IconButton(
                            tooltip: 'Remove lesson',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeLesson(course, lesson.id),
                          ),
                        ),
                      for (var index = 0;
                          index < course.finalTest.length;
                          index++)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.quiz_outlined),
                          title: Text(course.finalTest[index].question),
                          subtitle: Text(course.finalTest[index].topic),
                          trailing: IconButton(
                            tooltip: 'Remove question',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeQuestion(course, index),
                          ),
                        ),
                    ],
                  )
              ]);
            },
          ),
        ]),
      );

  Widget _creatorStats() => Row(
        children: [
          Expanded(
              child: _countTile(
                  'Courses',
                  _cloud.countOwnedRecords('courses', _uid))),
          Expanded(
              child: _countTile(
                  'Posts',
                  _cloud.countOwnedRecords('content', _uid))),
        ],
      );

  Widget _countTile(String label, Future<int> count) =>
      FutureBuilder<int>(
        future: count,
        builder: (context, snapshot) => ListTile(
          title: Text('${snapshot.data ?? '—'}'),
          subtitle: Text(label),
        ),
      );

  Future<void> _submitDrafts() async {
    await _run(() async {
      final posts = await _cloud.getRecords('content');
      for (final post in posts.where((row) => row['ownerId'] == _uid && row['status'] == 'draft')) {
        await _cloud.submitForReview(collection: 'content', id: post['id'] as String);
      }
      final profile = await _cloud.getRecord('influencers', _uid);
      if (profile != null && profile['status'] == 'draft') {
        await _cloud.submitForReview(collection: 'influencers', id: _uid);
      }
      final courses = await _cloud.getRecords('courses');
      for (final course in courses.where((row) => row['ownerId'] == _uid && row['status'] == 'draft')) {
        await _cloud.submitForReview(collection: 'courses', id: course['id'] as String);
      }
    });
  }

  Future<void> _generateCourseTest(Course course) async {
    final topic = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate final test'),
        content: TextField(
            controller: topic,
            decoration: const InputDecoration(labelText: 'Topics to cover')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, topic.text.trim()),
              child: const Text('Generate')),
        ],
      ),
    );
    if (value == null || value.isEmpty) return;
    await _run(() async {
      final questions = await AiLearningService().generateQuestions(
        courseTitle: course.title,
        topic: value,
        context: course.lessons
            .map((lesson) =>
                '${lesson.title}\n${lesson.content}\n${lesson.keyPoints.join('\n')}')
            .join('\n\n'),
        count: 10,
        finalTest: true,
      );
      final updated =
          course.copyWith(finalTest: [...course.finalTest, ...questions]);
      await _cloud.saveOwnedRecord(
          collection: 'courses', id: course.id, data: updated.toMap());
    });
  }

  Future<void> _addLesson(Course course) async {
    final module = TextEditingController(
        text:
            course.moduleNames.isEmpty ? 'Module 1' : course.moduleNames.last);
    final title = TextEditingController();
    final body = TextEditingController();
    PlatformFile? asset;
    final values = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, redraw) => AlertDialog(
          title: const Text('Add lesson'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: module,
                  decoration: const InputDecoration(labelText: 'Module')),
              TextField(
                  controller: title,
                  decoration: const InputDecoration(labelText: 'Lesson title')),
              TextField(
                  controller: body,
                  maxLines: 4,
                  decoration:
                      const InputDecoration(labelText: 'Lesson content')),
              TextButton.icon(
                onPressed: () async {
                  final result = await FilePicker.pickFile(
                    type: FileType.custom,
                    allowedExtensions: [
                      'mp4',
                      'mov',
                      'pdf',
                      'png',
                      'jpg',
                      'jpeg',
                      'zip'
                    ],
                  );
                  if (result != null) redraw(() => asset = result);
                },
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(asset?.name ?? 'Attach video or resource'),
              ),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (values != true || title.text.trim().isEmpty) return;
    await _run(() async {
      String? url;
      if (asset != null) {
        url = await _cloud.upload(
          path: 'course-assets/$_uid/${course.id}/${_newId()}-${asset!.name}',
          bytes: await asset!.readAsBytes(),
          contentType: _mime(asset!.name),
        );
      }
      final moduleName =
          module.text.trim().isEmpty ? 'Module 1' : module.text.trim();
      final isVideo = _mime(asset?.name ?? '').startsWith('video/');
      final lesson = CourseLesson(
        id: _newId(),
        title: title.text.trim(),
        durationLabel: 'Lesson',
        content: body.text.trim(),
        videoUrl: isVideo ? url : null,
        resources: url != null && !isVideo
            ? [
                {'title': asset!.name, 'url': url}
              ]
            : const [],
        moduleName: moduleName,
        keyPoints: const [],
      );
      await _cloud.saveOwnedRecord(
        collection: 'courses',
        id: course.id,
        data: course.copyWith(
          lessons: [...course.lessons, lesson],
          moduleNames: {...course.moduleNames, moduleName}.toList(),
        ).toMap(),
      );
    });
  }

  Future<void> _addQuestion(Course course) async {
    final question = TextEditingController();
    final options = TextEditingController();
    final answer = TextEditingController(text: '1');
    final topic = TextEditingController();
    final save = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add test question'),
        content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: question,
              decoration: const InputDecoration(labelText: 'Question')),
          TextField(
              controller: options,
              decoration:
                  const InputDecoration(labelText: 'Options, separated by |')),
          TextField(
              controller: answer,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Correct option number (1 based)')),
          TextField(
              controller: topic,
              decoration: const InputDecoration(labelText: 'Topic')),
        ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );
    final choices = options.text
        .split('|')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    if (save != true) return;
    if (question.text.trim().isEmpty || choices.length < 2) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Add a question and at least two options.')));
      return;
    }
    final answerIndex = int.tryParse(answer.text.trim()) ?? 1;
    await _run(() async {
      final item = CourseTestQuestion(
        question: question.text.trim(),
        options: choices,
        correctIndex: (answerIndex - 1).clamp(0, choices.length - 1),
        topic: topic.text.trim().isEmpty ? course.category : topic.text.trim(),
      );
      await _cloud.saveOwnedRecord(
        collection: 'courses',
        id: course.id,
        data: course.copyWith(finalTest: [...course.finalTest, item]).toMap(),
      );
    });
  }

  Future<void> _removeLesson(Course course, String lessonId) => _run(() async {
        await _cloud.saveOwnedRecord(
          collection: 'courses',
          id: course.id,
          data: course
              .copyWith(
                lessons: course.lessons
                    .where((lesson) => lesson.id != lessonId)
                    .toList(),
              )
              .toMap(),
        );
      });

  Future<void> _removeQuestion(Course course, int index) => _run(() async {
        final questions = [...course.finalTest]..removeAt(index);
        await _cloud.saveOwnedRecord(
          collection: 'courses',
          id: course.id,
          data: course.copyWith(finalTest: questions).toMap(),
        );
      });
}

extension on Influencer {
  Map<String, dynamic> copyWithProfile(List<String> values) => {
        ...toMap(),
        'name': values[0].trim(),
        'headline': values[1].trim(),
        'bio': values[2].trim(),
        'expertise': values[3]
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
      };
}
