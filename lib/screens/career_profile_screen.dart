import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';

class CareerProfileScreen extends StatefulWidget {
  const CareerProfileScreen({super.key});

  @override
  State<CareerProfileScreen> createState() => _CareerProfileScreenState();
}

class _CareerProfileScreenState extends State<CareerProfileScreen> {
  CareerItemType? _filter;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final filtered = _filter == null
        ? state.careerItems
        : state.careerItems.where((item) => item.type == _filter).toList();
    final verified = state.careerItems.where((item) => item.verified).length;

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 134),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Career profile',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 5),
                    Text(
                      'The evidence behind every tailored resume.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Add career detail',
                onPressed: () => _chooseType(context, state),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _EvidenceSummary(
            completion: state.profileCompletion.round(),
            total: state.careerItems.length,
            verified: verified,
          ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                ),
                for (final type in CareerItemType.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(type.label),
                      selected: _filter == type,
                      onSelected: (_) => setState(() => _filter = type),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SectionHeader(
            title: _filter?.label ?? 'All evidence',
            subtitle:
                '${filtered.length} details available to the tailoring engine',
            action: 'Add',
            onAction: () => _filter == null
                ? _chooseType(context, state)
                : _showEditor(context, state, _filter!),
          ),
          const SizedBox(height: 12),
          if (filtered.isEmpty)
            EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No ${_filter?.label.toLowerCase() ?? 'evidence'} yet',
              subtitle:
                  'Add a real detail that AI can safely use in your resume.',
              actionLabel: 'Add detail',
              onAction: () => _filter == null
                  ? _chooseType(context, state)
                  : _showEditor(context, state, _filter!),
            )
          else
            for (final item in filtered)
              Padding(
                padding: const EdgeInsets.only(bottom: 11),
                child: _CareerItemCard(
                  item: item,
                  onEdit: () =>
                      _showEditor(context, state, item.type, item: item),
                  onDelete: () => _confirmDelete(context, state, item),
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _chooseType(BuildContext context, AppState state) async {
    final type = await showModalBottomSheet<CareerItemType>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('What would you like to add?',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 14),
              for (final option in CareerItemType.values)
                ListTile(
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.sageSoft,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child:
                        Icon(_iconFor(option), size: 19, color: AppColors.sage),
                  ),
                  title: Text(option.label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.arrow_forward_rounded, size: 18),
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
            ],
          ),
        ),
      ),
    );
    if (type != null && context.mounted) {
      _showEditor(context, state, type);
    }
  }

  void _showEditor(
    BuildContext context,
    AppState state,
    CareerItemType type, {
    CareerItem? item,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CareerItemEditor(state: state, type: type, item: item),
    );
  }

  void _confirmDelete(BuildContext context, AppState state, CareerItem item) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove this evidence?'),
        content: Text(
            '“${item.title}” will no longer be available for resume tailoring.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              state.removeCareerItem(item.id);
              Navigator.of(dialogContext).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _EvidenceSummary extends StatelessWidget {
  const _EvidenceSummary({
    required this.completion,
    required this.total,
    required this.verified,
  });

  final int completion;
  final int total;
  final int verified;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: dark ? AppColors.brightBlue : AppColors.darkBlue,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 62,
            height: 62,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: completion / 100,
                  strokeWidth: 5,
                  backgroundColor: AppColors.white.withValues(alpha: .15),
                  color: AppColors.white,
                ),
                Center(
                  child: Text(
                    '$completion%',
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Evidence readiness',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$total details · $verified verified',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.white.withValues(alpha: .72),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'AI may only use information saved here.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.white.withValues(alpha: .72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CareerItemCard extends StatelessWidget {
  const _CareerItemCard({
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  final CareerItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 17,
      onTap: onEdit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: AppColors.sageSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child:
                    Icon(_iconFor(item.type), size: 18, color: AppColors.sage),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (item.subtitle != null || item.dateRange != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        [item.subtitle, item.dateRange]
                            .whereType<String>()
                            .join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Career item actions',
                onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Remove')),
                ],
              ),
            ],
          ),
          if (item.bullets.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final bullet in item.bullets.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 7),
                      child: SizedBox(
                        width: 4,
                        height: 4,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                              color: AppColors.stone, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                        child: Text(bullet,
                            style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: item.verified
                      ? AppColors.successSubtle
                      : AppColors.warningSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  item.verified ? 'VERIFIED' : 'UNVERIFIED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .6,
                    color:
                        item.verified ? AppColors.success : AppColors.warning,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(Icons.edit_outlined, size: 15, color: AppColors.stone),
              const SizedBox(width: 4),
              Text('Tap to edit', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _CareerItemEditor extends StatefulWidget {
  const _CareerItemEditor({
    required this.state,
    required this.type,
    this.item,
  });

  final AppState state;
  final CareerItemType type;
  final CareerItem? item;

  @override
  State<_CareerItemEditor> createState() => _CareerItemEditorState();
}

class _CareerItemEditorState extends State<_CareerItemEditor> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _date;
  late final TextEditingController _bullets;
  late bool _verified;

  bool get _isSkill => widget.type == CareerItemType.skill;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item?.title ?? '');
    _subtitle = TextEditingController(text: item?.subtitle ?? '');
    _date = TextEditingController(text: item?.dateRange ?? '');
    _bullets = TextEditingController(text: item?.bullets.join('\n') ?? '');
    _verified = item?.verified ?? false;
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
        id: widget.item?.id ?? 'item-${DateTime.now().microsecondsSinceEpoch}',
        type: widget.type,
        title: _title.text.trim(),
        subtitle: _subtitle.text.trim().isEmpty ? null : _subtitle.text.trim(),
        dateRange: _date.text.trim().isEmpty ? null : _date.text.trim(),
        bullets: _bullets.text
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.isNotEmpty)
            .toList(),
        verified: _verified,
      ),
    );
    Navigator.of(context).pop();
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
            'Only add facts you are comfortable using in a resume.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          _field(
            _title,
            _isSkill ? 'Skill' : 'Title',
            _isSkill ? 'e.g. Flutter' : 'Role, degree, project, or course',
          ),
          if (!_isSkill) ...[
            _field(
              _subtitle,
              widget.type == CareerItemType.education
                  ? 'Institution'
                  : 'Organisation or context',
              'Optional',
            ),
            _field(_date, 'Date range', 'e.g. Jun 2025 — Aug 2025'),
          ],
          if (widget.type == CareerItemType.experience ||
              widget.type == CareerItemType.project) ...[
            _field(
              _bullets,
              'Outcomes',
              'One fact or achievement per line',
              maxLines: 5,
            ),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.sageSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_outlined,
                    size: 19, color: AppColors.sage),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'I can support this with real evidence',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                    value: _verified,
                    onChanged: (value) => setState(() => _verified = value)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: Text(widget.item == null
                  ? 'Add to career profile'
                  : 'Save changes'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
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
}

IconData _iconFor(CareerItemType type) => switch (type) {
      CareerItemType.education => Icons.school_outlined,
      CareerItemType.experience => Icons.work_outline_rounded,
      CareerItemType.project => Icons.rocket_launch_outlined,
      CareerItemType.skill => Icons.bolt_outlined,
      CareerItemType.course => Icons.workspace_premium_outlined,
      CareerItemType.interview => Icons.mic_outlined,
    };
