import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/cloud_data_service.dart';
import '../services/resume_parser_service.dart';
import '../theme/app_theme.dart';
import '../widgets/resume_stepper.dart';
import 'auto_apply_screen.dart';
import 'admin_dashboard_screen.dart';
import 'login_screen.dart';

class LaunchFlow extends StatefulWidget {
  const LaunchFlow({super.key, required this.home});

  final Widget home;

  @override
  State<LaunchFlow> createState() => _LaunchFlowState();
}

class _LaunchFlowState extends State<LaunchFlow> {
  bool _showSplash = true;
  Timer? _timer;
  final CloudDataService _cloud = CloudDataService();
  String? _roleUserId;
  Future<AppRole>? _roleFuture;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 3000), () {
      if (mounted) setState(() => _showSplash = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _retryRoleCheck() {
    final userId = AuthService.instance.currentUser?.id;
    setState(() {
      _roleUserId = userId;
      _roleFuture = _cloud.currentRole();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.isAuthenticated) {
      _roleUserId = null;
      _roleFuture = null;
    } else {
      final userId = AuthService.instance.currentUser?.id;
      if (userId != null && userId != _roleUserId) {
        _roleUserId = userId;
        _roleFuture = _cloud.currentRole();
      }
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: _showSplash
          ? const _SplashScreen(key: ValueKey('splash'))
          : !state.isAuthenticated
              ? const LoginScreen(key: ValueKey('login'))
              : FutureBuilder<AppRole>(
                  future: _roleFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Scaffold(
                        key: ValueKey('role-check'),
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Scaffold(
                        key: const ValueKey('role-error'),
                        body: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Could not verify account access. Try again before continuing.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _retryRoleCheck,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    final role = snapshot.data;
                    if (role == AppRole.admin || role == AppRole.superAdmin) {
                      return const KeyedSubtree(
                        key: ValueKey('admin-home'),
                        child: AdminDashboardScreen(),
                      );
                    }
                    return state.onboardingCompleted
                        ? KeyedSubtree(
                            key: const ValueKey('home'), child: widget.home)
                        : const BasicResumeOnboarding(
                            key: ValueKey('onboarding'));
                  },
                ),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen({super.key});

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.veryLightBlue,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/splash-paper.png', fit: BoxFit.cover),
          Container(color: AppColors.white.withValues(alpha: .22)),
          SafeArea(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 700),
              opacity: _visible ? 1 : 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                offset: _visible ? Offset.zero : const Offset(0, .035),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Wordmark(),
                      const Spacer(),
                      Text(
                        'Your work,\nclearly told.',
                        style:
                            Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: AppColors.darkBlue,
                                  fontSize: 46,
                                ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'A focused resume for every opportunity.',
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.stone,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                    ],
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

class BasicResumeOnboarding extends StatefulWidget {
  const BasicResumeOnboarding({super.key});

  @override
  State<BasicResumeOnboarding> createState() => _BasicResumeOnboardingState();
}

class _BasicResumeOnboardingState extends State<BasicResumeOnboarding> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _headline = TextEditingController();
  final _degree = TextEditingController();
  final _school = TextEditingController();
  final _graduation = TextEditingController();
  final _role = TextEditingController();
  final _company = TextEditingController();
  final _experience = TextEditingController();
  final _skills = TextEditingController();
  bool _initialized = false;
  int _currentStep = 1;
  bool _isParsingResume = false;
  String? _scrapedSource;
  final ResumeParserService _parserService = const ResumeParserService();

  Future<void> _uploadAndParseResume() async {
    setState(() => _isParsingResume = true);
    try {
      final result = await _parserService.pickAndParseResume();
      if (result != null && mounted) {
        if (result.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No readable resume text was found. Try a text-based PDF or DOCX file, or paste the resume text.',
              ),
              backgroundColor: AppColors.danger,
            ),
          );
        } else {
          _applyParsedResume(result, sourceName: 'Uploaded Resume');
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Could not read file: $error. You can paste resume text directly.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isParsingResume = false);
    }
  }

  void _showPasteResumeDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Paste your resume'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paste text from your current resume or LinkedIn. All 5 steps will be extracted automatically.',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                maxLines: 8,
                decoration: const InputDecoration(
                  hintText:
                      'Paste resume text here (Contact, Education, Experience, Skills)...',
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    textController.text = _samplePastedResume;
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: const Text('Use sample resume'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final raw = textController.text.trim();
              if (raw.isEmpty) return;
              Navigator.of(dialogContext).pop();
              final result = _parserService.parseText(raw);
              _applyParsedResume(result, sourceName: 'Pasted Text');
            },
            icon: const Icon(Icons.auto_awesome_rounded, size: 17),
            label: const Text('Scrape & Fill Steps'),
          ),
        ],
      ),
    );
  }

  void _applyParsedResume(ResumeParseResult result,
      {required String sourceName}) {
    setState(() {
      if (result.name.isNotEmpty) _name.text = result.name;
      if (result.email.isNotEmpty) _email.text = result.email;
      if (result.phone.isNotEmpty) _phone.text = result.phone;
      if (result.location.isNotEmpty) _location.text = result.location;
      if (result.headline.isNotEmpty) _headline.text = result.headline;
      if (result.degree.isNotEmpty) _degree.text = result.degree;
      if (result.school.isNotEmpty) _school.text = result.school;
      if (result.graduation.isNotEmpty) _graduation.text = result.graduation;
      if (result.role.isNotEmpty) _role.text = result.role;
      if (result.company.isNotEmpty) _company.text = result.company;
      if (result.experience.isNotEmpty) _experience.text = result.experience;
      if (result.skills.isNotEmpty) _skills.text = result.skills.join(', ');
      _scrapedSource = sourceName;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✨ Scraped details from $sourceName! All 5 onboarding steps have been pre-filled for ${result.name}.',
        ),
        backgroundColor: AppColors.primaryBlue,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _clearScrapedData() {
    setState(() {
      _scrapedSource = null;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final state = AppScope.of(context);
    final user = state.user;
    _name.text = user.name;
    _email.text = user.email;
    _phone.text = user.phone;
    _location.text = user.location;
    _headline.text = user.headline;

    CareerItem? firstOf(CareerItemType type) {
      for (final item in state.careerItems) {
        if (item.type == type) return item;
      }
      return null;
    }

    final education = firstOf(CareerItemType.education);
    final experience = firstOf(CareerItemType.experience);
    _degree.text = education?.title ?? '';
    _school.text = education?.subtitle ?? '';
    _graduation.text = education?.dateRange ?? '';
    _role.text = experience?.title ?? '';
    _company.text = experience?.subtitle?.split(' · ').first ?? '';
    _experience.text = experience?.bullets.firstOrNull ?? '';
    _skills.text = state.careerItems
        .where((item) => item.type == CareerItemType.skill)
        .map((item) => item.title)
        .take(6)
        .join(', ');
    _initialized = true;
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _phone,
      _location,
      _headline,
      _degree,
      _school,
      _graduation,
      _role,
      _company,
      _experience,
      _skills,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _canContinue(int step) => switch (step) {
        1 => _name.text.trim().isNotEmpty && _email.text.trim().contains('@'),
        2 => _headline.text.trim().isNotEmpty,
        3 => _degree.text.trim().isNotEmpty && _school.text.trim().isNotEmpty,
        4 => _role.text.trim().isNotEmpty && _company.text.trim().isNotEmpty,
        _ => _skills.text.trim().isNotEmpty,
      };

  void _complete() {
    final AppState state = AppScope.of(context);
    final NavigatorState navigator = Navigator.of(context);
    state.completeOnboarding(
      name: _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      location: _location.text.trim(),
      headline: _headline.text.trim(),
      degree: _degree.text.trim(),
      school: _school.text.trim(),
      studyPeriod: _graduation.text.trim(),
      role: _role.text.trim(),
      company: _company.text.trim(),
      achievement: _experience.text.trim(),
      skills: _skills.text
          .split(',')
          .map((skill) => skill.trim())
          .where((skill) => skill.isNotEmpty)
          .toList(),
    );
    _promptAutoApply(state, navigator);
  }

  /// Asks whether AI should take over applications from now on. When enabled,
  /// the AutoApply screen tailors the master resume and applies to every open
  /// role, tagging each application as applied by AI.
  Future<void> _promptAutoApply(
    AppState state,
    NavigatorState navigator,
  ) async {
    final enable = await showDialog<bool>(
      context: navigator.context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enable AI auto-apply?'),
        content: const Text(
          'From now on, AI will automatically tailor your master resume and '
          'apply to open internships and jobs that fit your profile. '
          'Applications submitted this way are tagged “Applied by AI” in your '
          'tracker. You can switch this off anytime in Profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enable auto-apply'),
          ),
        ],
      ),
    );
    if (enable != true) return;
    state.setAutoApplyEnabled(true);
    if (!navigator.mounted) return;
    await navigator.push(
      MaterialPageRoute<void>(builder: (_) => const AutoApplyScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Wordmark(),
              const SizedBox(height: 28),
              Expanded(
                child: ResumeStepper(
                  initialStep: 1,
                  disableStepIndicators: true,
                  canContinue: _canContinue,
                  onStepChange: (step) => setState(() => _currentStep = step),
                  onFinalStepCompleted: _complete,
                  children: [
                    ResumeStep(children: [
                      const _StepHeading(
                        title: 'Let’s start with you.',
                        subtitle:
                            'The essentials that sit at the top of every resume.',
                      ),
                      _ResumeUploadCard(
                        isParsing: _isParsingResume,
                        scrapedSource: _scrapedSource,
                        onUploadFile: _uploadAndParseResume,
                        onPasteText: () => _showPasteResumeDialog(context),
                        onClear: _clearScrapedData,
                      ),
                      _field(
                          _name, 'Full name', 'How should your name appear?'),
                      _field(_email, 'Email', 'you@example.com',
                          keyboard: TextInputType.emailAddress),
                      _field(_phone, 'Phone', '+91 98765 43210',
                          keyboard: TextInputType.phone),
                      _field(_location, 'Location', 'City, country'),
                    ]),
                    ResumeStep(children: [
                      const _StepHeading(
                        title: 'Where are you headed?',
                        subtitle:
                            'A concise direction helps us shape every section around your goal.',
                      ),
                      _field(
                        _headline,
                        'Professional headline',
                        'Aspiring product engineer',
                        maxLines: 2,
                      ),
                      const _PromptNote(
                        text:
                            'Keep it specific: your level, field, and the kind of work you want.',
                      ),
                    ]),
                    ResumeStep(children: [
                      const _StepHeading(
                        title: 'Your education.',
                        subtitle:
                            'Add the qualification most relevant to your next role.',
                      ),
                      _field(_degree, 'Degree or qualification',
                          'B.Tech, Computer Science'),
                      _field(_school, 'School or university', 'IIIT Bengaluru'),
                      _field(_graduation, 'Study period', '2022 — 2026'),
                    ]),
                    ResumeStep(children: [
                      const _StepHeading(
                        title: 'Your recent experience.',
                        subtitle:
                            'Internships, part-time work, and meaningful projects all count.',
                      ),
                      _field(_role, 'Role or project',
                          'Software Development Intern'),
                      _field(_company, 'Company or organisation', 'StartupHub'),
                      _field(
                        _experience,
                        'One strong achievement',
                        'What did you build, improve, or make possible?',
                        maxLines: 3,
                      ),
                    ]),
                    ResumeStep(children: [
                      const _StepHeading(
                        title: 'Finish with your strengths.',
                        subtitle:
                            'List the skills you can support with real work or projects.',
                      ),
                      _field(
                        _skills,
                        'Skills',
                        'Flutter, React, SQL, Figma',
                        maxLines: 3,
                      ),
                      const _PromptNote(
                        text:
                            'Use commas between skills. You can refine everything later in your profile.',
                      ),
                      const SizedBox(height: 18),
                      _ReadySummary(name: _name, headline: _headline),
                    ]),
                  ],
                ),
              ),
              if (!_canContinue(_currentStep))
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Complete the required fields to continue.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, {
    TextInputType? keyboard,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: maxLines,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 31,
          height: 31,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Text(
            'R',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        const SizedBox(width: 10),
        const Flexible(
          child: Text(
            'Resumer',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepHeading extends StatelessWidget {
  const _StepHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 9),
          Text(subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.stone)),
        ],
      ),
    );
  }
}

class _PromptNote extends StatelessWidget {
  const _PromptNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sageSoft,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded,
              size: 18, color: AppColors.sage),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}

class _ReadySummary extends StatelessWidget {
  const _ReadySummary({required this.name, required this.headline});

  final TextEditingController name;
  final TextEditingController headline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.paper,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR BASIC RESUME',
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(letterSpacing: 1.2)),
          const SizedBox(height: 12),
          Text(name.text, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 3),
          Text(headline.text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ResumeUploadCard extends StatelessWidget {
  const _ResumeUploadCard({
    required this.isParsing,
    required this.scrapedSource,
    required this.onUploadFile,
    required this.onPasteText,
    required this.onClear,
  });

  final bool isParsing;
  final String? scrapedSource;
  final VoidCallback onUploadFile;
  final VoidCallback onPasteText;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isDone = scrapedSource != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDone
            ? (dark ? AppColors.darkSurfaceSubtle : AppColors.sageSoft)
            : (dark ? AppColors.darkSurfaceSubtle : AppColors.veryLightBlue),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDone
              ? AppColors.sage
              : (dark ? AppColors.darkBorderStrong : AppColors.line),
          width: isDone ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.success.withValues(alpha: 0.15)
                      : AppColors.sageSoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isDone
                      ? Icons.check_circle_rounded
                      : Icons.auto_awesome_rounded,
                  size: 20,
                  color: isDone ? AppColors.success : AppColors.sage,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDone
                          ? 'Resume Scraped & Pre-filled'
                          : 'Have an existing resume?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isDone
                          ? 'Source: $scrapedSource · Review & adjust any step'
                          : 'Upload PDF or paste text to auto-fill all 5 steps in seconds',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDone
                                ? AppColors.success
                                : (dark
                                    ? AppColors.darkMuted
                                    : AppColors.stone),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isParsing) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Scraping and extracting resume sections...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ],
            ),
          ] else if (!isDone) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onUploadFile,
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: const Text('Upload PDF/DOCX'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onPasteText,
                    icon: const Icon(Icons.paste_rounded, size: 16),
                    label: const Text('Paste Text'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onUploadFile,
                  icon: const Icon(Icons.refresh_rounded, size: 15),
                  label: const Text('Upload different resume'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

const String _samplePastedResume = '''
Priya Sharma
Bengaluru, India | +91 98765 43210 | priya.sharma@example.com

PROFESSIONAL SUMMARY
Aspiring Product Engineer passionate about building scalable mobile and web applications with Flutter, React, and Python.

EDUCATION
B.Tech, Computer Science and Engineering
IIIT Bengaluru
2022 — 2026

EXPERIENCE
Software Development Intern | StartupHub
• Built high-performance Flutter dashboard connecting to REST APIs, improving user efficiency by 35%.
• Automated deployment and test pipelines with GitHub Actions and Docker.

SKILLS
Flutter, Dart, React, Python, PostgreSQL, REST API, Git, Figma, Docker
''';
