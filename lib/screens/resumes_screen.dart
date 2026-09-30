import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/matching.dart';
import '../models/models.dart';
import '../services/ai_tailoring_service.dart';
import '../services/resume_export_service.dart';
import '../services/resume_parser_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/pickers.dart';
import 'job_site_browser_screen.dart';
import '../widgets/route_utils.dart';
import 'resume_preview_screen.dart';

// ===========================================================================
// Resumes screen
// ===========================================================================

class ResumesScreen extends StatefulWidget {
  const ResumesScreen({super.key});

  @override
  State<ResumesScreen> createState() => _ResumesScreenState();
}

class _ResumesScreenState extends State<ResumesScreen> {
  int _filter = 0; // 0 = all, 1 = master, 2 = tailored
  String _query = '';
  bool _uploading = false;
  final _parser = const ResumeParserService();

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    List<Resume> filtered = List.of(state.resumes);
    if (_filter == 1) {
      filtered = filtered.where((r) => r.type == ResumeType.master).toList();
    }
    if (_filter == 2) {
      filtered = filtered.where((r) => r.type == ResumeType.tailored).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered = filtered
          .where((r) =>
              r.name.toLowerCase().contains(q) ||
              (r.targetRole?.toLowerCase().contains(q) ?? false) ||
              (r.targetCompany?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
        children: [
          Text('Resumes', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(
            'Master and tailored resumes, grounded in your evidence.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _showCreateDialog(context, state),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New resume'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      pushRouteOnce(context, (_) => const TailorFlow()),
                  icon: const Icon(Icons.auto_fix_high,
                      size: 18, color: AppColors.violet),
                  label: const Text('Tailor for role'),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed:
                  _uploading ? null : () => _uploadResume(context, state),
              icon: _uploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.upload_file_rounded, size: 17),
              label:
                  Text(_uploading ? 'Reading resume…' : 'Upload a resume file'),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, label) in const [
                  (0, 'All'),
                  (1, 'Master'),
                  (2, 'Tailored')
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == i,
                      onSelected: (_) => setState(() => _filter = i),
                    ),
                  ),
              ],
            ),
          ),
          if (state.resumes.length > 3) ...[
            const SizedBox(height: 12),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search resumes…',
                prefixIcon: Icon(Icons.search_rounded, size: 20),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            EmptyState(
              icon: Icons.description_outlined,
              title: 'No resumes here yet',
              subtitle:
                  'Create a master resume, then tailor it for individual roles.',
              actionLabel: 'Create resume',
              onAction: () => _showCreateDialog(context, state),
            )
          else
            ...filtered.map((resume) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ResumeCard(
                    resume: resume,
                    onTap: () => _showResumeSheet(context, state, resume),
                  ),
                )),
        ],
      ),
    );
  }

  Future<void> _uploadResume(BuildContext context, AppState state) async {
    setState(() => _uploading = true);
    try {
      final result = await _parser.pickAndParseResume();
      if (!mounted || result == null) return;
      if (result.isEmpty) {
        _showMessage(
            'No readable text was found. Try a text-based PDF, TXT, MD, or RTF file.');
        return;
      }
      final confirmed = await _showImportReview(result);
      if (!mounted || confirmed != true) return;
      state.importParsedResume(
        name: result.name,
        email: result.email,
        phone: result.phone,
        location: result.location,
        headline: result.headline,
        degree: result.degree,
        school: result.school,
        graduation: result.graduation,
        role: result.role,
        company: result.company,
        experience: result.experience,
        skills: result.skills,
        bullets: result.allBullets,
      );
      _showMessage('Resume imported. Review the extracted details in Career.');
    } catch (_) {
      if (mounted) {
        _showMessage(
            'Could not read that file. Choose a text-based PDF, TXT, MD, or RTF resume.');
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<bool?> _showImportReview(ResumeParseResult result) {
    final fields = <String, String>{
      'Name': result.name,
      'Email': result.email,
      'Phone': result.phone,
      'Location': result.location,
      'Headline': result.headline,
      'Education': [result.degree, result.school, result.graduation]
          .where((v) => v.isNotEmpty)
          .join(' · '),
      'Experience':
          [result.role, result.company].where((v) => v.isNotEmpty).join(' · '),
      'Skills': result.skills.join(', '),
    };
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Review extracted details'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text(
                  'Check the fields before saving. Missing fields were not guessed.'),
              const SizedBox(height: 16),
              for (final entry in fields.entries)
                if (entry.value.isNotEmpty) ...[
                  Text(entry.key,
                      style: Theme.of(dialogContext).textTheme.labelMedium),
                  const SizedBox(height: 2),
                  Text(entry.value),
                  const SizedBox(height: 10),
                ],
              if (result.allBullets.isNotEmpty)
                Text('${result.allBullets.length} achievement bullets found.',
                    style: Theme.of(dialogContext).textTheme.bodySmall),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save resume')),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showCreateDialog(BuildContext context, AppState state) {
    final nameController = TextEditingController(text: 'New master resume');
    ResumeType selected = ResumeType.master;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Create a resume'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'Name', hintText: 'e.g. Priya Sharma — Master'),
              ),
              const SizedBox(height: 16),
              Text('Type', style: Theme.of(dialogContext).textTheme.labelLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final type in ResumeType.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(type.label),
                        selected: selected == type,
                        onSelected: (_) =>
                            setDialogState(() => selected = type),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(selected.hint,
                  style: Theme.of(dialogContext).textTheme.bodySmall),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                state.createResume(
                  nameController.text.trim().isEmpty
                      ? 'Untitled resume'
                      : nameController.text.trim(),
                  selected,
                );
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    ).then((_) => nameController.dispose());
  }

  void _showResumeSheet(BuildContext context, AppState state, Resume resume) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(resume.name,
                          style:
                              Theme.of(sheetContext).textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ResumeTypeBadge(type: resume.type),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: resume.status == ResumeStatus.ready
                                  ? AppColors.successSubtle
                                  : AppColors.warningSubtle,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              resume.status.label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: resume.status == ResumeStatus.ready
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (resume.matchScore > 0)
                  MatchRing(score: resume.matchScore, size: 52, stroke: 5),
              ],
            ),
            if (resume.targetRole != null) ...[
              const SizedBox(height: 12),
              Text(
                'Tailored for ${resume.targetRole} at ${resume.targetCompany ?? '—'}',
                style: Theme.of(sheetContext).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 20),
            Text('Version history',
                style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...resume.versions.map(
              (version) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      version.isCurrent
                          ? Icons.check_circle_rounded
                          : Icons.history_rounded,
                      size: 17,
                      color: version.isCurrent
                          ? AppColors.success
                          : AppColors.darkMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${version.label} · ${formatShortDate(version.createdAt)}',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              fontWeight: version.isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                      ),
                    ),
                    if (version.isCurrent)
                      const Text(
                        'Current',
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  pushRouteOnce(
                    context,
                    (_) => ResumePreviewScreen(resume: resume),
                  );
                },
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Preview resume'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      pushRouteOnce(
                        context,
                        (_) => TailorFlow(initialResume: resume),
                      );
                    },
                    icon: const Icon(Icons.auto_fix_high, size: 17),
                    label: const Text('Tailor'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _exportResume(context, resume),
                    icon: const Icon(Icons.download_rounded, size: 17),
                    label: const Text('Export'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _confirmDelete(context, state, resume),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('Delete resume'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState state, Resume resume) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this resume?'),
        content: const Text(
            'Every version in its history will be removed. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              state.deleteResume(resume.id);
              Navigator.of(dialogContext).pop(); // close the dialog
              Navigator.of(dialogContext).pop(); // close the detail sheet
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _exportResume(BuildContext context, Resume resume) {
    final AppState state = AppScope.of(context);
    const ResumeExportService exportService = ResumeExportService();
    exportService.promptAndExport(context, state: state, resume: resume);
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.resume, required this.onTap});

  final Resume resume;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurfaceSubtle
                  : AppColors.sageSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              resume.type == ResumeType.master
                  ? Icons.folder_copy_rounded
                  : Icons.auto_fix_high,
              size: 20,
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.violetSoft
                  : AppColors.sage,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(resume.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 8,
                  runSpacing: 5,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ResumeTypeBadge(type: resume.type),
                    Text(formatDaysAgo(resume.updatedAt),
                        style: Theme.of(context).textTheme.bodySmall),
                    if (resume.status == ResumeStatus.ready)
                      const Icon(Icons.check_circle_rounded,
                          size: 13, color: AppColors.success)
                    else
                      const Icon(Icons.edit_rounded,
                          size: 12, color: AppColors.warning),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (resume.type == ResumeType.tailored && resume.matchScore > 0)
            MatchRing(score: resume.matchScore, size: 40, stroke: 4)
          else
            const Icon(Icons.chevron_right_rounded, color: AppColors.darkMuted),
        ],
      ),
    );
  }
}

// ===========================================================================
// Tailor flow — 3 steps: Paste → Match → Review
// ===========================================================================

const String sampleJobDescription = '''
Product Engineer Intern — Bengaluru (hybrid)

We're hiring a Product Engineer intern to build React & Next.js dashboards
with TypeScript and Tailwind CSS. You'll design REST APIs, work with
PostgreSQL, and turn raw analytics data into clear charts our team reads
every day. Experience with Figma, Git, and writing automated tests is a
plus. Docker and CI/CD exposure helps.

Requirements: strong product sense, ability to communicate decisions,
and a portfolio that shows real projects.
''';

class TailorFlow extends StatefulWidget {
  const TailorFlow({
    super.key,
    this.initialResume,
    this.initialJobDescription,
    this.job,
  });

  final Resume? initialResume;
  final String? initialJobDescription;

  /// When the flow was started from a specific open role, applying keeps the
  /// application tied to that job.
  final JobOpening? job;

  @override
  State<TailorFlow> createState() => _TailorFlowState();
}

class _TailorFlowState extends State<TailorFlow> {
  int _step = 0;
  Resume? _resume;
  final TextEditingController _jdController = TextEditingController();
  MatchReport? _report;
  final Map<String, String> _edits = {}; // skill -> edited bullet
  final Set<String> _accepted = {};
  final Set<String> _skipped = {};
  final AiTailoringService _aiService = AiTailoringService();
  bool _isAnalyzing = false;
  bool _applied = false;
  String? _analysisNotice;

  @override
  void initState() {
    super.initState();
    _resume = widget.initialResume;
    if (widget.initialJobDescription != null) {
      _jdController.text = widget.initialJobDescription!;
    }
  }

  @override
  void dispose() {
    _jdController.dispose();
    _aiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tailor a resume'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _StepIndicator(step: _step),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: switch (_step) {
                0 => _stepPaste(context),
                1 => _stepMatch(context),
                _ => _stepReview(context),
              },
            ),
          ],
        ),
      ),
    );
  }

  // -- Step 1 ---------------------------------------------------------------

  Widget _stepPaste(BuildContext context) {
    final AppState state = AppScope.of(context);
    return Column(
      key: const ValueKey('step-paste'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        Text('Choose a resume', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        PickField(
          label: 'Source resume',
          value: _resume?.name ?? '',
          icon: Icons.description_outlined,
          hint: 'Pick the master or tailored resume',
          onTap: () async {
            final picked = await showPickerSheet<Resume>(
              context: context,
              title: 'Source resume',
              options: state.resumes,
              labelOf: (r) => r.name,
              subtitleOf: (r) => '${r.type.label} · ${r.status.label}',
              initial: _resume,
            );
            if (picked != null && mounted) setState(() => _resume = picked);
          },
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Text('Job description',
                style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(
              onPressed: () => _jdController.text = sampleJobDescription,
              child: const Text('Use sample'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _jdController,
          maxLines: 9,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            hintText:
                'Paste the full job description here.\n\nResumer separates real requirements from generic hiring noise…',
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isAnalyzing
                ? null
                : () {
                    if (_resume == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Pick a source resume first')),
                      );
                      return;
                    }
                    if (_jdController.text.trim().length < 20) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Paste a job description (at least 20 characters)')),
                      );
                      return;
                    }
                    _analyze(state);
                  },
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome_rounded, size: 17),
            label: Text(_isAnalyzing ? 'Tailoring with AI…' : 'Tailor resume'),
          ),
        ),
      ],
    );
  }

  // -- Step 2 ---------------------------------------------------------------

  Widget _stepMatch(BuildContext context) {
    final report = _report!;
    return Column(
      key: const ValueKey('step-match'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_analysisNotice != null) ...[
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.warningSubtle,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.wifi_off_rounded,
                    size: 17, color: AppColors.warning),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(_analysisNotice!,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        GlassCard(
          child: Row(
            children: [
              MatchRing(score: report.score, size: 64, stroke: 6),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Match score',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${report.backedCount} of ${report.totalCount} requirements backed by your evidence',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      report.generatedByAi
                          ? 'Generated with AI · grounded in your Career profile.'
                          : 'Offline evidence match.',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.darkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (report.summary.isNotEmpty) ...[
          Text('Tailoring direction',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(report.summary, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 18),
        ],
        Text('Requirement map', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
            'Strong, partial and missing requirements — with the evidence behind each.',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            children: [
              for (final (i, requirement) in report.requirements.indexed) ...[
                if (i > 0) const SizedBox(height: 14),
                SkillBar(
                  label: requirement.skill,
                  status: requirement.status,
                  value: requirement.status == 'strong'
                      ? 0.9
                      : requirement.status == 'partial'
                          ? 0.55
                          : 0.22,
                ),
                if (requirement.status != 'strong')
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      requirement.evidence,
                      style: const TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: AppColors.darkMuted,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => setState(() {
              _step = 2;
              _edits.clear();
              _accepted.clear();
              _skipped.clear();
            }),
            icon: const Icon(Icons.rate_review_rounded, size: 17),
            label: const Text('Review suggestions'),
          ),
        ),
      ],
    );
  }

  // -- Step 3 ---------------------------------------------------------------

  Widget _stepReview(BuildContext context) {
    final report = _report!;
    final suggestions = _suggestions(report);
    final decidedCount = _accepted.length + _edits.length + _skipped.length;
    final allResolved =
        suggestions.isEmpty || decidedCount >= suggestions.length;

    return Column(
      key: const ValueKey('step-review'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Review every rewrite',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Accept it, edit it, or skip it. Your voice stays intact and nothing changes silently.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 14),
        if (suggestions.isEmpty)
          GlassCard(
            child: Row(
              children: [
                const Icon(Icons.verified_rounded,
                    color: AppColors.success, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your resume already covers every requirement strongly. Export it as-is.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          ...suggestions.indexed.map((entry) {
            final (index, suggestion) = entry;
            final (skill, original, rewrite) = suggestion;
            final accepted = _accepted.contains(skill);
            final edited = _edits.containsKey(skill);
            final skipped = _skipped.contains(skill);
            final decided = accepted || edited || skipped;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppColors.violet.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.violetSoft),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(skill,
                                style:
                                    Theme.of(context).textTheme.titleMedium)),
                        if (accepted)
                          const Icon(Icons.check_circle_rounded,
                              size: 20, color: AppColors.success)
                        else if (skipped)
                          const Icon(Icons.remove_circle_outline_rounded,
                              size: 20, color: AppColors.darkMuted),
                        if (edited)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.edit_rounded,
                                size: 18, color: AppColors.warning),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Current: $original',
                      style: const TextStyle(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: AppColors.darkMuted),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.violet.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.violet.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        _edits[skill] ?? rewrite,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success,
                                minimumSize: const Size(0, 40)),
                            onPressed: decided && !edited
                                ? null
                                : () => setState(() {
                                      _accepted.add(skill);
                                      _edits.remove(skill);
                                      _skipped.remove(skill);
                                    }),
                            child: Text(accepted ? 'Accepted' : 'Accept'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 40)),
                            onPressed: () => _editSuggestion(
                                skill, _edits[skill] ?? rewrite),
                            child: Text(edited ? 'Edit' : 'Edit'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                                minimumSize: const Size(0, 40),
                                foregroundColor: AppColors.darkMuted),
                            onPressed: decided && !skipped
                                ? null
                                : () => setState(() {
                                      _skipped.add(skill);
                                      _accepted.remove(skill);
                                      _edits.remove(skill);
                                    }),
                            child: Text(skipped ? 'Skipped' : 'Skip'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: allResolved
                    ? () => _exportTailored(context, report)
                    : () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Accept, edit or skip every suggestion to export')),
                        ),
                icon: const Icon(Icons.download_rounded, size: 17),
                label: const Text('Export resume'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: allResolved && !_applied
                    ? () => _applyTailored(context, report)
                    : allResolved && _applied
                        ? null
                        : () => ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Accept, edit or skip every suggestion to apply')),
                            ),
                icon: _applied
                    ? const Icon(Icons.check_circle_rounded, size: 17)
                    : const Icon(Icons.send_rounded, size: 17),
                label: Text(_applied ? 'Applied ✓' : 'Apply'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Clean, ATS-safe format · PDF or Word (.docx) · selectable text',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.darkMuted),
        ),
      ],
    );
  }

  void _editSuggestion(String skill, String currentText) {
    final controller = TextEditingController(text: currentText);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit suggestion'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
              hintText: 'Rewrite the bullet in your own words…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              setState(() => _edits[skill] = controller.text.trim());
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Save edit'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportTailored(BuildContext context, MatchReport report) async {
    final AppState state = AppScope.of(context);
    final savedId = _saveTailoredResume(context, report);
    if (savedId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a source resume to export')),
      );
      return;
    }
    final tailored =
        state.resumes.where((resume) => resume.id == savedId).firstOrNull;
    if (tailored == null) return;
    const ResumeExportService exportService = ResumeExportService();
    await exportService.promptAndExport(context,
        state: state, resume: tailored);
  }

  /// Saves the tailored resume with the accepted rewrites and returns its id,
  /// or null when no source resume was selected.
  String? _saveTailoredResume(BuildContext context, MatchReport report) {
    final AppState state = AppScope.of(context);
    if (_resume == null) return null;
    final suggestions = _suggestions(report);
    final tailoredBullets = <String>[
      for (final suggestion in suggestions)
        if (_edits.containsKey(suggestion.$1))
          _edits[suggestion.$1]!
        else if (_accepted.contains(suggestion.$1))
          suggestion.$3,
    ];
    return state.saveTailoredResume(
      sourceResumeId: _resume!.id,
      matchScore: report.score,
      targetRole: report.targetRole,
      targetCompany: report.targetCompany,
      tailoredBullets: tailoredBullets,
    );
  }

  Future<void> _applyTailored(BuildContext context, MatchReport report) async {
    final AppState state = AppScope.of(context);
    if (_saveTailoredResume(context, report) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a source resume to apply with')),
      );
      return;
    }
    final job = widget.job;
    final jobTitle = job?.title ?? report.targetRole;
    final companyName = job?.companyName ?? report.targetCompany;
    final alreadyApplied = state.applications.any(
      (application) =>
          application.jobTitle == jobTitle &&
          application.companyName == companyName,
    );
    if (!alreadyApplied) {
      state.applyToJob(
        jobTitle: jobTitle,
        companyName: companyName,
        matchScore: report.score,
        location: job?.location,
        remote: job != null && job.workMode.toLowerCase() == 'remote',
      );
    }
    setState(() => _applied = true);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          alreadyApplied
              ? '$jobTitle at $companyName is already in your tracker.'
              : 'Applied to $jobTitle at $companyName with your tailored resume · ${report.score}% match',
        ),
      ),
    );

    // Hand over to the posting inside the app: sessions persist in the
    // WebView, profile details are autofilled, and auto-submit can finish
    // the application.
    if (job == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JobSiteBrowserScreen(job: job),
      ),
    );
  }

  List<(String, String, String)> _suggestions(MatchReport report) {
    if (report.suggestions.isNotEmpty) {
      return [
        for (final suggestion in report.suggestions)
          (
            suggestion.skill,
            suggestion.currentBullet,
            suggestion.rewrittenBullet,
          ),
      ];
    }
    const templates = {
      'React & Next.js':
          'Rebuilt the campus events platform as a React SPA — 60% faster registration flows used by 400+ students.',
      'API development':
          'Designed REST APIs serving five internal services and documented the integration flow end-to-end.',
      'Data visualization':
          'Built an analytics dashboard that turned raw support data into daily charts for a 12-person team.',
      'TypeScript':
          'Shipped typed React components and shared API contracts with TypeScript across a 5-service codebase.',
      'Tailwind CSS':
          'Styled the full product UI with Tailwind CSS, cutting custom CSS by 70% while keeping the design system.',
      'Automated testing':
          'Added Jest unit tests and end-to-end flows that lifted regression coverage from 40% to 85%.',
      'Git & collaboration':
          'Rode the merge-request loop on GitHub — reviewed 30+ PRs and kept main green through placement season.',
      'SQL / databases':
          'Designed PostgreSQL schemas with Prisma and cut query time 4x with indexing during the campus platform build.',
      'Deployment / DevOps':
          'Containerized the campus platform with Docker and wired a CI/CD pipeline that deploys on every merge.',
      'Figma / design sense':
          'Translated Figma prototypes into pixel-consistent React components with the team design system.',
    };
    final weak =
        report.requirements.where((r) => r.status != 'strong').take(3).toList();
    if (weak.isEmpty) return const [];
    return [
      for (final requirement in weak)
        (
          requirement.skill,
          'No explicit bullet mentions ${requirement.skill.toLowerCase()}.',
          templates[requirement.skill] ??
              'Added a grounded bullet that demonstrates ${requirement.skill} using evidence from your projects and internships.',
        ),
    ];
  }

  Future<void> _analyze(AppState state) async {
    setState(() {
      _isAnalyzing = true;
      _analysisNotice = null;
    });
    MatchReport report;
    try {
      report = await _aiService.tailor(
        jobDescription: _jdController.text.trim(),
        evidence: state.careerItems,
      );
    } on AiTailoringException catch (error) {
      report = buildMatchReport(
        jobDescription: _jdController.text,
        evidence: state.careerItems,
      );
      _analysisNotice =
          '${error.message} An offline evidence match is shown instead.';
    }
    if (!mounted) return;
    setState(() {
      _report = report;
      _isAnalyzing = false;
      _step = 1;
    });
  }
}

// ---------------------------------------------------------------------------
// Step indicator
// ---------------------------------------------------------------------------

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  static const _labels = ['Paste', 'Match', 'Review'];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        for (var i = 0; i < _labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: i <= step
                      ? AppColors.violet.withValues(alpha: 0.7)
                      : dark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= step ? AppColors.violet : Colors.transparent,
                  border: Border.all(
                    color: i <= step
                        ? AppColors.violet
                        : (dark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.12)),
                  ),
                ),
                child: Center(
                  child: i < step
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : Text(
                          '${i + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: i == step
                                ? Colors.white
                                : (dark
                                    ? AppColors.darkMuted
                                    : AppColors.lightMuted),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _labels[i],
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: i == step ? FontWeight.w700 : FontWeight.w500,
                  color: i == step
                      ? AppColors.violetSoft
                      : (dark ? AppColors.darkMuted : AppColors.lightMuted),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
