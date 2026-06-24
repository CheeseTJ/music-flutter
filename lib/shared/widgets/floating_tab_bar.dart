import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/animation/pearl_motion.dart';
import '../../core/theme/pearl_colors.dart';
import '../../core/widgets/upload_button.dart';

class FloatingTabBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool showUploadButton;
  final bool isDark;

  const FloatingTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.showUploadButton = true,
    this.isDark = true,
  });

  @override
  State<FloatingTabBar> createState() => _FloatingTabBarState();
}

class _FloatingTabBarState extends State<FloatingTabBar> {
  // Collection (0), Vault (1). The upload shortcut sits in the same
  // row to the right (not floating above the capsule). Online import
  // is reached via the search bar on the home page.
  static const _tabs = [
    _TabItem(Icons.music_note_rounded, 'Collection'),
    _TabItem(Icons.lock_outline_rounded, 'Vault'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    const indicatorWidth = 36.0;
    const tabHeight = 64.0;
    const tabRadius = 32.0;

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: 16 + bottomInset, left: 16, right: 16),
      child: Row(
        children: [
          // Capsule with 2 tabs on the left
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(tabRadius),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                child: Container(
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final capsuleWidth = constraints.maxWidth;
                      final itemWidth = capsuleWidth / _tabs.length;
                      final indicatorLeft =
                          itemWidth * widget.currentIndex + (itemWidth - indicatorWidth) / 2;

                      return Stack(
                        children: [
                          AnimatedPositioned(
                            duration: PearlMotion.durationMd,
                            curve: PearlMotion.standard,
                            left: indicatorLeft,
                            bottom: 8,
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
                          Row(
                            children: List.generate(_tabs.length, (i) {
                              final selected = i == widget.currentIndex;
                              final accent = PearlColors.accent(isDark);
                              final accentGradient = LinearGradient(
                                colors: [accent, const Color(0xFF9B8BFF)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              );
                              final unselectedColor =
                                  PearlColors.textDisabled(isDark);

                              return Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => widget.onTap(i),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(height: 4),
                                      AnimatedSwitcher(
                                        duration: PearlMotion.durationMd,
                                        switchInCurve: PearlMotion.standard,
                                        switchOutCurve: PearlMotion.standardIn,
                                        transitionBuilder: (child, anim) =>
                                            FadeTransition(opacity: anim, child: child),
                                        child: ShaderMask(
                                          key: ValueKey(selected),
                                          shaderCallback: (bounds) => selected
                                              ? accentGradient.createShader(bounds)
                                              : LinearGradient(colors: [
                                                  unselectedColor,
                                                  unselectedColor
                                                ]).createShader(bounds),
                                          child: Icon(
                                            _tabs[i].icon,
                                            size: 22,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      AnimatedSize(
                                        duration: PearlMotion.durationMd,
                                        curve: PearlMotion.standard,
                                        child: AnimatedOpacity(
                                          duration: PearlMotion.durationMd,
                                          curve: PearlMotion.standard,
                                          opacity: selected ? 1.0 : 0.0,
                                          child: selected
                                              ? ShaderMask(
                                                  shaderCallback: (bounds) =>
                                                      accentGradient.createShader(bounds),
                                                  child: Text(
                                                    _tabs[i].label,
                                                    style: const TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                )
                                              : const SizedBox(width: 0, height: 0),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // Upload button on the right of the same row.
          if (widget.showUploadButton) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: tabHeight,
              child: Center(
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: UploadButton(isDark: isDark),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final String label;
  const _TabItem(this.icon, this.label);
}
