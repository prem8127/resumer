import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A tappable field row that opens [showPickerSheet].
class PickField extends StatelessWidget {
  const PickField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon,
    this.hint,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData? icon;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: dark
              ? Colors.white.withValues(alpha: 0.055)
              : Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: dark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: AppColors.violetSoft),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: dark ? AppColors.darkMuted : AppColors.lightMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.isEmpty ? (hint ?? 'Select…') : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: value.isEmpty
                          ? (dark ? AppColors.darkMuted : AppColors.lightMuted)
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.darkMuted),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet single-select picker. Returns the chosen [T] or null.
Future<T?> showPickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<T> options,
  required String Function(T) labelOf,
  String? Function(T)? subtitleOf,
  T? initial,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Text(title,
                    style: Theme.of(sheetContext).textTheme.headlineSmall),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final option in options)
                      ListTile(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        title: Text(labelOf(option),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: subtitleOf == null
                            ? null
                            : Text(subtitleOf(option) ?? ''),
                        trailing: option == initial
                            ? const Icon(Icons.check_circle_rounded,
                                color: AppColors.violet, size: 22)
                            : const Icon(Icons.radio_button_unchecked_rounded,
                                color: Colors.transparent, size: 22),
                        onTap: () => Navigator.of(sheetContext).pop(option),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
