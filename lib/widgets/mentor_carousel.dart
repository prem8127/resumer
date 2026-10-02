import 'package:flutter/material.dart';

import '../data/influencer_catalog.dart';
import '../models/influencer.dart';
import '../services/cloud_data_service.dart';
import '../widgets/influencer_widgets.dart';
import '../widgets/route_utils.dart';
import '../screens/influencer_details_screen.dart';

/// Compact, circular mentor directory used from Career and Learn.
class MentorCarousel extends StatefulWidget {
  const MentorCarousel({super.key});

  @override
  State<MentorCarousel> createState() => _MentorCarouselState();
}

class _MentorCarouselState extends State<MentorCarousel> {
  final CloudDataService _cloud = CloudDataService();
  late final Stream<List<Influencer>> _stream;

  @override
  void initState() {
    super.initState();
    _stream = _cloud.watchApprovedInfluencers();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<Influencer>>(
        stream: _stream,
        builder: (context, snapshot) {
          final mentors = snapshot.hasData && snapshot.data!.isNotEmpty
              ? snapshot.data!
              : kInfluencerCatalog;
          if (mentors.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Meet the Real Mentors',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: mentors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final mentor = mentors[index];
                    return SizedBox(
                      width: 68,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(36),
                        onTap: () => pushRouteOnce(
                          context,
                          (_) => InfluencerDetailsScreen(influencer: mentor),
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary,
                                  width: 2,
                                ),
                              ),
                              child: InfluencerAvatar(
                                name: mentor.name,
                                size: 52,
                                photoUrl: mentor.profilePhotoUrl,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              mentor.name.split(' ').first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
}
