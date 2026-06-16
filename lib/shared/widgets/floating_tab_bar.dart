import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';

class FloatingTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;

  const FloatingTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isDark
        ? const Color(0xEB161A24)
        : const Color(0xE8FFFFFF);

    final tabItems = [
      _TabItem(Icons.library_music_rounded, 'Library'),
      _TabItem(Icons.cloud_upload_outlined, 'Upload'),
      _TabItem(Icons.person_outline_rounded, 'Me'),
    ];

    return Container(
      margin: EdgeInsets.only(
        bottom: isDark ? 16.0 : 20.0,
        left: MediaQuery.of(context).size.width * 0.05,
        right: MediaQuery.of(context).size.width * 0.05,
      ),
      height: isDark ? 86.0 : 80.0,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isDark ? 32.0 : 40.0),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0x14283246),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: const Color(0x0C283246),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: List.generate(tabItems.length, (i) {
          final item = tabItems[i];
          final selected = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Container(
                decoration: selected
                    ? BoxDecoration(
                        gradient: isDark
                            ? const LinearGradient(
                                colors: AuroraColors.gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : const LinearGradient(
                                colors: [
                                  HarmoniqColors.blue,
                                  HarmoniqColors.emphasize,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        borderRadius: BorderRadius.circular(28),
                      )
                    : null,
                margin: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      color: selected
                          ? Colors.white
                          : isDark
                              ? AuroraColors.textSecondary
                              : HarmoniqColors.textSecondary,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        color: selected
                            ? Colors.white
                            : isDark
                                ? AuroraColors.textSecondary
                                : HarmoniqColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem(this.icon, this.label);
}
