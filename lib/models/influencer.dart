/// Influencer / course-creator domain models for the Learn module.
///
/// Pure Dart creator model shared by the bundled starter catalog and Supabase.
library;

/// A single social / external profile link shown on an influencer's profile.
class SocialLink {
  const SocialLink({
    required this.platform,
    required this.handle,
    required this.url,
  });

  /// e.g. 'YouTube', 'LinkedIn', 'Twitter/X', 'Instagram', 'GitHub', 'Website'.
  final String platform;

  /// Display handle, e.g. '@johndoecodes'.
  final String handle;

  final String url;

  Map<String, dynamic> toMap() => {
        'platform': platform,
        'handle': handle,
        'url': url,
      };

  static SocialLink fromMap(Map<String, dynamic> map) => SocialLink(
        platform: map['platform'] as String? ?? '',
        handle: map['handle'] as String? ?? '',
        url: map['url'] as String? ?? '',
      );
}

/// A single piece of video/content authored by an influencer, shown on
/// A video or other creator content item displayed on a profile.
class InfluencerContent {
  const InfluencerContent({
    required this.title,
    required this.platform,
    required this.durationLabel,
    this.url,
  });

  final String title;

  /// e.g. 'YouTube', 'Podcast'.
  final String platform;

  /// e.g. '12 min' — shown next to the content in the list.
  final String durationLabel;

  /// Optional deep link to the content itself.
  final String? url;

  Map<String, dynamic> toMap() => {
        'title': title,
        'platform': platform,
        'durationLabel': durationLabel,
        if (url != null) 'url': url,
      };

  static InfluencerContent fromMap(Map<String, dynamic> map) =>
      InfluencerContent(
        title: map['title'] as String? ?? '',
        platform: map['platform'] as String? ?? '',
        durationLabel: map['durationLabel'] as String? ?? '',
        url: map['url'] as String?,
      );
}

/// A course creator shown on the Influencers tab and stored in Supabase.
class Influencer {
  const Influencer({
    required this.id,
    required this.name,
    required this.headline,
    required this.bio,
    required this.expertise,
    required this.socialLinks,
    required this.content,
    required this.courseIds,
    this.ownerId,
    this.profilePhotoUrl,
    this.coverPhotoUrl,
    this.verified = false,
    this.status = 'approved',
  });

  final String id;
  final String name;

  /// Short one-line role/title, e.g. 'Software Engineer & Python Educator'.
  final String headline;

  final String bio;

  /// Categories / topics this influencer is known for.
  final List<String> expertise;

  final List<SocialLink> socialLinks;

  /// Videos / other content published by this influencer.
  final List<InfluencerContent> content;

  /// Optional bundled course IDs retained for the starter catalog migration.
  final List<String> courseIds;
  final String? ownerId;
  final String? profilePhotoUrl;
  final String? coverPhotoUrl;
  final bool verified;
  final String status;

  Map<String, dynamic> toMap() => {
        'name': name,
        'headline': headline,
        'bio': bio,
        'expertise': expertise,
        'socialLinks': socialLinks.map((link) => link.toMap()).toList(),
        'content': content.map((item) => item.toMap()).toList(),
        'courseIds': courseIds,
        if (ownerId != null) 'ownerId': ownerId,
        if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
        if (coverPhotoUrl != null) 'coverPhotoUrl': coverPhotoUrl,
        'verified': verified,
        'status': status,
      };

  static Influencer fromMap(String id, Map<String, dynamic> map) => Influencer(
        id: id,
        name: map['name'] as String? ?? '',
        headline: map['headline'] as String? ?? '',
        bio: map['bio'] as String? ?? '',
        expertise: List<String>.from(map['expertise'] as List? ?? const []),
        socialLinks: [
          for (final link in map['socialLinks'] as List? ?? const [])
            if (link is Map<String, dynamic>) SocialLink.fromMap(link),
        ],
        content: [
          for (final item in map['content'] as List? ?? const [])
            if (item is Map<String, dynamic>) InfluencerContent.fromMap(item),
        ],
        courseIds: List<String>.from(map['courseIds'] as List? ?? const []),
        ownerId: map['ownerId'] as String?,
        profilePhotoUrl: map['profilePhotoUrl'] as String?,
        coverPhotoUrl: map['coverPhotoUrl'] as String?,
        verified: map['verified'] as bool? ?? false,
        status: map['status'] as String? ?? 'draft',
      );

  String get initials => name
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0])
      .take(2)
      .join()
      .toUpperCase();
}
