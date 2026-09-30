import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

String formatDaysAgo(DateTime date) {
  final diff = DateTime.now().difference(date).inDays;
  if (diff <= 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '$diff days ago';
}

String formatShortDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}';
}

String todayLine() {
  const weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final now = DateTime.now();
  return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
}

/// Kept for API compatibility; now uses quiet ink instead of a rainbow fill.
class PrismText extends StatelessWidget {
  const PrismText(this.data, {super.key, this.style, this.colors});

  final String data;
  final TextStyle? style;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: (style ?? const TextStyle(fontSize: 16)).copyWith(
        color: colors?.first ?? Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

class SignalKicker extends StatelessWidget {
  const SignalKicker(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurfaceSubtle : AppColors.sageSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: dark ? AppColors.violetSoft : AppColors.sage,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: dark ? AppColors.violetSoft : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 20,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(borderRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? (dark ? AppColors.darkSurface : AppColors.paper),
        borderRadius: radius,
        border: Border.all(color: dark ? AppColors.darkBorder : AppColors.line),
        boxShadow: dark
            ? null
            : [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: .055),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
    this.subtitle,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 34),
            ),
            child: Text(action!),
          ),
      ],
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});

  final ApplicationStatus status;

  static (Color, Color) _colors(ApplicationStatus status) => switch (status) {
        ApplicationStatus.rejected => (
            AppColors.dangerSubtle,
            AppColors.danger
          ),
        ApplicationStatus.offer => (AppColors.successSubtle, AppColors.success),
        ApplicationStatus.interview => (
            AppColors.warningSubtle,
            AppColors.warning
          ),
        _ => (AppColors.infoSubtle, AppColors.info),
      };

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = _colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
          color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration:
                BoxDecoration(color: foreground, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            status.label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: foreground),
          ),
        ],
      ),
    );
  }
}

class ResumeTypeBadge extends StatelessWidget {
  const ResumeTypeBadge({super.key, required this.type});

  final ResumeType type;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurfaceSubtle : AppColors.sageSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: dark ? AppColors.violetSoft : AppColors.sage,
        ),
      ),
    );
  }
}

/// Marks an application that was submitted automatically by AI auto-apply.
class AppliedByAiBadge extends StatelessWidget {
  const AppliedByAiBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 11, color: AppColors.violet),
          SizedBox(width: 5),
          Text(
            'Applied by AI',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.violet,
            ),
          ),
        ],
      ),
    );
  }
}

class MatchRing extends StatelessWidget {
  const MatchRing(
      {super.key, required this.score, this.size = 46, this.stroke = 4.5});

  final int score;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: score / 100,
          stroke: stroke,
          trackColor: dark ? AppColors.darkBorderStrong : AppColors.line,
          valueColor: dark ? AppColors.violetSoft : AppColors.sage,
        ),
        child: Center(
          child: Text(
            score > 0 ? '$score' : '—',
            style: TextStyle(
              fontSize: size * .31,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.stroke,
    required this.trackColor,
    required this.valueColor,
  });

  final double progress;
  final double stroke;
  final Color trackColor;
  final Color valueColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawCircle(
      rect.center,
      size.width / 2 - stroke / 2,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect.deflate(stroke / 2),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      Paint()
        ..color = valueColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.stroke != stroke;
}

class SkillBar extends StatelessWidget {
  const SkillBar({
    super.key,
    required this.label,
    required this.status,
    required this.value,
  });

  final String label;
  final String status;
  final double value;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = status == 'missing'
        ? AppColors.danger
        : status == 'partial'
            ? AppColors.warning
            : (dark ? AppColors.violetSoft : AppColors.sage);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.labelLarge),
            ),
            Text(
              status[0].toUpperCase() + status.substring(1),
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) => LinearProgressIndicator(
              value: animatedValue.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: dark ? AppColors.darkBorder : AppColors.line,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.note,
  });

  final String value;
  final String label;
  final IconData icon;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface),
          const SizedBox(height: 12),
          Text(value,
              style:
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          if (note != null) ...[
            const SizedBox(height: 2),
            Text(note!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class CompanyLogoBanner extends StatelessWidget {
  const CompanyLogoBanner({
    super.key,
    required this.name,
    this.width,
    this.height = 114,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(15)),
  });

  final String name;
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  static String? _assetPath(String name) {
    final n = name.trim().toLowerCase();
    if (n.contains('google')) return 'assets/logos/google.png';
    if (n.contains('amazon') || n.contains('aws')) {
      return 'assets/logos/amazon.png';
    }
    if (n.contains('microsoft')) return 'assets/logos/microsoft.png';
    if (n.contains('flipkart')) return 'assets/logos/flipkart.png';
    if (n.contains('apple')) return 'assets/logos/apple.png';
    if (n.contains('meta') || n.contains('facebook')) {
      return 'assets/logos/meta.png';
    }
    if (n.contains('uber')) return 'assets/logos/uber.png';
    if (n.contains('netflix')) return 'assets/logos/netflix.png';
    if (n.contains('spotify')) return 'assets/logos/spotify.png';
    if (n.contains('adobe')) return 'assets/logos/adobe.png';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final asset = _assetPath(name);

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurfaceSubtle : AppColors.lightBlue,
        borderRadius: borderRadius,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Subtle background texture / grid
          Positioned.fill(
            child: Opacity(
              opacity: dark ? 0.06 : 0.04,
              child: CustomPaint(painter: _DotPatternPainter()),
            ),
          ),
          // Logo Centerpiece
          if (asset != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Image.asset(
                asset,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) =>
                    CompanyAvatar(name: name, size: 54),
              ),
            )
          else
            CompanyAvatar(name: name, size: 52),
        ],
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.grey;
    const spacing = 14.0;
    for (double x = 4; x < size.width; x += spacing) {
      for (double y = 4; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CompanyAvatar extends StatelessWidget {
  const CompanyAvatar({super.key, required this.name, this.size = 38});

  final String name;
  final double size;

  static String? assetPathFor(String name) =>
      CompanyLogoBanner._assetPath(name);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final normalized = name.trim().toLowerCase();
    final asset = CompanyLogoBanner._assetPath(name);

    if (asset != null) {
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: dark ? AppColors.darkSurfaceSubtle : AppColors.sageSoft,
          borderRadius: BorderRadius.circular(size * .28),
          border: Border.all(
            color: dark ? AppColors.darkBorder : AppColors.line,
            width: 1,
          ),
        ),
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              _buildFallback(context, dark, normalized),
        ),
      );
    }

    return _buildFallback(context, dark, normalized);
  }

  Widget _buildFallback(BuildContext context, bool dark, String normalized) {
    Widget? brandLogo;
    Color? customBg;
    Color? customBorder;

    if (normalized.contains('google')) {
      brandLogo = _GoogleLogo(size: size * 0.58);
      customBg = dark ? const Color(0xFF1E2022) : Colors.white;
      customBorder = dark ? const Color(0xFF33383F) : const Color(0xFFE2E4E8);
    } else if (normalized.contains('amazon') || normalized.contains('aws')) {
      brandLogo = _AmazonLogo(size: size * 0.65);
      customBg = const Color(0xFF131921);
      customBorder = const Color(0xFF232F3E);
    } else if (normalized.contains('microsoft')) {
      brandLogo = _MicrosoftLogo(size: size * 0.52);
      customBg = dark ? const Color(0xFF1E2022) : Colors.white;
      customBorder = dark ? const Color(0xFF33383F) : const Color(0xFFE2E4E8);
    } else if (normalized.contains('flipkart')) {
      brandLogo = _FlipkartLogo(size: size * 0.62);
      customBg = const Color(0xFF2874F0);
      customBorder = const Color(0xFF1A58BF);
    } else if (normalized.contains('apple')) {
      brandLogo = _AppleLogo(size: size * 0.55, dark: dark);
      customBg = dark ? const Color(0xFF222222) : const Color(0xFFF2F2F4);
      customBorder = dark ? const Color(0xFF383838) : const Color(0xFFDCDCE0);
    } else if (normalized.contains('meta') || normalized.contains('facebook')) {
      brandLogo = _MetaLogo(size: size * 0.58);
      customBg = dark ? const Color(0xFF0C1D38) : const Color(0xFFE7F0FF);
      customBorder = const Color(0xFF0866FF).withValues(alpha: 0.3);
    } else if (normalized.contains('uber')) {
      brandLogo = _UberLogo(size: size * 0.7);
      customBg = Colors.black;
      customBorder = const Color(0xFF333333);
    } else if (normalized.contains('netflix')) {
      brandLogo = _NetflixLogo(size: size * 0.56);
      customBg = const Color(0xFF141414);
      customBorder = const Color(0xFF282828);
    } else if (normalized.contains('spotify')) {
      brandLogo = _SpotifyLogo(size: size * 0.58);
      customBg = const Color(0xFF121212);
      customBorder = const Color(0xFF1DB954).withValues(alpha: 0.3);
    } else if (normalized.contains('adobe')) {
      brandLogo = _AdobeLogo(size: size * 0.55);
      customBg = const Color(0xFFFA0F00);
      customBorder = const Color(0xFFD60E00);
    } else if (normalized.contains('startuphub')) {
      brandLogo = Icon(Icons.rocket_launch_rounded,
          size: size * 0.5, color: const Color(0xFF6366F1));
      customBg = dark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF);
      customBorder = const Color(0xFF6366F1).withValues(alpha: 0.3);
    } else if (normalized.contains('fenix')) {
      brandLogo = Icon(Icons.local_fire_department_rounded,
          size: size * 0.54, color: const Color(0xFFF97316));
      customBg = dark ? const Color(0xFF431407) : const Color(0xFFFFEDD5);
      customBorder = const Color(0xFFF97316).withValues(alpha: 0.3);
    } else if (normalized.contains('northstar')) {
      brandLogo = Icon(Icons.explore_rounded,
          size: size * 0.52, color: const Color(0xFF0EA5E9));
      customBg = dark ? const Color(0xFF082F49) : const Color(0xFFE0F2FE);
      customBorder = const Color(0xFF0EA5E9).withValues(alpha: 0.3);
    } else if (normalized.contains('paperplane')) {
      brandLogo = Icon(Icons.send_rounded,
          size: size * 0.48, color: const Color(0xFF10B981));
      customBg = dark ? const Color(0xFF064E3B) : const Color(0xFFD1FAE5);
      customBorder = const Color(0xFF10B981).withValues(alpha: 0.3);
    } else if (normalized.contains('lattice')) {
      brandLogo = Icon(Icons.grid_view_rounded,
          size: size * 0.5, color: const Color(0xFF8B5CF6));
      customBg = dark ? const Color(0xFF2E1065) : const Color(0xFFF3E8FF);
      customBorder = const Color(0xFF8B5CF6).withValues(alpha: 0.3);
    } else if (normalized.contains('quantara')) {
      brandLogo = Icon(Icons.insights_rounded,
          size: size * 0.5, color: const Color(0xFF14B8A6));
      customBg = dark ? const Color(0xFF042F2E) : const Color(0xFFCCFBF1);
      customBorder = const Color(0xFF14B8A6).withValues(alpha: 0.3);
    }

    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();

    final bgColor =
        customBg ?? (dark ? AppColors.darkSurfaceSubtle : AppColors.sageSoft);
    final borderColor =
        customBorder ?? (dark ? AppColors.darkBorder : AppColors.line);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(size * .28),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.25 : 0.04),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: brandLogo ??
          Text(
            initials.isEmpty ? '?' : initials,
            style: TextStyle(
              fontSize: size * .34,
              fontWeight: FontWeight.w700,
              color: dark ? AppColors.violetSoft : AppColors.sage,
            ),
          ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top Company Brand Vector Renderers
// ---------------------------------------------------------------------------

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GooglePainter(),
    );
  }
}

class _GooglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.24;
    final rect =
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final paintRed = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintYellow = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintGreen = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final paintBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    // Google G 4 color arcs
    // Red: Top right to top left
    canvas.drawArc(rect, -math.pi * 0.75, math.pi * 0.5, false, paintRed);
    // Yellow: Top left to bottom left
    canvas.drawArc(rect, -math.pi * 1.25, math.pi * 0.5, false, paintYellow);
    // Green: Bottom left to bottom right
    canvas.drawArc(rect, math.pi * 0.25, math.pi * 0.5, false, paintGreen);
    // Blue: Bottom right & middle bar
    canvas.drawArc(rect, -math.pi * 0.25, math.pi * 0.5, false, paintBlue);

    // Crossbar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - strokeWidth * 0.1,
        center.dy - strokeWidth / 2,
        radius + strokeWidth * 0.1,
        strokeWidth,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MicrosoftLogo extends StatelessWidget {
  const _MicrosoftLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final gap = size * 0.12;
    final squareSize = (size - gap) / 2;
    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: squareSize,
                height: squareSize,
                decoration: BoxDecoration(
                  color: const Color(0xFFF25022),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              Container(
                width: squareSize,
                height: squareSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF7FBA00),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: squareSize,
                height: squareSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF00A4EF),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
              Container(
                width: squareSize,
                height: squareSize,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB900),
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AmazonLogo extends StatelessWidget {
  const _AmazonLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.85,
      child: CustomPaint(
        painter: _AmazonPainter(),
      ),
    );
  }
}

class _AmazonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'a',
        style: TextStyle(
          color: Colors.white,
          fontSize: size.height * 0.78,
          fontWeight: FontWeight.w900,
          fontFamily: 'sans-serif',
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height * 0.02),
    );

    // Amazon orange smile curve
    final smilePaint = Paint()
      ..color = const Color(0xFFFF9900)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.12
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.15, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.52,
        size.height * 0.98,
        size.width * 0.88,
        size.height * 0.82,
      );

    canvas.drawPath(path, smilePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FlipkartLogo extends StatelessWidget {
  const _FlipkartLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.shopping_bag_rounded,
          size: size * 0.52,
          color: const Color(0xFFFFE500),
        ),
        Text(
          'f',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.44,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            height: 0.8,
          ),
        ),
      ],
    );
  }
}

class _AppleLogo extends StatelessWidget {
  const _AppleLogo({required this.size, required this.dark});
  final double size;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.apple,
      size: size * 1.05,
      color: dark ? Colors.white : Colors.black,
    );
  }
}

class _MetaLogo extends StatelessWidget {
  const _MetaLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.all_inclusive_rounded,
      size: size * 1.05,
      color: const Color(0xFF0866FF),
    );
  }
}

class _UberLogo extends StatelessWidget {
  const _UberLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Uber',
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.4,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    );
  }
}

class _NetflixLogo extends StatelessWidget {
  const _NetflixLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      'N',
      style: TextStyle(
        color: const Color(0xFFE50914),
        fontSize: size * 0.85,
        fontWeight: FontWeight.w900,
        height: 1,
      ),
    );
  }
}

class _SpotifyLogo extends StatelessWidget {
  const _SpotifyLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.graphic_eq_rounded,
      size: size * 0.9,
      color: const Color(0xFF1DB954),
    );
  }
}

class _AdobeLogo extends StatelessWidget {
  const _AdobeLogo({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      'A',
      style: TextStyle(
        color: Colors.white,
        fontSize: size * 0.82,
        fontWeight: FontWeight.w900,
        fontFamily: 'serif',
        height: 1,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurfaceSubtle
                    : AppColors.sageSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon,
                  size: 25, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(subtitle,
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center),
            if (actionLabel != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
