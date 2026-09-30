import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/course_catalog.dart';
import '../models/influencer.dart';
import '../models/models.dart';
import '../services/cloud_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/influencer_widgets.dart';
import '../widgets/route_utils.dart';
import 'course_learning_screen.dart';

/// "Influencer Details" — profile, bio, expertise, social links, content and
/// the courses this influencer has created.
///
/// Read-only with respect to courses: tapping a course here opens the
/// existing [CourseLearningScreen] unchanged — this screen never edits
/// course, test or certificate data or UI.
class InfluencerDetailsScreen extends StatelessWidget {
  const InfluencerDetailsScreen({super.key, required this.influencer});

  final Influencer influencer;
  static final CloudDataService _cloud = CloudDataService();

  List<Course> get _courses => kCourseCatalog
      .where((course) => influencer.courseIds.contains(course.id))
      .toList();

  Widget _contentSection(BuildContext context) =>
      StreamBuilder<List<InfluencerContent>>(
        stream: _cloud.watchApprovedContentByOwner(influencer.id),
        builder: (context, snapshot) {
          final items = <InfluencerContent>[
            ...influencer.content,
            ...?snapshot.data,
          ];
          final unique = <String, InfluencerContent>{
            for (final item in items) '${item.title}|${item.url}': item,
          }.values.toList();
          if (unique.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 22),
              const SectionHeader(title: 'Videos & Content'),
              const SizedBox(height: 10),
              SizedBox(
                height: 132,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: unique.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) => SizedBox(
                    width: 190,
                    child: _ContentCard(
                      content: unique[index],
                      onTap: unique[index].url == null
                          ? null
                          : () => _openLink(context, unique[index].url!),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    bool launched = false;
    if (uri != null) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } on Object {
        launched = false;
      }
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  void _openCourse(BuildContext context, Course course) {
    pushRouteOnce(context, (_) => CourseLearningScreen(course: course));
  }

  @override
  Widget build(BuildContext context) {
    final bundledCourses = _courses;

    return StreamBuilder<List<Course>>(
      stream: _cloud.watchPublishedCoursesByOwner(influencer.id),
      builder: (context, snapshot) {
        final byId = {for (final course in bundledCourses) course.id: course};
        for (final course in snapshot.data ?? const <Course>[]) {
          byId[course.id] = course;
        }
        final courses = byId.values.toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(influencer.name, overflow: TextOverflow.ellipsis),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
              children: [
                Center(
                  child: Column(
                    children: [
                      InfluencerAvatar(
                          name: influencer.name,
                          size: 84,
                          photoUrl: influencer.profilePhotoUrl),
                      const SizedBox(height: 14),
                      Text(
                        influencer.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        influencer.headline,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: MetricTile(
                        value: '${courses.length}',
                        label: courses.length == 1 ? 'Course' : 'Courses',
                        icon: Icons.menu_book_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricTile(
                        value: '${influencer.content.length}',
                        label: 'Videos',
                        icon: Icons.play_circle_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MetricTile(
                        value: '${influencer.socialLinks.length}',
                        label: 'Socials',
                        icon: Icons.link_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                SectionHeader(title: 'About'),
                const SizedBox(height: 10),
                GlassCard(
                  child: Text(
                    influencer.bio,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                if (influencer.expertise.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  SectionHeader(title: 'Expertise'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in influencer.expertise) InfluencerTag(e),
                    ],
                  ),
                ],
                if (influencer.socialLinks.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  SectionHeader(title: 'Social Links'),
                  const SizedBox(height: 10),
                  for (final link in influencer.socialLinks) ...[
                    _SocialLinkTile(
                      link: link,
                      onTap: () => _openLink(context, link.url),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
                _contentSection(context),
                const SizedBox(height: 22),
                SectionHeader(
                  title: courses.isEmpty
                      ? 'Courses'
                      : 'Courses by ${influencer.name}',
                ),
                const SizedBox(height: 10),
                if (courses.isEmpty)
                  const EmptyState(
                    icon: Icons.menu_book_outlined,
                    title: 'No courses yet',
                    subtitle: "This influencer hasn't published a course yet.",
                  )
                else
                  for (final course in courses) ...[
                    _InfluencerCourseCard(
                      course: course,
                      onTap: () => _openCourse(context, course),
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SocialLinkTile extends StatelessWidget {
  const _SocialLinkTile({required this.link, required this.onTap});

  final SocialLink link;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.sageSoft,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(iconForPlatform(link.platform),
                size: 18, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.platform,
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(link.handle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.open_in_new_rounded,
              size: 17, color: AppColors.stone),
        ],
      ),
    );
  }
}

class _ContentCard extends StatelessWidget {
  const _ContentCard({required this.content, this.onTap});

  final InfluencerContent content;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.sageSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconForPlatform(content.platform),
                size: 18, color: AppColors.primaryBlue),
          ),
          const SizedBox(height: 10),
          Text(
            content.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text('${content.platform} · ${content.durationLabel}',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _InfluencerCourseCard extends StatelessWidget {
  const _InfluencerCourseCard({required this.course, required this.onTap});

  final Course course;
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
            child: const Icon(Icons.menu_book_outlined,
                color: AppColors.primaryBlue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text('${course.category} · ${course.level}',
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
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.stone),
        ],
      ),
    );
  }
}
