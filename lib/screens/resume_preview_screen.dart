import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../services/resume_export_service.dart';
import '../theme/app_theme.dart';

class ResumePreviewScreen extends StatelessWidget {
  const ResumePreviewScreen({super.key, required this.resume});

  final Resume resume;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final currentResume = state.resumes
        .where((candidate) => candidate.id == resume.id)
        .firstOrNull;
    final previewResume = currentResume ?? resume;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resume preview'),
        actions: [
          IconButton(
            tooltip: 'Edit resume',
            onPressed: () => _showResumeEditor(context, state, previewResume),
            icon: const Icon(Icons.edit_outlined, size: 20),
          ),
          IconButton(
            tooltip: 'Export resume',
            onPressed: () => _export(context, previewResume),
            icon: const Icon(Icons.ios_share_rounded, size: 20),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 32),
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.sageSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: AppColors.sage),
                    SizedBox(width: 5),
                    Text(
                      'ATS-SAFE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.sage,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text('A4 · PDF & DOCX ready',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Tap any resume section to edit it.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(26, 30, 26, 34),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.line),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .06),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: DefaultTextStyle(
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 10.5,
                height: 1.45,
              ),
              child: _ResumeDocument(
                state: state,
                resume: previewResume,
                onEditContact: () => _showEditProfile(context, state),
                onEditResume: () =>
                    _showEditResumeDetails(context, state, previewResume),
                onEditCareerItem: (item) =>
                    _showCareerItemEditor(context, state, item.type, item),
                onOpenEditor: () =>
                    _showResumeEditor(context, state, previewResume),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showResumeEditor(context, state, previewResume),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit resume'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _export(context, previewResume),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Export resume'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _export(BuildContext context, Resume currentResume) {
    final state = AppScope.of(context);
    const ResumeExportService exportService = ResumeExportService();
    exportService.promptAndExport(
      context,
      state: state,
      resume: currentResume,
    );
  }

  void _showEditProfile(BuildContext context, AppState state) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _EditContactSheet(state: state),
    );
  }

  void _showEditResumeDetails(
    BuildContext context,
    AppState state,
    Resume currentResume,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditResumeDetailsSheet(
        state: state,
        resume: currentResume,
      ),
    );
  }

  void _showCareerItemEditor(
    BuildContext context,
    AppState state,
    CareerItemType type, [
    CareerItem? item,
  ]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CareerItemEditSheet(
        state: state,
        type: type,
        item: item,
      ),
    );
  }

  Future<void> _showResumeEditor(
    BuildContext context,
    AppState state,
    Resume currentResume,
  ) async {
    final selection = await showModalBottomSheet<_ResumeEditSelection>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ResumeEditorSheet(
        state: state,
        resume: currentResume,
      ),
    );
    if (!context.mounted || selection == null) return;

    switch (selection.target) {
      case _ResumeEditTarget.contact:
        _showEditProfile(context, state);
      case _ResumeEditTarget.resume:
        _showEditResumeDetails(context, state, currentResume);
      case _ResumeEditTarget.careerItem:
        final item = selection.item;
        if (item != null) {
          _showCareerItemEditor(context, state, item.type, item);
        }
      case _ResumeEditTarget.addItem:
        final type = selection.type;
        if (type != null) _showCareerItemEditor(context, state, type);
    }
  }
}

class _ResumeDocument extends StatelessWidget {
  const _ResumeDocument({
    required this.state,
    required this.resume,
    required this.onEditContact,
    required this.onEditResume,
    required this.onEditCareerItem,
    required this.onOpenEditor,
  });

  final AppState state;
  final Resume resume;
  final VoidCallback onEditContact;
  final VoidCallback onEditResume;
  final ValueChanged<CareerItem> onEditCareerItem;
  final VoidCallback onOpenEditor;

  @override
  Widget build(BuildContext context) {
    final user = state.user;
    final experience = state.careerItems
        .where((item) => item.type == CareerItemType.experience)
        .toList();
    final projects = state.careerItems
        .where((item) => item.type == CareerItemType.project)
        .toList();
    final education = state.careerItems
        .where((item) => item.type == CareerItemType.education)
        .toList();
    final skills = state.careerItems
        .where((item) => item.type == CareerItemType.skill)
        .map((item) => item.title.trim())
        .where((title) => title.isNotEmpty)
        .toList();
    final courses = state.careerItems
        .where((item) => item.type == CareerItemType.course)
        .toList();

    final headline = user.headline.trim();
    final displayName =
        user.name.trim().isEmpty ? 'YOUR NAME' : user.name.trim().toUpperCase();
    final contactParts = [user.email, user.phone, user.location]
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final hasTargetRole =
        resume.targetRole != null && resume.targetRole!.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onEditContact,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 5, 8, 8),
            child: Stack(
              children: [
                Column(
                  children: [
                    Center(
                      child: Text(
                        displayName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (headline.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                          color: AppColors.sage,
                        ),
                      ),
                    ],
                    if (contactParts.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        contactParts.join('   |   '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: AppColors.stone,
                        ),
                      ),
                    ],
                  ],
                ),
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.edit_outlined,
                    size: 12,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, thickness: 0.8, color: AppColors.line),

        // Professional Summary
        if (hasTargetRole || headline.isNotEmpty) ...[
          _DocumentSection(
            title: 'PROFESSIONAL SUMMARY',
            onTap: onEditContact,
            child: Text(
              hasTargetRole
                  ? (headline.isNotEmpty
                      ? '$headline with targeted focus toward ${resume.targetRole}${resume.targetCompany == null ? '' : ' at ${resume.targetCompany}'}. Proven background delivering dependable, high-impact results with cross-functional technical rigor.'
                      : 'Targeted for ${resume.targetRole}${resume.targetCompany == null ? '' : ' at ${resume.targetCompany}'}. Proven background delivering dependable, high-impact results with cross-functional technical rigor.')
                  : '$headline with demonstrated expertise in delivering high-quality engineering and product solutions. Committed to technical excellence, continuous learning, and driving scalable impact.',
              style: const TextStyle(fontSize: 9.5, height: 1.45),
            ),
          ),
        ],

        // Targeted Highlights
        if (resume.tailoredBullets.isNotEmpty)
          _DocumentSection(
            title: 'TARGETED HIGHLIGHTS',
            onTap: onEditResume,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final bullet in resume.tailoredBullets)
                  _DocumentBullet(text: bullet),
              ],
            ),
          ),

        // Experience
        if (experience.isNotEmpty)
          _DocumentSection(
            title: 'EXPERIENCE',
            child: Column(children: [
              for (final item in experience)
                _DocumentEntry(
                  item: item,
                  onTap: () => onEditCareerItem(item),
                )
            ]),
          ),

        // Projects
        if (projects.isNotEmpty)
          _DocumentSection(
            title: 'PROJECTS',
            child: Column(children: [
              for (final item in projects)
                _DocumentEntry(
                  item: item,
                  onTap: () => onEditCareerItem(item),
                )
            ]),
          ),

        // Education
        if (education.isNotEmpty)
          _DocumentSection(
            title: 'EDUCATION',
            child: Column(children: [
              for (final item in education)
                _DocumentEntry(
                  item: item,
                  onTap: () => onEditCareerItem(item),
                )
            ]),
          ),

        // Skills
        if (skills.isNotEmpty)
          _DocumentSection(
            title: 'SKILLS & EXPERTISE',
            onTap: onOpenEditor,
            child: Text(
              skills.join('   |   '),
              style: const TextStyle(
                fontSize: 9.5,
                height: 1.45,
                color: AppColors.ink,
              ),
            ),
          ),

        // Courses / Certifications
        if (courses.isNotEmpty)
          _DocumentSection(
            title: 'CERTIFICATIONS & COURSES',
            child: Column(children: [
              for (final item in courses)
                _DocumentEntry(
                  item: item,
                  onTap: () => onEditCareerItem(item),
                )
            ]),
          ),
        const SizedBox(height: 8),
        Center(
          child: TextButton.icon(
            onPressed: onOpenEditor,
            icon: const Icon(Icons.add_rounded, size: 14),
            label: const Text('Add or edit a section'),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 32),
              textStyle: const TextStyle(fontSize: 10),
            ),
          ),
        ),
      ],
    );
  }
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.title,
    required this.child,
    this.onTap,
  });

  final String title;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.only(top: 15, left: 3, right: 3, bottom: 3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child:
                      Divider(height: 1, thickness: 0.7, color: AppColors.line),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.edit_outlined,
                    size: 11,
                    color: AppColors.primaryBlue,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

class _DocumentEntry extends StatelessWidget {
  const _DocumentEntry({required this.item, this.onTap});

  final CareerItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2, right: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                if (item.dateRange != null && item.dateRange!.trim().isNotEmpty)
                  Text(
                    item.dateRange!,
                    style:
                        const TextStyle(fontSize: 8.5, color: AppColors.stone),
                  ),
                if (onTap != null) ...[
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.edit_outlined,
                    size: 10,
                    color: AppColors.primaryBlue,
                  ),
                ],
              ],
            ),
            if (item.subtitle != null && item.subtitle!.trim().isNotEmpty) ...[
              const SizedBox(height: 1.5),
              Text(
                item.subtitle!,
                style: const TextStyle(
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                  color: AppColors.stone,
                ),
              ),
            ],
            for (final bullet in item.bullets)
              if (bullet.trim().isNotEmpty) _DocumentBullet(text: bullet),
          ],
        ),
      ),
    );
  }
}

class _DocumentBullet extends StatelessWidget {
  const _DocumentBullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5, right: 6),
            child: Container(
              width: 3.5,
              height: 3.5,
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 9.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ResumeEditTarget { contact, resume, careerItem, addItem }

class _ResumeEditSelection {
  const _ResumeEditSelection(this.target, {this.item, this.type});

  final _ResumeEditTarget target;
  final CareerItem? item;
  final CareerItemType? type;
}

class _ResumeEditorSheet extends StatelessWidget {
  const _ResumeEditorSheet({required this.state, required this.resume});

  final AppState state;
  final Resume resume;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .88,
      minChildSize: .55,
      maxChildSize: .96,
      builder: (context, scrollController) => SafeArea(
        top: false,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Text(
              'Edit resume',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 5),
            Text(
              'Choose any part of the preview. Saved changes update the preview and future exports.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            _EditorMenuTile(
              icon: Icons.person_outline_rounded,
              title: 'Personal details and summary',
              subtitle: [state.user.name, state.user.headline]
                  .where((value) => value.trim().isNotEmpty)
                  .join(' · '),
              onTap: () => Navigator.pop(
                context,
                const _ResumeEditSelection(_ResumeEditTarget.contact),
              ),
            ),
            const SizedBox(height: 9),
            _EditorMenuTile(
              icon: Icons.description_outlined,
              title: 'Resume title, target and highlights',
              subtitle: [resume.name, resume.targetRole, resume.targetCompany]
                  .whereType<String>()
                  .where((value) => value.trim().isNotEmpty)
                  .join(' · '),
              onTap: () => Navigator.pop(
                context,
                const _ResumeEditSelection(_ResumeEditTarget.resume),
              ),
            ),
            const SizedBox(height: 22),
            Text('Resume sections',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 9),
            if (state.careerItems.isEmpty)
              Text(
                'No sections yet. Add education, experience, projects, skills, or courses below.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              for (final item in state.careerItems) ...[
                _EditorMenuTile(
                  icon: _iconForCareerType(item.type),
                  title: item.title,
                  subtitle: [item.type.label, item.subtitle, item.dateRange]
                      .whereType<String>()
                      .where((value) => value.trim().isNotEmpty)
                      .join(' · '),
                  onTap: () => Navigator.pop(
                    context,
                    _ResumeEditSelection(
                      _ResumeEditTarget.careerItem,
                      item: item,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 14),
            Text('Add a section',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in CareerItemType.values)
                  ActionChip(
                    avatar: Icon(_iconForCareerType(type), size: 16),
                    label: Text(type.label),
                    onPressed: () => Navigator.pop(
                      context,
                      _ResumeEditSelection(
                        _ResumeEditTarget.addItem,
                        type: type,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorMenuTile extends StatelessWidget {
  const _EditorMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.veryLightBlue,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.lightBlue,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 19, color: AppColors.primaryBlue),
        ),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: subtitle.isEmpty
            ? null
            : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.edit_outlined, size: 18),
      ),
    );
  }
}

class _EditResumeDetailsSheet extends StatefulWidget {
  const _EditResumeDetailsSheet({required this.state, required this.resume});

  final AppState state;
  final Resume resume;

  @override
  State<_EditResumeDetailsSheet> createState() =>
      _EditResumeDetailsSheetState();
}

class _EditResumeDetailsSheetState extends State<_EditResumeDetailsSheet> {
  late final TextEditingController _name;
  late final TextEditingController _targetRole;
  late final TextEditingController _targetCompany;
  late final TextEditingController _highlights;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.resume.name);
    _targetRole = TextEditingController(text: widget.resume.targetRole ?? '');
    _targetCompany =
        TextEditingController(text: widget.resume.targetCompany ?? '');
    _highlights =
        TextEditingController(text: widget.resume.tailoredBullets.join('\n'));
  }

  @override
  void dispose() {
    _name.dispose();
    _targetRole.dispose();
    _targetCompany.dispose();
    _highlights.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resume title cannot be empty.')),
      );
      return;
    }
    widget.state.updateResumeDetails(
      resumeId: widget.resume.id,
      name: _name.text,
      targetRole: _targetRole.text,
      targetCompany: _targetCompany.text,
      tailoredBullets: _highlights.text.split('\n'),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(22, 4, 22, bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit resume details',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 5),
          Text(
            'Target fields are optional. Put each highlight on a new line.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          _sheetField(_name, 'Resume title'),
          _sheetField(_targetRole, 'Target role', hint: 'Optional'),
          _sheetField(_targetCompany, 'Target company', hint: 'Optional'),
          _sheetField(
            _highlights,
            'Targeted highlights',
            hint: 'One achievement per line',
            maxLines: 7,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save resume changes'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CareerItemEditSheet extends StatefulWidget {
  const _CareerItemEditSheet({
    required this.state,
    required this.type,
    this.item,
  });

  final AppState state;
  final CareerItemType type;
  final CareerItem? item;

  @override
  State<_CareerItemEditSheet> createState() => _CareerItemEditSheetState();
}

class _CareerItemEditSheetState extends State<_CareerItemEditSheet> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _date;
  late final TextEditingController _bullets;

  bool get _isSkill => widget.type == CareerItemType.skill;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _subtitle = TextEditingController(text: item?.subtitle ?? '');
    _date = TextEditingController(text: item?.dateRange ?? '');
    _bullets = TextEditingController(text: item?.bullets.join('\n') ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _date.dispose();
    _bullets.dispose();
    super.dispose();
  }

  void _save() {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title before saving.')),
      );
      return;
    }
    widget.state.upsertCareerItem(
      CareerItem(
        id: widget.item?.id ??
            'preview-${widget.type.name}-${DateTime.now().microsecondsSinceEpoch}',
        type: widget.type,
        title: _title.text.trim(),
        subtitle: _subtitle.text.trim().isEmpty ? null : _subtitle.text.trim(),
        dateRange: _date.text.trim().isEmpty ? null : _date.text.trim(),
        bullets: _bullets.text
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList(),
        verified: widget.item?.verified ?? false,
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final item = widget.item;
    if (item == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this resume section?'),
        content: Text('“${item.title}” will be removed from resume previews.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.state.removeCareerItem(item.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(22, 4, 22, bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.item == null ? 'Add' : 'Edit'} ${widget.type.label.toLowerCase()}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 5),
          Text(
            'Changes are saved to this resume profile and reflected in exports.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          _sheetField(
            _title,
            _isSkill ? 'Skill' : 'Title',
            hint:
                _isSkill ? 'e.g. Flutter' : 'Role, degree, project, or course',
          ),
          if (!_isSkill) ...[
            _sheetField(
              _subtitle,
              widget.type == CareerItemType.education
                  ? 'Institution'
                  : 'Organisation or context',
              hint: 'Optional',
            ),
            _sheetField(
              _date,
              'Date range',
              hint: 'e.g. Jun 2025 — Aug 2025',
            ),
            _sheetField(
              _bullets,
              'Details and achievements',
              hint: 'One item per line',
              maxLines: 6,
            ),
          ],
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save section'),
            ),
          ),
          if (widget.item != null) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: _delete,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: const Text('Remove section'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _sheetField(
  TextEditingController controller,
  String label, {
  String? hint,
  int maxLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
}

IconData _iconForCareerType(CareerItemType type) => switch (type) {
      CareerItemType.education => Icons.school_outlined,
      CareerItemType.experience => Icons.work_outline_rounded,
      CareerItemType.project => Icons.rocket_launch_outlined,
      CareerItemType.skill => Icons.bolt_outlined,
      CareerItemType.course => Icons.workspace_premium_outlined,
      CareerItemType.interview => Icons.mic_outlined,
    };

class _EditContactSheet extends StatefulWidget {
  const _EditContactSheet({required this.state});

  final AppState state;

  @override
  State<_EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends State<_EditContactSheet> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _location;
  late final TextEditingController _headline;

  @override
  void initState() {
    super.initState();
    final user = widget.state.user;
    _name = TextEditingController(text: user.name);
    _email = TextEditingController(text: user.email);
    _phone = TextEditingController(text: user.phone);
    _location = TextEditingController(text: user.location);
    _headline = TextEditingController(text: user.headline);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    _headline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(22, 14, 22, bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit contact details',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 18),
          _field(_name, 'Full name'),
          _field(_headline, 'Headline', maxLines: 2),
          _field(_email, 'Email'),
          _field(_phone, 'Phone'),
          _field(_location, 'Location'),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                widget.state.updateUser(
                  name: _name.text.trim(),
                  email: _email.text.trim(),
                  phone: _phone.text.trim(),
                  location: _location.text.trim(),
                  headline: _headline.text.trim(),
                );
                Navigator.of(context).pop();
              },
              child: const Text('Save changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController controller, String label,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}
