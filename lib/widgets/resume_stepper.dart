import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A Flutter adaptation of the React Bits Stepper interaction.
///
/// It keeps the same ideas—numbered indicators, animated connectors,
/// directional step transitions, Back/Continue actions, and a completion
/// callback—without adding a web-only dependency to the Flutter project.
class ResumeStepper extends StatefulWidget {
  const ResumeStepper({
    super.key,
    required this.children,
    this.initialStep = 1,
    this.onStepChange,
    this.onFinalStepCompleted,
    this.canContinue,
    this.backButtonText = 'Back',
    this.nextButtonText = 'Continue',
    this.completeButtonText = 'Build my resume',
    this.disableStepIndicators = false,
  });

  final List<Widget> children;
  final int initialStep;
  final ValueChanged<int>? onStepChange;
  final VoidCallback? onFinalStepCompleted;
  final bool Function(int step)? canContinue;
  final String backButtonText;
  final String nextButtonText;
  final String completeButtonText;
  final bool disableStepIndicators;

  @override
  State<ResumeStepper> createState() => _ResumeStepperState();
}

class _ResumeStepperState extends State<ResumeStepper> {
  late int _step;
  int _direction = 1;

  @override
  void initState() {
    super.initState();
    _step = widget.initialStep.clamp(1, widget.children.length);
  }

  void _goTo(int next) {
    if (next == _step || next < 1 || next > widget.children.length) return;
    setState(() {
      _direction = next > _step ? 1 : -1;
      _step = next;
    });
    widget.onStepChange?.call(next);
  }

  void _continue() {
    if (!(widget.canContinue?.call(_step) ?? true)) return;
    if (_step == widget.children.length) {
      widget.onFinalStepCompleted?.call();
      return;
    }
    _goTo(_step + 1);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = dark ? AppColors.brightBlue : AppColors.primaryBlue;
    final line = dark ? AppColors.darkBorderStrong : AppColors.line;
    final canContinue = widget.canContinue?.call(_step) ?? true;

    return Column(
      children: [
        Row(
          children: [
            for (var index = 0; index < widget.children.length; index++) ...[
              _StepDot(
                number: index + 1,
                currentStep: _step,
                activeColor: active,
                onTap: widget.disableStepIndicators
                    ? null
                    : () => _goTo(index + 1),
              ),
              if (index < widget.children.length - 1)
                Expanded(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: line,
                    alignment: Alignment.centerLeft,
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      widthFactor: _step > index + 1 ? 1 : 0,
                      child: Container(color: active),
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'STEP $_step OF ${widget.children.length}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  letterSpacing: 1.2,
                  color: dark ? AppColors.darkMuted : AppColors.stone,
                ),
          ),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: ClipRect(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 380),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                final offset = Tween<Offset>(
                  begin: Offset(_direction > 0 ? .16 : -.16, 0),
                  end: Offset.zero,
                ).animate(animation);
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(position: offset, child: child),
                );
              },
              child: KeyedSubtree(
                key: ValueKey(_step),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: widget.children[_step - 1],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (_step > 1)
              TextButton.icon(
                onPressed: () => _goTo(_step - 1),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(widget.backButtonText),
              )
            else
              const SizedBox.shrink(),
            const Spacer(),
            FilledButton.icon(
              onPressed: canContinue ? _continue : null,
              iconAlignment: IconAlignment.end,
              icon: Icon(
                _step == widget.children.length
                    ? Icons.check_rounded
                    : Icons.arrow_forward_rounded,
                size: 18,
              ),
              label: Text(
                _step == widget.children.length
                    ? widget.completeButtonText
                    : widget.nextButtonText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ResumeStep extends StatelessWidget {
  const ResumeStep({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.number,
    required this.currentStep,
    required this.activeColor,
    this.onTap,
  });

  final int number;
  final int currentStep;
  final Color activeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final complete = currentStep > number;
    final active = currentStep == number;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      label: 'Step $number',
      selected: active,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          width: 31,
          height: 31,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active || complete
                ? activeColor
                : (dark ? AppColors.darkSurfaceSubtle : AppColors.paper),
            border: Border.all(
              color: active || complete
                  ? activeColor
                  : (dark ? AppColors.darkBorderStrong : AppColors.line),
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: complete
                ? Icon(
                    Icons.check_rounded,
                    key: const ValueKey('complete'),
                    size: 16,
                    color: dark ? AppColors.ink : Colors.white,
                  )
                : active
                    ? Container(
                        key: const ValueKey('active'),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: dark ? AppColors.ink : Colors.white,
                          shape: BoxShape.circle,
                        ),
                      )
                    : Text(
                        '$number',
                        key: const ValueKey('number'),
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
          ),
        ),
      ),
    );
  }
}
