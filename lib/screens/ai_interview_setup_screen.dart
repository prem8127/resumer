import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/route_utils.dart';
import 'ai_interview_screen.dart';

/// Setup step for a mock AI interview: role, experience level, interview
/// type, and question count. Starting the interview pushes
/// [AiInterviewScreen] with the chosen configuration.
class AiInterviewSetupScreen extends StatefulWidget {
  const AiInterviewSetupScreen({super.key});

  @override
  State<AiInterviewSetupScreen> createState() =>
      _AiInterviewSetupScreenState();
}

class _AiInterviewSetupScreenState extends State<AiInterviewSetupScreen> {
  late final TextEditingController _roleController;
  String _experienceLevel = _experienceLevels.first;
  String _interviewType = _interviewTypes.first;
  int _questionCount = 10;

  static const _experienceLevels = ['Entry-level', 'Mid-level', 'Senior'];
  static const _interviewTypes = ['Behavioral', 'Technical', 'HR', 'Mixed'];
  static const _questionCounts = [5, 10, 15];

  @override
  void initState() {
    super.initState();
    _roleController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_roleController.text.isEmpty) {
      final headline = AppScope.of(context).user.headline;
      if (headline.isNotEmpty) _roleController.text = headline;
    }
  }

  @override
  void dispose() {
    _roleController.dispose();
    super.dispose();
  }

  bool get _canStart => _roleController.text.trim().isNotEmpty;

  void _startInterview() {
    if (!_canStart) return;
    pushRouteOnce(
      context,
      (_) => AiInterviewScreen(
        targetRole: _roleController.text.trim(),
        experienceLevel: _experienceLevel,
        interviewType: _interviewType,
        questionCount: _questionCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Interview')),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const SectionHeader(
              title: 'Set up your mock interview',
              subtitle:
                  'Tell the AI interviewer what to focus on, then start practicing.',
            ),
            const SizedBox(height: 22),
            Text('Target role', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            TextField(
              controller: _roleController,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'e.g. Frontend Developer',
                prefixIcon: Icon(Icons.work_outline_rounded),
              ),
            ),
            const SizedBox(height: 24),
            Text('Experience level',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _ChipRow(
              options: _experienceLevels,
              selected: _experienceLevel,
              onSelected: (value) => setState(() => _experienceLevel = value),
            ),
            const SizedBox(height: 24),
            Text('Interview type',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _ChipRow(
              options: _interviewTypes,
              selected: _interviewType,
              onSelected: (value) => setState(() => _interviewType = value),
            ),
            const SizedBox(height: 24),
            Text('Number of questions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _ChipRow(
              options: [for (final count in _questionCounts) '$count'],
              selected: '$_questionCount',
              onSelected: (value) =>
                  setState(() => _questionCount = int.parse(value)),
            ),
            const SizedBox(height: 30),
            GlassCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      size: 20, color: AppColors.sage),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Questions are generated live by Gemini for the role and '
                      'level you pick, so every run feels like a fresh interview.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _canStart ? _startInterview : null,
              icon: const Icon(Icons.mic_rounded, size: 18),
              label: const Text('Start interview'),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option),
            selected: option == selected,
            onSelected: (_) => onSelected(option),
          ),
      ],
    );
  }
}
