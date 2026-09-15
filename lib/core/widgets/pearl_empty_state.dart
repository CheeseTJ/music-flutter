import 'package:flutter/material.dart';

import '../theme/pearl_colors.dart';

/// 统一的空状态 / 错误态。
///
/// 之前 6 处各写一份，形态从「图标 + 标题 + 副标题 + 重试按钮」到「就一行文字」
/// 都有（层数 1~4 不等）。现在统一成：图标 + 标题 +（可选）副标题 +（可选）操作。
///
/// [compact] 给窄容器用（播放列表弹层、歌词区），图标与字号各降一档。
class PearlEmptyState extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  /// 窄容器：图标 36、标题 14、副标题 12
  final bool compact;

  /// 默认 textDisabled；错误态传强调色（如 #FF7A9E）
  final Color? iconColor;

  const PearlEmptyState({
    super.key,
    required this.isDark,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
    this.compact = false,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 36 : 56,
              color: iconColor ?? PearlColors.textDisabled(isDark),
            ),
            SizedBox(height: compact ? 10 : 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 14 : 16,
                color: PearlColors.textSecondary(isDark),
              ),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  color: PearlColors.textDisabled(isDark),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
