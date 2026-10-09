import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/smooth_size_switcher.dart';

class GitHubStoreTabs extends StatelessWidget {
  final TabController tabController;
  final bool isSearching;

  const GitHubStoreTabs({
    super.key,
    required this.tabController,
    required this.isSearching,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SmoothSizeSwitcher(
      child: isSearching
          ? const SizedBox.shrink(key: ValueKey('empty_tabs'))
          : Padding(
              key: const ValueKey('tabs_padding'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  controller: tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: scheme.primaryContainer.withValues(alpha: 0.5),
                  ),
                  labelColor: scheme.onPrimaryContainer,
                  unselectedLabelColor: scheme.onSurfaceVariant,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(
                      text: "推荐",
                      icon: Icon(Icons.recommend_rounded, size: 20),
                    ),
                    Tab(
                      text: "排行榜",
                      icon: Icon(Icons.leaderboard_rounded, size: 20),
                    ),
                    Tab(
                      text: "热度榜",
                      icon: Icon(Icons.local_fire_department_rounded, size: 20),
                    ),
                    Tab(
                      text: "最新更新",
                      icon: Icon(Icons.update_rounded, size: 20),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
