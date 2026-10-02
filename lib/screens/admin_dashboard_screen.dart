import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../services/cloud_data_service.dart';
import '../services/auth_service.dart';
import '../services/ai_learning_service.dart';
import '../models/models.dart';
import 'creator_studio_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final CloudDataService _cloud = CloudDataService();
  late Future<AppRole> _role;
  int _tab = 0;
  static const _collections = ['users', 'influencers', 'courses', 'content'];

  @override
  void initState() {
    super.initState();
    _role = _cloud.currentRole();
  }

  void _refreshRole() => setState(() => _role = _cloud.currentRole());

  @override
  Widget build(BuildContext context) => FutureBuilder<AppRole>(
        future: _role,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(title: const Text('Admin access')),
              body: _accessMessage(
                title: 'Could not verify your account role',
                detail:
                    'The app could not read your Supabase profile. Confirm the database migration completed, then refresh.',
                actionLabel: 'Retry',
                onAction: _refreshRole,
              ),
            );
          }
          if (snapshot.data != AppRole.admin &&
              snapshot.data != AppRole.superAdmin) {
            return Scaffold(
              appBar: AppBar(title: const Text('Admin access')),
              body: _accessMessage(
                title: 'Admin access is not enabled for this account',
                detail:
                    'Signed in as ${AuthService.instance.currentUser?.email ?? 'your Google account'} with role ${snapshot.data?.name ?? 'unknown'}. Changing the email address does not grant admin access. A project owner must set this account’s public.profiles role to admin or superAdmin in Supabase.',
                actionLabel: 'Check again',
                onAction: _refreshRole,
              ),
            );
          }
          return DefaultTabController(
            length: 4,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Admin Dashboard'),
                actions: [
                  IconButton(
                    tooltip: 'Log out',
                    onPressed: () async {
                      final navigator = Navigator.of(context);
                      await AppScope.of(context).logout();
                      if (navigator.mounted) {
                        navigator.popUntil((route) => route.isFirst);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                  ),
                ],
                bottom: TabBar(
                  onTap: (index) => setState(() => _tab = index),
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Users'),
                    Tab(text: 'Review'),
                    Tab(text: 'Manage'),
                  ],
                ),
              ),
              body: _tab == 0
                  ? _overview()
                  : _tab == 1
                      ? _users()
                      : _tab == 2
                          ? _review()
                          : _manage(),
            ),
          );
        },
      );

  Widget _accessMessage({
    required String title,
    required String detail,
    required String actionLabel,
    required VoidCallback onAction,
  }) =>
      Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 42),
                const SizedBox(height: 16),
                Text(title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text(detail, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionLabel),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _overview() => ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Platform activity',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonalIcon(
              onPressed: _importCatalog,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Import starter learning catalog'),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _secureCourseTests,
              icon: const Icon(Icons.lock_outline_rounded),
              label: const Text('Secure existing final tests'),
            ),
          ),
          const SizedBox(height: 8),
          for (final collection in _collections)
            FutureBuilder<int>(
              future: _cloud.countRecords(collection),
              builder: (context, snapshot) => ListTile(
                title: Text(_label(collection)),
                trailing: Text('${snapshot.data ?? '—'}'),
              ),
            ),
        ],
      );

  Future<void> _importCatalog() async {
    try {
      final result = await _cloud.importStarterCatalog();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Imported ${result.courses} courses and ${result.influencers} mentors. Existing records were kept.',
        ),
      ));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Catalog import failed: $error')),
      );
    }
  }

  Future<void> _secureCourseTests() async {
    try {
      final migrated = await _cloud.secureExistingCourseTests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Updated course security for $migrated courses.'),
      ));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not secure course tests: $error')),
      );
    }
  }

  Widget _users() => StreamBuilder<List<Map<String, dynamic>>>(
        stream: _cloud.watchRecords('users'),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _message('Could not load users.');
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return _message('No user profiles yet.');
          }
          return ListView.builder(
            itemCount: snapshot.data!.length,
            itemBuilder: (context, index) {
              final data = snapshot.data![index];
              final id = data['id'] as String;
              return ListTile(
                title: Text((data['name'] as String?) ?? id),
                subtitle: Text((data['email'] as String?) ?? id),
                trailing: PopupMenuButton<AppRole>(
                  tooltip: 'Change role',
                  onSelected: (role) => _cloud.setUserRole(id, role),
                  itemBuilder: (context) => [
                    for (final role in AppRole.values)
                      PopupMenuItem(value: role, child: Text(role.name)),
                  ],
                  child: Text((data['role'] as String?) ?? 'user'),
                ),
              );
            },
          );
        },
      );

  Widget _review() => ListView(
        children: [
          for (final collection in const ['influencers', 'courses', 'content'])
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _cloud.watchRecords(collection, status: 'pendingReview'),
              builder: (context, snapshot) {
                if (snapshot.hasError || !snapshot.hasData) {
                  return const SizedBox.shrink();
                }
                return ExpansionTile(
                  title: Text(_label(collection)),
                  children: [
                    for (final data in snapshot.data!)
                      ListTile(
                        title: Text((data['title'] as String?) ??
                            (data['name'] as String?) ??
                            (data['id'] as String)),
                        subtitle: Text(data['id'] as String),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Reject',
                              onPressed: () => _moderate(
                                  collection, data['id'] as String, false),
                              icon: const Icon(Icons.close),
                            ),
                            IconButton(
                              tooltip: 'Approve',
                              onPressed: () => _moderate(
                                  collection, data['id'] as String, true),
                              icon: const Icon(Icons.check),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      );

  Widget _manage() => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Wrap(spacing: 8, children: [
              FilledButton.tonalIcon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CreatorStudioScreen(),
                  ),
                ),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Courses, modules, lessons & uploads'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _editInfluencer(),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Add mentor'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _createRecord('courses'),
                icon: const Icon(Icons.add),
                label: const Text('Add course'),
              ),
            ]),
          ),
          for (final collection in const ['influencers', 'courses'])
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _cloud.watchRecords(collection),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                return ExpansionTile(
                  title: Text(_label(collection)),
                  children: [
                    for (final data in snapshot.data!)
                      ListTile(
                        leading: collection == 'influencers' &&
                                (data['profilePhotoUrl'] as String?)
                                        ?.isNotEmpty ==
                                    true
                            ? CircleAvatar(
                                backgroundImage: NetworkImage(
                                    data['profilePhotoUrl'] as String),
                              )
                            : collection == 'influencers'
                                ? const CircleAvatar(
                                    child: Icon(Icons.person_outline))
                                : null,
                        title: Text((data['title'] as String?) ??
                            (data['name'] as String?) ??
                            (data['id'] as String)),
                        subtitle: Text(collection == 'influencers'
                            ? '${data['headline'] ?? ''} · ${data['status'] ?? 'draft'}'
                            : (data['status'] as String?) ?? 'draft'),
                        trailing: Wrap(spacing: 0, children: [
                          if (collection == 'courses')
                            IconButton(
                              tooltip: 'Generate AI final test',
                              icon: const Icon(Icons.auto_awesome_outlined),
                              onPressed: () =>
                                  _generateTest(data['id'] as String, data),
                            ),
                          IconButton(
                            tooltip: 'Edit',
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _editRecord(
                                collection, data['id'] as String, data),
                          ),
                          if (collection == 'influencers')
                            if (data['status'] != 'approved')
                              IconButton(
                                tooltip: 'Publish mentor',
                                icon: const Icon(Icons.publish_outlined),
                                onPressed: () => _moderate(
                                  'influencers',
                                  data['id'] as String,
                                  true,
                                ),
                              ),
                          if (collection == 'influencers')
                            IconButton(
                              tooltip: (data['verified'] as bool? ?? false)
                                  ? 'Unverify mentor'
                                  : 'Verify mentor',
                              icon: Icon((data['verified'] as bool? ?? false)
                                  ? Icons.verified
                                  : Icons.verified_outlined),
                              onPressed: () => _setVerified(
                                data['id'] as String,
                                !(data['verified'] as bool? ?? false),
                              ),
                            ),
                          IconButton(
                            tooltip: 'Delete',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                _deleteRecord(collection, data['id'] as String),
                          ),
                        ]),
                      ),
                  ],
                );
              },
            ),
        ],
      );

  Future<void> _createRecord(String collection) async {
    final name = TextEditingController();
    final headline = TextEditingController();
    final description = TextEditingController();
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
            collection == 'courses' ? 'Create course' : 'Create mentor'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              decoration: InputDecoration(
                  labelText:
                      collection == 'courses' ? 'Course title' : 'Name')),
          TextField(
              controller: headline,
              decoration: InputDecoration(
                  labelText:
                      collection == 'courses' ? 'Category' : 'Headline')),
          TextField(
              controller: description,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Description or bio')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, [
                    name.text.trim(),
                    headline.text.trim(),
                    description.text.trim()
                  ]),
              child: const Text('Create draft')),
        ],
      ),
    );
    if (values == null || values.first.isEmpty) return;
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final ownerId = _cloud.currentUid;
    if (ownerId == null) return;
    final data = collection == 'courses'
        ? {
            'title': values[0],
            'category': values[1],
            'description': values[2],
            'instructor': '',
            'level': 'Beginner',
            'priceLabel': 'Free',
            'rating': 0,
            'studentsLabel': 'New course',
            'lessons': <Object>[],
            'finalTest': <Object>[],
            'moduleNames': <String>[],
            'ownerId': ownerId,
          }
        : {
            'name': values[0],
            'headline': values[1],
            'bio': values[2],
            'expertise': <String>[],
            'socialLinks': <Object>[],
            'content': <Object>[],
            'courseIds': <String>[],
            'ownerId': ownerId,
          };
    try {
      await _cloud.saveOwnedRecord(collection: collection, id: id, data: data);
    } on Object {
      if (mounted) _message('Could not create draft.');
    }
  }

  Future<void> _editInfluencer(
      {String? id, Map<String, dynamic>? initial}) async {
    final data = Map<String, dynamic>.from(initial ?? const {});
    final name = TextEditingController(text: data['name'] as String? ?? '');
    final headline =
        TextEditingController(text: data['headline'] as String? ?? '');
    final bio = TextEditingController(text: data['bio'] as String? ?? '');
    final expertise = TextEditingController(
      text: (data['expertise'] as List? ?? const []).join(', '),
    );
    final links = TextEditingController(
      text: [
        for (final item in data['socialLinks'] as List? ?? const [])
          if (item is Map)
            '${item['platform'] ?? ''} | ${item['handle'] ?? ''} | ${item['url'] ?? ''}',
      ].join('\n'),
    );
    PlatformFile? profileImage;
    PlatformFile? coverImage;
    // Admin-created profiles are public by default; editors can still return
    // an existing profile to draft or submit it for review.
    var selectedStatus = data['status'] as String? ?? 'approved';
    final status = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, redraw) => AlertDialog(
          title: Text(id == null ? 'Add mentor' : 'Edit mentor'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'Name')),
                  TextField(
                      controller: headline,
                      decoration:
                          const InputDecoration(labelText: 'Headline / role')),
                  TextField(
                      controller: bio,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(labelText: 'Full bio')),
                  TextField(
                      controller: expertise,
                      decoration: const InputDecoration(
                          labelText: 'Expertise, comma separated')),
                  TextField(
                    controller: links,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Social links',
                      hintText:
                          'Platform | handle | https://link (one per line)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _mediaPicker(
                    label: 'Profile photo',
                    selectedName: profileImage?.name,
                    currentUrl: data['profilePhotoUrl'] as String?,
                    onPick: () async {
                      final result =
                          await FilePicker.pickFile(type: FileType.image);
                      if (result != null) redraw(() => profileImage = result);
                    },
                  ),
                  _mediaPicker(
                    label: 'Cover photo',
                    selectedName: coverImage?.name,
                    currentUrl: data['coverPhotoUrl'] as String?,
                    onPick: () async {
                      final result =
                          await FilePicker.pickFile(type: FileType.image);
                      if (result != null) redraw(() => coverImage = result);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration:
                        const InputDecoration(labelText: 'Publication status'),
                    items: const [
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                      DropdownMenuItem(
                          value: 'pendingReview',
                          child: Text('Pending review')),
                      DropdownMenuItem(
                          value: 'approved', child: Text('Published')),
                      DropdownMenuItem(
                          value: 'rejected', child: Text('Rejected')),
                    ],
                    onChanged: (value) =>
                        redraw(() => selectedStatus = value ?? 'draft'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selectedStatus),
                child: const Text('Save')),
          ],
        ),
      ),
    );
    if (status == null || name.text.trim().isEmpty) return;
    final ownerId = _cloud.currentUid;
    if (ownerId == null) return;
    final recordId = id ?? DateTime.now().microsecondsSinceEpoch.toString();
    try {
      if (profileImage != null) {
        data['profilePhotoUrl'] = await _cloud.upload(
          path:
              'influencers/$ownerId/admin/$recordId/profile/${profileImage!.name}',
          bytes: await profileImage!.readAsBytes(),
          contentType: _imageMime(profileImage!.name),
        );
      }
      if (coverImage != null) {
        data['coverPhotoUrl'] = await _cloud.upload(
          path:
              'influencers/$ownerId/admin/$recordId/cover/${coverImage!.name}',
          bytes: await coverImage!.readAsBytes(),
          contentType: _imageMime(coverImage!.name),
        );
      }
      data.addAll({
        'name': name.text.trim(),
        'headline': headline.text.trim(),
        'bio': bio.text.trim(),
        'expertise': expertise.text
            .split(',')
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(),
        'socialLinks': [
          for (final line in links.text.split('\n'))
            if (line.trim().isNotEmpty && line.split('|').length >= 3)
              {
                'platform': line.split('|')[0].trim(),
                'handle': line.split('|')[1].trim(),
                'url': line.split('|').skip(2).join('|').trim(),
              },
        ],
        'ownerId': id == null ? ownerId : data['ownerId'] ?? ownerId,
      });
      await _cloud.saveOwnedRecord(
        collection: 'influencers',
        id: recordId,
        data: data,
        status: status,
      );
      if (mounted) _message('Influencer profile saved.');
    } on Object catch (error) {
      if (mounted) _message('Could not save mentor: $error');
    }
  }

  Widget _mediaPicker({
    required String label,
    required String? selectedName,
    required String? currentUrl,
    required VoidCallback onPick,
  }) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(label == 'Profile photo'
            ? Icons.account_circle_outlined
            : Icons.image_outlined),
        title: Text(label),
        subtitle: Text(selectedName ??
            (currentUrl?.isNotEmpty == true
                ? 'Photo uploaded'
                : 'No photo selected')),
        trailing: IconButton(
            tooltip: 'Choose $label',
            onPressed: onPick,
            icon: const Icon(Icons.upload_outlined)),
      );

  String _imageMime(String name) =>
      switch (name.split('.').last.toLowerCase()) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'heic' => 'image/heic',
        _ => 'application/octet-stream',
      };

  Future<void> _setVerified(String id, bool verified) async {
    try {
      await _cloud.setVerified(id, verified);
      if (mounted) {
        _message(verified ? 'Influencer verified.' : 'Influencer unverified.');
      }
    } on Object catch (error) {
      if (mounted) _message('Could not update verification: $error');
    }
  }

  Future<void> _deleteRecord(String collection, String id) async {
    try {
      await _cloud.deleteRecord(collection, id);
    } on Object {
      if (mounted) _message('Could not delete this record.');
    }
  }

  Future<void> _generateTest(String id, Map<String, dynamic> data) async {
    final course = Course.fromMap(id, data);
    final topic = TextEditingController(text: course.category);
    final selectedTopic = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate final test'),
        content: TextField(
          controller: topic,
          decoration: const InputDecoration(labelText: 'Topics to cover'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, topic.text.trim()),
            child: const Text('Generate'),
          ),
        ],
      ),
    );
    if (selectedTopic == null || selectedTopic.isEmpty) return;
    try {
      final questions = await AiLearningService().generateQuestions(
        courseTitle: course.title,
        topic: selectedTopic,
        context: course.lessons
            .map((lesson) => '${lesson.title}\n${lesson.content}')
            .join('\n\n'),
        count: 10,
        finalTest: true,
      );
      final current = await _cloud.getRecord('courses', id);
      if (current == null) throw StateError('Course no longer exists.');
      await _cloud.saveOwnedRecord(
          collection: 'courses',
          id: id,
          data: {
            ...current,
            'finalTest': [
              ...course.finalTest,
              for (final item in questions)
                {
                  'question': item.question,
                  'options': item.options,
                  'correctIndex': item.correctIndex,
                  'topic': item.topic,
                },
            ],
          },
          status: 'draft');
      if (mounted) {
        _message('Added ${questions.length} questions to the draft.');
      }
    } on Object catch (error) {
      if (mounted) _message('Could not generate test questions: $error');
    }
  }

  Future<void> _editRecord(
    String collection,
    String id,
    Map<String, dynamic> data,
  ) async {
    if (collection == 'influencers') {
      await _editInfluencer(id: id, initial: data);
      return;
    }
    final title = TextEditingController(
        text: (data['title'] as String?) ?? (data['name'] as String?) ?? '');
    final subtitle = TextEditingController(
        text: (data['category'] as String?) ??
            (data['headline'] as String?) ??
            '');
    final description = TextEditingController(
        text:
            (data['description'] as String?) ?? (data['bio'] as String?) ?? '');
    final values = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit record'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: title,
              decoration: const InputDecoration(labelText: 'Name or title')),
          TextField(
              controller: subtitle,
              decoration:
                  const InputDecoration(labelText: 'Headline or category')),
          TextField(
              controller: description,
              maxLines: 3,
              decoration:
                  const InputDecoration(labelText: 'Bio or description')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, [
                    title.text.trim(),
                    subtitle.text.trim(),
                    description.text.trim()
                  ]),
              child: const Text('Save')),
        ],
      ),
    );
    if (values == null) return;
    try {
      await _cloud.updateRecord(
          collection,
          id,
          collection == 'courses'
              ? {
                  'title': values[0],
                  'category': values[1],
                  'description': values[2]
                }
              : {'name': values[0], 'headline': values[1], 'bio': values[2]});
    } on Object {
      if (mounted) _message('Could not update this record.');
    }
  }

  Future<void> _moderate(String collection, String id, bool approved) async {
    try {
      await _cloud.moderateContent(
        collection: collection,
        id: id,
        approved: approved,
      );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update this review.')),
        );
      }
    }
  }

  Widget _message(String message) => Center(child: Text(message));

  String _label(String value) => switch (value) {
        'users' => 'Users',
        'influencers' => 'Mentors',
        'courses' => 'Courses',
        _ => 'Content',
      };
}
