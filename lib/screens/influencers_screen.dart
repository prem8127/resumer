import 'package:flutter/material.dart';

import '../data/course_catalog.dart';
import '../models/influencer.dart';
import '../services/cloud_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_widgets.dart';
import '../widgets/influencer_widgets.dart';
import '../widgets/route_utils.dart';
import 'influencer_details_screen.dart';

/// "Influencers" — browse course creators and open their profile.
///
/// This is the entry point for the Influencer Details flow: tapping a card
/// pushes [InfluencerDetailsScreen]. Course/test/certificate screens are not
/// touched by this feature — course pages are reached the same way they
/// always were, and from here via a course's creator profile.
class InfluencersScreen extends StatefulWidget {
  const InfluencersScreen({super.key});

  @override
  State<InfluencersScreen> createState() => _InfluencersScreenState();
}

class _InfluencersScreenState extends State<InfluencersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final CloudDataService _cloud = CloudDataService();
  late Stream<List<Influencer>> _influencersStream;

  @override
  void initState() {
    super.initState();
    _influencersStream = _cloud.watchApprovedInfluencers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Influencer> _filtered(List<Influencer> catalog) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return catalog;
    return catalog.where((influencer) {
      return influencer.name.toLowerCase().contains(q) ||
          influencer.headline.toLowerCase().contains(q) ||
          influencer.expertise.any((e) => e.toLowerCase().contains(q));
    }).toList();
  }

  Widget _courseCountFor(Influencer influencer) => FutureBuilder(
        future: _cloud.countCoursesByOwner(influencer.id),
        builder: (context, snapshot) {
          final liveCount = snapshot.data ?? 0;
          final bundledCount = kCourseCatalog
              .where((course) => influencer.courseIds.contains(course.id))
              .length;
          return _InfluencerCard(
            influencer: influencer,
            courseCount: liveCount > 0 ? liveCount : bundledCount,
            onTap: () => _openInfluencer(influencer),
          );
        },
      );

  void _openInfluencer(Influencer influencer) {
    pushRouteOnce(
      context,
      (_) => InfluencerDetailsScreen(influencer: influencer),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Influencer>>(
      stream: _influencersStream,
      builder: (context, snapshot) {
        final influencers = _filtered(snapshot.data ?? const []);
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
            children: [
              Text('Influencers',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'Meet the instructors behind your courses.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search influencers',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'All Influencers'),
              const SizedBox(height: 10),
              if (snapshot.hasError)
                EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load influencers',
                  subtitle: 'Check your connection and try again.',
                  actionLabel: 'Retry',
                  onAction: () => setState(
                    () => _influencersStream =
                        _cloud.watchApprovedInfluencers(),
                  ),
                )
              else if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (influencers.isEmpty)
                const EmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'No influencers found',
                  subtitle:
                      'Published influencer profiles will appear here.',
                )
              else
                for (final influencer in influencers) ...[
                  _courseCountFor(influencer),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _InfluencerCard extends StatelessWidget {
  const _InfluencerCard({
    required this.influencer,
    required this.courseCount,
    required this.onTap,
  });

  final Influencer influencer;
  final int courseCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfluencerAvatar(
              name: influencer.name,
              size: 52,
              photoUrl: influencer.profilePhotoUrl),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  influencer.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  influencer.headline,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in influencer.expertise.take(3))
                      InfluencerTag(e),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.menu_book_outlined,
                        size: 15, color: AppColors.primaryBlue),
                    const SizedBox(width: 4),
                    Text(
                      '$courseCount ${courseCount == 1 ? 'course' : 'courses'}',
                      style: Theme.of(context).textTheme.bodySmall,
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
