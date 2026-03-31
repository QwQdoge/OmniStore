import 'package:flutter/material.dart';
import 'pages/homepage.dart';
import 'pages/searchpage.dart';

void main() => runApp(const OmnistoreApp());

class OmnistoreApp extends StatelessWidget {
  const OmnistoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const MainNavigationEntry(),
    );
  }
}

class MainNavigationEntry extends StatefulWidget {
  const MainNavigationEntry({super.key});

  @override
  State<MainNavigationEntry> createState() => _MainNavigationEntryState();
}

class _MainNavigationEntryState extends State<MainNavigationEntry> {
  int _selectedIndex = 0;

  final List<Widget> _subPages = [
    const HomePage(),
    const SearchPage(),
    const Center(child: Text("Settings Page")),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // 背景色使用 Surface，与内容区做区分
      backgroundColor: colorScheme.surface,
      body: Row(
        children: [
          // 1. 更加精致的 NavigationRail
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (i) => setState(() => _selectedIndex = i),
            labelType: NavigationRailLabelType.all,
            backgroundColor: colorScheme.surface, // 侧边栏与底色融为一体
            useIndicator: true, // 启用 M3 特有的胶囊形选中指示器
            indicatorColor: colorScheme.secondaryContainer,
            minWidth: 80, // 稍微加宽，增加呼吸感
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Icon(
                Icons.auto_awesome_mosaic,
                size: 32,
                color: colorScheme.primary,
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.search_rounded),
                label: Text('Search'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: Text('Settings'),
              ),
            ],
          ),

          // 2. 移除生硬的 VerticalDivider，改用圆角容器包裹内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 12, 12, 12), // 四周留白
              child: Container(
                clipBehavior: Clip.antiAlias, // 确保子页面圆角生效
                decoration: BoxDecoration(
                  // 使用 M3 的 Surface Container Low，产生微妙的层级感
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24), // 大圆角是 M3 的灵魂
                ),
                child: IndexedStack(index: _selectedIndex, children: _subPages),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
