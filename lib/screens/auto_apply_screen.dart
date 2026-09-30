import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/matching.dart';
import '../models/models.dart';
import '../services/ai_tailoring_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

// ===========================================================================
// AI auto-apply — tailor the master resume for every open role and apply.
// ===========================================================================

enum _JobRunState { queued, tailoring, applied, skipped }

class AutoApplyScreen extends StatefulWidget {
  const AutoApplyScreen({super.key});

  @override
  State<AutoApplyScreen> createState() => _AutoApplyScreenState();
}

class _AutoApplyScreenState extends State<AutoApplyScreen> {
  final AiTailoringService _aiService = AiTailoringService();
  final Map<String, _JobRunState> _runState = {};
  bool _running = false;
  bool _completed = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    // Auto-apply runs immediately when enabled — no manual start needed.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final AppState state = AppScope.of(context);
      if (_candidateJobs(state).isNotEmpty) {
        _run(state);
      }
    });
  }

  @override
  void dispose() {
    _aiService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final jobs = _candidateJobs(state);
    for (final job in jobs) {
      _runState.putIfAbsent(job.id, () => _JobRunState.queued);
    }
    final appliedCount =
        _runState.values.where((s) => s == _JobRunState.applied).length;
    final allDone = !_running && _completed;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI auto-apply'),
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
            GlassCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.sageSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded,
                            size: 19, color: AppColors.sage),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Tailored by AI',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              'The master resume is tailored to every open role before applying.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          allDone
                              ? 'Applied to $appliedCount role'
                                  '${appliedCount == 1 ? '' : 's'} with AI.'
                              : 'Ready to apply to ${jobs.length} open '
                                  'role${jobs.length == 1 ? '' : 's'}.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      if (appliedCount > 0 && !allDone)
                        Text(
                          '$appliedCount / ${jobs.length}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (_notice != null) ...[
              const SizedBox(height: 14),
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
                      child: Text(_notice!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text('Open roles', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Each application below is tagged “Applied by AI” in your tracker.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            if (jobs.isEmpty)
              const EmptyState(
                icon: Icons.task_alt_rounded,
                title: 'No open roles to apply to',
                subtitle:
                    'Every open internship and job already has an application.',
              )
            else
              for (final job in jobs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _JobRunCard(
                    job: job,
                    state: _runState[job.id] ?? _JobRunState.queued,
                  ),
                ),
            const SizedBox(height: 18),
            if (allDone)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.bookmark_rounded, size: 17),
                  label: const Text('View in tracker'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _running ? null : () => _run(state),
                  icon: _running
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome_rounded, size: 17),
                  label: Text(_running
                      ? 'Applying with AI…'
                      : appliedCount > 0
                          ? 'Resume auto-apply'
                          : 'Start AI auto-apply'),
                ),
              ),
            const SizedBox(height: 6),
            const Text(
              'Only your Career profile evidence is used. Every application stays visible and editable in the tracker.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.darkMuted),
            ),
          ],
        ),
      ),
    );
  }

  List<JobOpening> _candidateJobs(AppState state) {
    return state.jobOpenings.where((job) {
      final alreadyApplied = state.applications.any(
        (application) =>
            application.jobTitle == job.title &&
            application.companyName == job.companyName,
      );
      return !alreadyApplied;
    }).toList();
  }

  Future<void> _run(AppState state) async {
    setState(() {
      _running = true;
      _notice = null;
      for (final id in _runState.keys) {
        _runState[id] = _JobRunState.queued;
      }
    });

    final jobs = _candidateJobs(state);
    for (final job in jobs) {
      if (!mounted) return;
      setState(() => _runState[job.id] = _JobRunState.tailoring);
      final report = await _tailorFor(state, job);
      if (!mounted) return;
      if (report != null) {
        state.aiApplyToJob(job: job, report: report);
        setState(() => _runState[job.id] = _JobRunState.applied);
      } else {
        setState(() => _runState[job.id] = _JobRunState.skipped);
      }
      // Small pause so the progress animation is visible between roles.
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    if (!mounted) return;
    setState(() {
      _running = false;
      _completed = true;
    });
  }

  Future<MatchReport?> _tailorFor(AppState state, JobOpening job) async {
    final jobDescription =
        '${job.title} — ${job.companyName}\n\n${job.description}\n\n'
        'Skills: ${job.skills.join(', ')}';
    try {
      return await _aiService.tailor(
        jobDescription: jobDescription,
        evidence: state.careerItems,
      );
    } on AiTailoringException catch (error) {
      // Never claim "Applied by AI" for a run whose tailoring failed — the
      // job is skipped instead of being recorded with an offline guess.
      if (!mounted) return null;
      setState(() {
        _notice ??= error.message;
      });
      return null;
    }
  }
}

class _JobRunCard extends StatelessWidget {
  const _JobRunCard({required this.job, required this.state});

  final JobOpening job;
  final _JobRunState state;

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (state) {
      _JobRunState.queued => (
          Icons.radio_button_unchecked_rounded,
          AppColors.darkMuted,
          'Queued'
        ),
      _JobRunState.tailoring => (
          Icons.auto_awesome_rounded,
          AppColors.warning,
          'Tailoring…'
        ),
      _JobRunState.applied => (
          Icons.check_circle_rounded,
          AppColors.success,
          'Applied by AI'
        ),
      _JobRunState.skipped => (
          Icons.remove_circle_outline_rounded,
          AppColors.danger,
          'Skipped'
        ),
    };
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          CompanyAvatar(name: job.companyName, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(job.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  '${job.companyName} · ${job.workMode}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (state == _JobRunState.tailoring)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.2),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
