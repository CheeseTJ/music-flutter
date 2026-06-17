import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/pearl_colors.dart';

class FloatingTabBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FloatingTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<FloatingTabBar> createState() => _FloatingTabBarState();
}

class _FloatingTabBarState extends State<FloatingTabBar> {
  static const _tabs = [
    _TabItem(Icons.music_note_rounded, 'Collection'),
    _TabItem(Icons.upload_rounded, 'Import'),
    _TabItem(Icons.lock_outline_rounded, 'Vault'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    final navWidth = screenWidth * 0.8;
    final itemWidth = navWidth / 3;
    const indicatorWidth = 36.0;
    const tabHeight = 72.0;
    const tabRadius = 36.0;
    final indicatorLeft = itemWidth * widget.currentIndex + (itemWidth - indicatorWidth) / 2;

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: 20 + bottomInset),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(tabRadius),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              width: navWidth,
              height: tabHeight,
              decoration: BoxDecoration(
                color: PearlColors.glassBg(isDark),
                borderRadius: BorderRadius.circular(tabRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                    spreadRadius: -8,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.10 : 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.06 : 0.5),
                  width: 0.5,
                ),
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
                        gradient: LinearGradient(
                          colors: [
                            PearlColors.accent(isDark),
                            const Color(0xFF9B8BFF),
                          ],
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
                      final accent = PearlColors.accent(isDark);
                      final accentGradient = LinearGradient(
                        colors: [accent, const Color(0xFF9B8BFF)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      );
                      final unselectedColor = PearlColors.textDisabled(isDark);

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
                                    ? accentGradient.createShader(bounds)
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
                                  shaderCallback: (bounds) => accentGradient.createShader(bounds),
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
