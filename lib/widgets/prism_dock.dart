import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class DockItem {
  const DockItem(
      {required this.icon,
      required this.activeIcon,
      required this.label,
      this.badgeCount = 0});

  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Number shown in the notification badge. Hidden when zero.
  final int badgeCount;
}

/// A compact bottom taskbar with a single quiet active state.
class PrismDock extends StatelessWidget {
  const PrismDock({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<DockItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const double height = 66;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: dark ? AppColors.darkSurface : AppColors.paper,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(
              color: dark ? AppColors.darkBorderStrong : AppColors.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? .24 : .07),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: _DockButton(
                  item: items[index],
                  active: index == currentIndex,
                  onTap: () => onSelect(index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton(
      {required this.item, required this.active, required this.onTap});

  final DockItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark ? AppColors.darkMuted : AppColors.stone;
    return Semantics(
      selected: active,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: active
                ? (dark ? AppColors.darkSurfaceSubtle : AppColors.sageSoft)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      active ? item.activeIcon : item.icon,
                      key: ValueKey(active),
                      size: 20,
                      color: active
                          ? (dark
                              ? AppColors.brightBlue
                              : AppColors.primaryBlue)
                          : muted,
                    ),
                  ),
                  if (item.badgeCount > 0)
                    Positioned(
                      top: -7,
                      right: -11,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color:
                                dark ? AppColors.darkSurface : AppColors.paper,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          item.badgeCount > 9 ? '9+' : '${item.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? (dark ? AppColors.brightBlue : AppColors.primaryBlue)
                      : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
