import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/animation/pearl_motion.dart';
import '../../core/theme/pearl_colors.dart';
import '../../core/theme/pearl_elevation.dart';
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
  // 图标下方不再放文字，选中态只靠渐变色图标 + 底部指示条表达。
  static const _tabs = <IconData>[
    Icons.music_note_rounded,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    const indicatorWidth = 36.0;
    const tabHeight = 64.0;

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final radius = PearlElevation.radius(PearlLayer.nav);

    return Padding(
      padding: EdgeInsets.only(bottom: 16 + bottomInset, left: 16, right: 16),
      child: Row(
        children: [
          // Capsule with 2 icon-only tabs on the left.
          Expanded(
            child: Container(
              // 阴影必须画在 ClipRRect 之外：ClipRRect 会把 Container 自己
              // 投出的 BoxShadow 一并裁掉，之前那层阴影其实从未渲染过。
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius),
                boxShadow: PearlElevation.shadow(PearlLayer.nav, isDark),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                  child: Container(
                    height: tabHeight,
                    decoration: BoxDecoration(
                      color: PearlElevation.fill(PearlLayer.nav, isDark),
                      borderRadius: BorderRadius.circular(radius),
                      border: PearlElevation.outline(PearlLayer.nav, isDark),
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
                                final unselectedColor = PearlColors.textDisabled(isDark);

                                return Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => widget.onTap(i),
                                    child: Center(
                                      child: AnimatedSwitcher(
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
                                            _tabs[i],
                                            size: 24,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
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
