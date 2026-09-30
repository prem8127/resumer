import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/course_catalog.dart';
import '../models/models.dart';
import '../services/cloud_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/route_utils.dart';
import 'course_learning_screen.dart';

/// "Explore Courses" — browse the catalog and jump back into courses already
/// in progress ("My Learning").
class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key, this.onExploreMentors});

  final VoidCallback? onExploreMentors;

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _category = 'All';
  final CloudDataService _cloud = CloudDataService();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _categories(List<Course> catalog) => [
        'All',
        for (final c in {for (final course in catalog) course.category}) c,
      ];

  List<Course> _filtered(List<Course> catalog) {
    return catalog.where((course) {
      final matchesCategory =
          _category == 'All' || course.category == _category;
      final q = _query.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          course.title.toLowerCase().contains(q) ||
          course.category.toLowerCase().contains(q) ||
          course.instructor.toLowerCase().contains(q);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  void _openCourse(Course course) {
    pushRouteOnce(context, (_) => CourseLearningScreen(course: course));
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final enrolled = state.enrolledCourses;

    return StreamBuilder<List<Course>>(
      stream: _cloud.watchApprovedCourses(),
      builder: (context, snapshot) {
        final cloudCatalog = snapshot.data;
        final catalog = cloudCatalog == null || cloudCatalog.isEmpty
            ? kCourseCatalog
            : cloudCatalog;
        final categories = _categories(catalog);
        final filtered = _filtered(catalog);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
            children: [
              Text('Learn', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Courses, tests and certificates for your career profile.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: widget.onExploreMentors,
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Meet the mentors'),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search courses',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = categories[i];
                    final selected = c == _category;
                    return ChoiceChip(
                      label: Text(c),
                      selected: selected,
                      onSelected: (_) => setState(() => _category = c),
                    );
                  },
                ),
              ),
              if (enrolled.isNotEmpty) ...[
                const SizedBox(height: 22),
                const SectionHeader(title: 'My Learning'),
                const SizedBox(height: 10),
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: enrolled.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) {
                      final course = enrolled[i];
                      return SizedBox(
                        width: 220,
                        child: _MyLearningCard(
                          course: course,
                          progress: state.courseProgress(course),
                          onTap: () => _openCourse(course),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SectionHeader(
                title: _category == 'All' ? 'Popular Courses' : _category,
              ),
              const SizedBox(height: 10),
              if (filtered.isEmpty)
                const EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'No courses found',
                  subtitle: 'Try a different search or category.',
                )
              else
                for (final course in filtered) ...[
                  _CourseCard(
                    course: course,
                    enrolled: state.isEnrolled(course.id),
                    progress: state.courseProgress(course),
                    onTap: () => _openCourse(course),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.enrolled,
    required this.progress,
    required this.onTap,
  });

  final Course course;
  final bool enrolled;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.sageSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                Icon(_iconFor(course.category), color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('${course.instructor} · ${course.level}',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 15, color: AppColors.orange),
                    const SizedBox(width: 3),
                    Text('${course.rating}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 10),
                    Text(course.studentsLabel,
                        style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    Text(
                      course.isFree ? 'Free' : course.priceLabel,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryBlue),
                    ),
                  ],
                ),
                if (enrolled) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.sageSoft,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    progress >= 1
                        ? 'Completed'
                        : '${(progress * course.lessons.length).round()}/${course.lessons.length} lessons',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String category) {
    switch (category) {
      case 'Programming':
        return Icons.code_rounded;
      case 'Web Development':
        return Icons.web_rounded;
      case 'Data':
        return Icons.table_chart_outlined;
      case 'AI / ML':
        return Icons.psychology_outlined;
      case 'Cloud':
        return Icons.cloud_outlined;
      default:
        return Icons.menu_book_outlined;
    }
  }
}

class _MyLearningCard extends StatelessWidget {
  const _MyLearningCard({
    required this.course,
    required this.progress,
    required this.onTap,
  });

  final Course course;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            course.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          Text(course.category, style: Theme.of(context).textTheme.bodySmall),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.sageSoft,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                progress >= 1 ? 'Completed 🎉' : 'Continue learning',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryBlue),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
