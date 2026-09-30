import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Circular initials avatar for an influencer (no photo backend yet — same
/// approach as [CompanyAvatar]'s fallback, but sized for a person's profile).
class InfluencerAvatar extends StatelessWidget {
  const InfluencerAvatar({super.key, required this.name, this.size = 48, this.photoUrl});

  final String name;
  final double size;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurfaceSubtle : AppColors.sageSoft,
        shape: BoxShape.circle,
        border: Border.all(
          color: dark ? AppColors.darkBorder : AppColors.line,
        ),
      ),
      child: ClipOval(
        child: photoUrl == null || photoUrl!.isEmpty
            ? Text(
                initials.isEmpty ? '?' : initials,
                style: TextStyle(
                  fontSize: size * .36,
                  fontWeight: FontWeight.w700,
                  color: dark ? AppColors.violetSoft : AppColors.primaryBlue,
                ),
              )
            : Image.network(photoUrl!, width: size, height: size, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(child: Text(initials.isEmpty ? '?' : initials))),
      ),
    );
  }
}

/// Small pill used for an influencer's expertise/category tags.
class InfluencerTag extends StatelessWidget {
  const InfluencerTag(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurfaceSubtle : AppColors.sageSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: dark ? AppColors.violetSoft : AppColors.inkSoft,
        ),
      ),
    );
  }
}

/// Best-effort icon for a social/content platform name.
IconData iconForPlatform(String platform) {
  final p = platform.toLowerCase();
  if (p.contains('youtube')) return Icons.play_circle_fill_rounded;
  if (p.contains('linkedin')) return Icons.business_center_rounded;
  if (p.contains('twitter/x') || p.contains('twitter')) {
    return Icons.alternate_email_rounded;
  }
  if (p.contains('instagram')) return Icons.camera_alt_rounded;
  if (p.contains('github')) return Icons.code_rounded;
  if (p.contains('podcast')) return Icons.podcasts_rounded;
  if (p.contains('website') || p.contains('blog')) {
    return Icons.language_rounded;
  }
  return Icons.link_rounded;
}
