import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class FloatingTabBar extends StatefulWidget {
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
  State<FloatingTabBar> createState() => _FloatingTabBarState();
}

class _FloatingTabBarState extends State<FloatingTabBar> {
  static const _tabs = [
    _TabItem(Icons.music_note_rounded, 'Library'),
    _TabItem(Icons.upload_rounded, 'Upload'),
    _TabItem(Icons.person_outline_rounded, 'Me'),
  ];

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final navWidth = screenWidth * 0.9;
    final itemWidth = navWidth / 3;
    const indicatorWidth = 64.0;
    final indicatorLeft = itemWidth * widget.currentIndex + (itemWidth - indicatorWidth) / 2;

    return Padding(
      padding: EdgeInsets.only(bottom: widget.isDark ? 16.0 : 20.0),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.isDark ? 32.0 : 40.0),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              width: navWidth,
              height: widget.isDark ? 86.0 : 80.0,
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xEB161A24)
                    : const Color(0xE8FFFFFF),
                borderRadius: BorderRadius.circular(widget.isDark ? 32.0 : 40.0),
                boxShadow: [
                  BoxShadow(
                    color: widget.isDark
                        ? Colors.black.withValues(alpha: 0.12)
                        : const Color(0x0C283246),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Animated bottom indicator bar
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    left: indicatorLeft,
                    bottom: 10,
                    child: Container(
                      width: indicatorWidth,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: widget.isDark
                            ? AuroraColors.primaryGradientH
                            : const LinearGradient(
                                colors: [HarmoniqColors.blue, HarmoniqColors.emphasize],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Tab items
                  Row(
                    children: List.generate(_tabs.length, (i) {
                      final selected = i == widget.currentIndex;
                      final gradient = widget.isDark
                          ? AuroraColors.primaryGradientH
                          : const LinearGradient(
                              colors: [HarmoniqColors.blue, HarmoniqColors.emphasize],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            );
                      final unselectedColor = widget.isDark
                          ? AuroraColors.textDisabled
                          : HarmoniqColors.textSecondary;

                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onTap(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 2),
                              ShaderMask(
                                shaderCallback: (bounds) => selected
                                    ? gradient.createShader(bounds)
                                    : LinearGradient(colors: [unselectedColor, unselectedColor]).createShader(bounds),
                                child: Icon(
                                  _tabs[i].icon,
                                  size: 24,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (selected)
                                ShaderMask(
                                  shaderCallback: (bounds) => gradient.createShader(bounds),
                                  child: Text(
                                    _tabs[i].label,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  _tabs[i].label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    color: unselectedColor,
                                  ),
                                ),
                              const SizedBox(height: 2),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem(this.icon, this.label);
}
