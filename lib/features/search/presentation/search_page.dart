import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_provider.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _searchCtrl = TextEditingController();
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider).isDark;
    final bg = isDark ? AuroraColors.bgPrimary : HarmoniqColors.bg;
    final textP = isDark ? AuroraColors.textPrimary : HarmoniqColors.textPrimary;
    final textS = isDark ? AuroraColors.textSecondary : HarmoniqColors.textSecondary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, size: 24, color: textP),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: SizedBox(
          height: 44,
          child: TextField(
            controller: _searchCtrl,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search online music...',
              hintStyle: TextStyle(color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary, fontSize: 15),
              filled: true,
              fillColor: isDark ? AuroraColors.bgSecondary : HarmoniqColors.aux,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(Icons.search_rounded, size: 20,
                  color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, size: 18,
                          color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _hasSearched = false);
                      },
                    )
                  : null,
            ),
            style: TextStyle(fontSize: 15, color: textP),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) {
                setState(() => _hasSearched = true);
              }
            },
          ),
        ),
      ),
      body: Center(
        child: _hasSearched
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded, size: 56,
                      color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary),
                  const SizedBox(height: 16),
                  Text('No results for "${_searchCtrl.text}"',
                      style: TextStyle(color: textS, fontSize: 16)),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.language_rounded, size: 56,
                      color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary),
                  const SizedBox(height: 16),
                  Text('Search music from online sources',
                      style: TextStyle(color: textS, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Powered by cloud music API',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AuroraColors.textDisabled : HarmoniqColors.textSecondary,
                      )),
                ],
              ),
      ),
    );
  }
}
