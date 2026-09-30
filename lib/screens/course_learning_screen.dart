import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_state.dart';
import '../models/models.dart';
import '../services/ai_learning_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/route_utils.dart';
import 'certificate_screen.dart';
import 'course_test_screen.dart';

/// "Course Learning" — lesson list + reader with Overview / Notes tabs,
/// matching the product flow's Course Learning step. Enrolls automatically
/// on open and tracks per-lesson completion locally.
class CourseLearningScreen extends StatefulWidget {
  const CourseLearningScreen({super.key, required this.course});

  final Course course;

  @override
  State<CourseLearningScreen> createState() => _CourseLearningScreenState();
}

class _CourseLearningScreenState extends State<CourseLearningScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late CourseLesson _selectedLesson;
  bool _generatingPractice = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedLesson = widget.course.lessons.isEmpty
        ? const CourseLesson(
            id: '',
            title: 'No lessons',
            durationLabel: '',
            content: 'This course does not have lessons yet.',
          )
        : widget.course.lessons.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = AppScope.of(context);
      state.enrollInCourse(widget.course);
      if (widget.course.lessons.isEmpty) return;
      final enrollment = state.enrollmentFor(widget.course.id);
      final lastId = enrollment?.lastLessonId;
      setState(() {
        _selectedLesson = widget.course.lessons.firstWhere(
          (l) => l.id == lastId,
          orElse: () => widget.course.lessons.first,
        );
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _selectLesson(CourseLesson lesson) {
    setState(() => _selectedLesson = lesson);
  }

  void _markComplete() {
    final state = AppScope.of(context);
    state.markLessonComplete(widget.course.id, _selectedLesson.id);
    final lessons = widget.course.lessons;
    final index = lessons.indexWhere((l) => l.id == _selectedLesson.id);
    if (index != -1 && index + 1 < lessons.length) {
      setState(() => _selectedLesson = lessons[index + 1]);
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.course.lessons.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.course.title)),
        body: const EmptyState(
          icon: Icons.menu_book_outlined,
          title: 'Course coming soon',
          subtitle: 'Lessons are still being prepared.',
        ),
      );
    }
    final state = AppScope.of(context);
    final course = widget.course;
    final enrollment = state.enrollmentFor(course.id);
    final completedIds = enrollment?.completedLessonIds ?? const [];
    final progress = state.courseProgress(course);
    final isSelectedComplete = completedIds.contains(_selectedLesson.id);
    final allComplete = progress >= 1.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(course.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Generate AI practice questions',
            onPressed: _generatingPractice ? null : _generatePractice,
            icon: _generatingPractice
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 7,
                    backgroundColor: AppColors.sageSoft,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  allComplete
                      ? 'All lessons completed 🎉'
                      : '${completedIds.length}/${course.lessons.length} lessons completed',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: _LessonChips(
              lessons: course.lessons,
              completedIds: completedIds,
              selected: _selectedLesson,
              onSelect: _selectLesson,
            ),
          ),
          const Divider(height: 24),
          TabBar(
            controller: _tabController,
            tabs: const [Tab(text: 'Overview'), Tab(text: 'Notes')],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(lesson: _selectedLesson),
                _NotesTab(lesson: _selectedLesson),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
              child: SizedBox(
                width: double.infinity,
                child: _buildBottomAction(
                  context,
                  isSelectedComplete: isSelectedComplete,
                  allComplete: allComplete,
                  enrollment: enrollment,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePractice() async {
    setState(() => _generatingPractice = true);
    try {
      final state = AppScope.of(context);
      final enrollment = state.enrollmentFor(widget.course.id);
      final questions = await AiLearningService().generateQuestions(
        courseTitle: widget.course.title,
        topic: _selectedLesson.title,
        context:
            '${_selectedLesson.content}\n${_selectedLesson.keyPoints.join('\n')}',
        weakTopics: enrollment?.weakTopics ?? const [],
        count: 5,
      );
      if (!mounted) return;
      if (questions.isEmpty)
        throw StateError('No practice questions were returned.');
      final practiceCourse = Course(
        id: widget.course.id,
        title: widget.course.title,
        category: widget.course.category,
        instructor: widget.course.instructor,
        level: widget.course.level,
        priceLabel: widget.course.priceLabel,
        rating: widget.course.rating,
        studentsLabel: widget.course.studentsLabel,
        description: widget.course.description,
        lessons: widget.course.lessons,
        finalTest: questions,
        isFree: widget.course.isFree,
        status: widget.course.status,
        ownerId: widget.course.ownerId,
        moduleNames: widget.course.moduleNames,
      );
      pushRouteOnce(context,
          (_) => CourseTestScreen(course: practiceCourse, practice: true));
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Could not generate practice questions: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPractice = false);
    }
  }

  Widget _buildBottomAction(
    BuildContext context, {
    required bool isSelectedComplete,
    required bool allComplete,
    required CourseEnrollment? enrollment,
  }) {
    final course = widget.course;
    if (!allComplete) {
      return FilledButton.icon(
        onPressed: isSelectedComplete ? null : _markComplete,
        icon: Icon(isSelectedComplete
            ? Icons.check_circle_rounded
            : Icons.check_rounded),
        label: Text(isSelectedComplete
            ? 'Lesson completed'
            : 'Mark complete & continue'),
      );
    }
    if (course.finalTest.isEmpty) {
      return const FilledButton(
        onPressed: null,
        child: Text('All lessons completed'),
      );
    }
    if (enrollment?.hasCertificate ?? false) {
      return FilledButton.icon(
        onPressed: () =>
            pushRouteOnce(context, (_) => CertificateScreen(course: course)),
        icon: const Icon(Icons.workspace_premium_rounded),
        label: const Text('View certificate'),
      );
    }
    return FilledButton.icon(
      onPressed: () =>
          pushRouteOnce(context, (_) => CourseTestScreen(course: course)),
      icon: const Icon(Icons.quiz_rounded),
      label: const Text('Take final exam'),
    );
  }
}

class _LessonChips extends StatelessWidget {
  const _LessonChips({
    required this.lessons,
    required this.completedIds,
    required this.selected,
    required this.onSelect,
  });

  final List<CourseLesson> lessons;
  final List<String> completedIds;
  final CourseLesson selected;
  final ValueChanged<CourseLesson> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: lessons.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final lesson = lessons[i];
          final done = completedIds.contains(lesson.id);
          final isSelected = lesson.id == selected.id;
          return InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelect(lesson),
            child: Container(
              width: 130,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryBlue : AppColors.sageSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Icon(
                        done
                            ? Icons.check_circle_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 15,
                        color: isSelected
                            ? AppColors.white
                            : AppColors.primaryBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lesson.moduleName.isEmpty
                            ? 'Lesson ${i + 1}'
                            : '${lesson.moduleName} · ${i + 1}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? AppColors.white
                              : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lesson.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.white : AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.lesson});

  final CourseLesson lesson;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(lesson.title,
                  style: Theme.of(context).textTheme.titleLarge),
            ),
            Text(lesson.durationLabel,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 14),
        if (lesson.videoUrl != null && lesson.videoUrl!.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(lesson.videoUrl!);
                if (uri != null)
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Open lesson video'),
            ),
          ),
        for (final resource in lesson.resources)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(resource['title'] ?? 'Course resource'),
            onTap: () async {
              final uri = Uri.tryParse(resource['url'] ?? '');
              if (uri != null)
                await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        Text(lesson.content, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _NotesTab extends StatelessWidget {
  const _NotesTab({required this.lesson});

  final CourseLesson lesson;

  @override
  Widget build(BuildContext context) {
    if (lesson.keyPoints.isEmpty) {
      return const EmptyState(
        icon: Icons.sticky_note_2_outlined,
        title: 'No notes yet',
        subtitle: 'Key takeaways for this lesson will show up here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 120),
      children: [
        for (final point in lesson.keyPoints)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child:
                      Icon(Icons.circle, size: 6, color: AppColors.primaryBlue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(point,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
