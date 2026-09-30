import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/pickers.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  ApplicationStatus? _filter;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);

    List<Application> filtered = List.of(state.applications);
    if (_filter != null) {
      filtered = filtered.where((a) => a.status == _filter).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      filtered = filtered
          .where((a) =>
              a.jobTitle.toLowerCase().contains(q) ||
              a.companyName.toLowerCase().contains(q) ||
              (a.location?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Applications',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Your job search, tracked end to end.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showAddDialog(context, state),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryTile(
                  value: '${state.activeApplicationCount}',
                  label: 'Active',
                  icon: Icons.rocket_launch_rounded,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  value: '${state.interviewCount}',
                  label: 'Interviews',
                  icon: Icons.chat_rounded,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryTile(
                  value: '${state.offerCount}',
                  label: 'Offers',
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip(null, 'All'),
                for (final status in ApplicationStatus.values)
                  _filterChip(status, status.label),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search roles, companies…',
              prefixIcon: Icon(Icons.search_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            EmptyState(
              icon: Icons.work_outline,
              title: _filter == null
                  ? 'No applications yet'
                  : 'Nothing in "${_filter!.label}"',
              subtitle:
                  'Save the first role you apply to and watch it progress.',
              actionLabel: 'Add application',
              onAction: () => _showAddDialog(context, state),
            )
          else
            ...filtered.map(
              (app) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ApplicationCard(
                  application: app,
                  onTap: () => _showDetailSheet(context, state, app),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(ApplicationStatus? status, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: _filter == status,
        onSelected: (_) => setState(() => _filter = status),
      ),
    );
  }

  void _showAddDialog(BuildContext context, AppState state) {
    showDialog<void>(
      context: context,
      builder: (_) => _AddApplicationDialog(state: state),
    );
  }

  void _showDetailSheet(BuildContext context, AppState state, Application app) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.jobTitle,
                          style:
                              Theme.of(sheetContext).textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      Text(
                        '${app.companyName}${app.location != null ? ' · ${app.location}' : ''}${app.remote ? ' · Remote' : ''}',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: AppColors.darkMuted),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBadge(status: app.status),
                          if (app.appliedByAi) const AppliedByAiBadge(),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    MatchRing(score: app.matchScore, size: 52, stroke: 5),
                    const SizedBox(height: 4),
                    const Text(
                      'match',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: AppColors.darkMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Progress',
                style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 14),
            _ProgressTimeline(status: app.status),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showPickerSheet<ApplicationStatus>(
                        context: sheetContext,
                        title: 'Update status',
                        options: ApplicationStatus.values,
                        labelOf: (s) => s.label,
                        initial: app.status,
                      );
                      if (picked != null && picked != app.status) {
                        state.updateApplicationStatus(app.id, picked);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      }
                    },
                    icon: const Icon(Icons.sync_rounded, size: 17),
                    label: const Text('Update status'),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Delete',
                  onPressed: () {
                    state.deleteApplication(app.id);
                    Navigator.of(sheetContext).pop();
                  },
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 19, color: AppColors.danger),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary tile
// ---------------------------------------------------------------------------

class _SummaryTile extends StatelessWidget {
  const _SummaryTile(
      {required this.value,
      required this.label,
      required this.icon,
      required this.color});

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 14),
      borderRadius: 18,
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 7),
          Text(
            value,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkMuted
                    : AppColors.lightMuted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Application card
// ---------------------------------------------------------------------------

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.onTap});

  final Application application;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = application;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          CompanyAvatar(name: app.companyName, size: 42),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.jobTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  '${app.companyName}${app.remote ? ' · Remote' : app.location != null ? ' · ${app.location}' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBadge(status: app.status),
                    if (app.appliedByAi) const AppliedByAiBadge(),
                    Text(formatDaysAgo(app.updatedAt),
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (app.matchScore > 0)
            MatchRing(score: app.matchScore, size: 40, stroke: 4),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress timeline
// ---------------------------------------------------------------------------

class _ProgressTimeline extends StatelessWidget {
  const _ProgressTimeline({required this.status});

  final ApplicationStatus status;

  static const _order = [
    ApplicationStatus.saved,
    ApplicationStatus.preparing,
    ApplicationStatus.applied,
    ApplicationStatus.assessment,
    ApplicationStatus.interview,
    ApplicationStatus.offer,
  ];

  @override
  Widget build(BuildContext context) {
    if (status == ApplicationStatus.rejected) {
      return GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.close_rounded, color: AppColors.danger, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This application was not selected this time. Keep the momentum — the next role is a fresh start.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }

    final currentIndex = _order.indexOf(status);
    return Row(
      children: [
        for (final (i, step) in _order.indexed)
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i <= currentIndex
                              ? AppColors.violet
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.08)),
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i <= currentIndex
                            ? AppColors.violet
                            : Colors.transparent,
                        border: Border.all(
                          color: i <= currentIndex
                              ? AppColors.violet
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.16)
                                  : Colors.black.withValues(alpha: 0.14)),
                        ),
                      ),
                      child: Center(
                        child: i < currentIndex
                            ? const Icon(Icons.check_rounded,
                                size: 12, color: Colors.white)
                            : i == currentIndex
                                ? const Icon(Icons.circle,
                                    size: 7, color: Colors.white)
                                : null,
                      ),
                    ),
                    if (i < _order.length - 1)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i < currentIndex
                              ? AppColors.violet
                              : (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.08)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _labelFor(step),
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight:
                        i == currentIndex ? FontWeight.w700 : FontWeight.w500,
                    color: i <= currentIndex
                        ? AppColors.violetSoft
                        : (Theme.of(context).brightness == Brightness.dark
                            ? AppColors.darkMuted
                            : AppColors.lightMuted),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _labelFor(ApplicationStatus step) => switch (step) {
        ApplicationStatus.saved => 'Saved',
        ApplicationStatus.preparing => 'Prep',
        ApplicationStatus.applied => 'Applied',
        ApplicationStatus.assessment => 'Assess',
        ApplicationStatus.interview => 'Interview',
        ApplicationStatus.offer => 'Offer',
        ApplicationStatus.rejected => '—',
      };
}

// ---------------------------------------------------------------------------
// Add application dialog
// ---------------------------------------------------------------------------

class _AddApplicationDialog extends StatefulWidget {
  const _AddApplicationDialog({required this.state});

  final AppState state;

  @override
  State<_AddApplicationDialog> createState() => _AddApplicationDialogState();
}

class _AddApplicationDialogState extends State<_AddApplicationDialog> {
  final _title = TextEditingController();
  final _company = TextEditingController();
  final _location = TextEditingController();
  ApplicationStatus _status = ApplicationStatus.saved;
  int _match = 0;
  bool _remote = false;

  @override
  void dispose() {
    _title.dispose();
    _company.dispose();
    _location.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add application'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _title,
              autofocus: true,
              decoration: const InputDecoration(
                  labelText: 'Job title', hintText: 'e.g. SDE Intern'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _company,
              decoration: const InputDecoration(
                  labelText: 'Company', hintText: 'e.g. StartupHub'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _location,
              decoration:
                  const InputDecoration(labelText: 'Location (optional)'),
            ),
            const SizedBox(height: 12),
            PickField(
              label: 'Status',
              value: _status.label,
              icon: Icons.sync_rounded,
              onTap: () async {
                final picked = await showPickerSheet<ApplicationStatus>(
                  context: context,
                  title: 'Initial status',
                  options: ApplicationStatus.values,
                  labelOf: (s) => s.label,
                  initial: _status,
                );
                if (picked != null) setState(() => _status = picked);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Match score',
                          style: Theme.of(context).textTheme.labelLarge),
                      Text(
                        _match == 0 ? 'Not analyzed yet' : '$_match%',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.cyanBright),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _remote,
                  onChanged: (v) => setState(() => _remote = v),
                ),
                const Text('Remote',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            Slider(
              value: _match.toDouble(),
              max: 100,
              divisions: 100,
              label: '$_match%',
              onChanged: (v) => setState(() => _match = v.round()),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_title.text.trim().isEmpty || _company.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Job title and company are required')),
              );
              return;
            }
            widget.state.addApplication(
              jobTitle: _title.text.trim(),
              companyName: _company.text.trim(),
              status: _status,
              matchScore: _match,
              location:
                  _location.text.trim().isEmpty ? null : _location.text.trim(),
              remote: _remote,
            );
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
