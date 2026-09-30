import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../services/ai_learning_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/route_utils.dart';
import 'certificate_screen.dart';

/// "Tests & Final Exam" — a short multiple-choice quiz gating the
/// certificate. Pass mark is 60%.
class CourseTestScreen extends StatefulWidget {
  const CourseTestScreen(
      {super.key, required this.course, this.practice = false});

  final Course course;
  final bool practice;

  @override
  State<CourseTestScreen> createState() => _CourseTestScreenState();
}

class _CourseTestScreenState extends State<CourseTestScreen> {
  int _questionIndex = 0;
  int? _selectedOption;
  final List<int> _answers = [];
  bool _submitted = false;
  bool _submitting = false;

  List<CourseTestQuestion> get _questions => widget.course.finalTest;

  void _selectOption(int index) {
    setState(() => _selectedOption = index);
  }

  void _next() {
    _answers.add(_selectedOption ?? -1);
    if (_questionIndex + 1 < _questions.length) {
      setState(() {
        _questionIndex++;
        _selectedOption = null;
      });
    } else {
      unawaited(_finish());
    }
  }

  Future<void> _finish() async {
    final correct = [
      for (var i = 0; i < _questions.length; i++)
        if (_answers[i] == _questions[i].correctIndex) 1
    ].length;
    final state = AppScope.of(context);
    final incorrectTopics = [
      for (var i = 0; i < _questions.length; i++)
        if (_answers[i] != _questions[i].correctIndex &&
            _questions[i].topic.isNotEmpty)
          _questions[i].topic,
    ];
    if (!widget.practice && widget.course.ownerId != null) {
      setState(() => _submitting = true);
      try {
        final result = await AiLearningService().gradeFinalTest(
          courseId: widget.course.id,
          answers: _answers,
        );
        if (!mounted) return;
        state.recordVerifiedTestResult(
          course: widget.course,
          scorePercent: result['score'] as int,
          incorrectTopics:
              List<String>.from(result['weakTopics'] as List? ?? []),
          certificateId: result['certificateId'] as String?,
          certificateIssuedAt: result['issuedAt'] is String
              ? DateTime.tryParse(result['issuedAt'] as String)
              : null,
        );
      } on Object catch (error) {
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit the final test: $error')),
        );
        return;
      }
    } else {
      state.recordTestResult(
        course: widget.course,
        correctCount: correct,
        incorrectTopics: incorrectTopics,
        issueCertificate: !widget.practice,
      );
    }
    if (mounted) setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) {
      return Scaffold(
        appBar:
            AppBar(title: Text(widget.practice ? 'AI Practice' : 'Final Exam')),
        body: const EmptyState(
          icon: Icons.quiz_outlined,
          title: 'No exam available',
          subtitle: 'This course does not have a final exam yet.',
        ),
      );
    }

    if (_submitted) {
      final state = AppScope.of(context);
      final enrollment = state.enrollmentFor(widget.course.id);
      final score = enrollment?.testScore ?? 0;
      final passed = enrollment?.testPassed ?? false;
      return Scaffold(
        appBar:
            AppBar(title: Text(widget.practice ? 'AI Practice' : 'Final Exam')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  passed
                      ? Icons.emoji_events_rounded
                      : Icons.sentiment_dissatisfied_rounded,
                  size: 56,
                  color: passed ? AppColors.orange : AppColors.secondaryText,
                ),
                const SizedBox(height: 16),
                Text(
                  widget.practice
                      ? 'Practice complete'
                      : passed
                          ? 'You passed!'
                          : 'Not quite there',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  'Your score: $score%',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.practice
                      ? 'Review the topics you missed and try another practice set.'
                      : passed
                          ? 'Certificate unlocked — added to your career profile.'
                          : 'You need 60% to pass. Review the lessons and try again.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                if (passed && !widget.practice)
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      pushRouteOnce(
                        context,
                        (_) => CertificateScreen(course: widget.course),
                      );
                    },
                    icon: const Icon(Icons.workspace_premium_rounded),
                    label: const Text('View certificate'),
                  )
                else
                  OutlinedButton(
                    onPressed: () => setState(() {
                      _questionIndex = 0;
                      _selectedOption = null;
                      _answers.clear();
                      _submitted = false;
                    }),
                    child: const Text('Retake exam'),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final question = _questions[_questionIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_questionIndex + 1}/${_questions.length}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (_questionIndex) / _questions.length,
                minHeight: 6,
                backgroundColor: AppColors.sageSoft,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Text(
                  question.question,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < question.options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OptionTile(
                      label: question.options[i],
                      selected: _selectedOption == i,
                      onTap: () => _selectOption(i),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _selectedOption == null || _submitting ? null : _next,
                  child: _submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _questionIndex + 1 == _questions.length
                              ? 'Submit'
                              : 'Next question',
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.sageSoft : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : AppColors.line,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              size: 20,
              color: selected ? AppColors.primaryBlue : AppColors.secondaryText,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    );
  }
}
