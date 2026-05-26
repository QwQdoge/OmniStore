import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import '../l10n/app_localizations.dart';
import '../services/app_package.dart';
import '../services/backend_service.dart';
import './app_details_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<AppPackage> _recommendations = [];
  List<dynamic> _essentials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final recFuture = BackendService.instance.getRecommendations();
    final essFuture = BackendService.instance.getEssentials();

    final results = await Future.wait([recFuture, essFuture]);

    if (mounted) {
      setState(() {
        _recommendations = List<AppPackage>.from(results[0]);
        _essentials = results[1];
        _isLoading = false;
      });
    }
  }

  Future<void> _importPackages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'json'],
    );

    if (result != null) {
      final path = result.files.single.path!;
      final packages = await BackendService.instance.importPackages(path);
      if (mounted && packages.isNotEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("导入软件包"),
            content: Text("已从文件中读取 ${packages.length} 个软件包。是否开始批量下载？"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  for (var pkg in packages) {
                    final name = pkg['name'] as String;
                    final source = pkg['source'] as String? ?? 'Native';
                    _executeInstall(name, source);
                  }
                },
                child: const Text("全部下载"),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(AppLocalizations.of(context)!.featured),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const SizedBox(
                        height: 210,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_recommendations.isEmpty)
                      SizedBox(
                        height: 210,
                        child: Center(
                            child: Text(AppLocalizations.of(context)!.noResults)),
                      )
                    else
                      SizedBox(
                        height: 210,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: (_recommendations.length / 2).floor(),
                          separatorBuilder: (context, index) =>
                              const SizedBox(width: 16),
                          itemBuilder: (context, index) => _buildBannerCard(
                              context, _recommendations[index]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 16),
                child: Row(
                  children: [
                    Expanded(child: _buildSectionHeader("必备软件包")),
                    Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: OutlinedButton.icon(
                        onPressed: _importPackages,
                        icon: const Icon(Icons.file_upload_outlined, size: 18),
                        label: const Text("导入列表"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 80,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildEssentialCard(_essentials[index]),
                    childCount: _essentials.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 16),
                child:
                    _buildSectionHeader(AppLocalizations.of(context)!.hotApps),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final startIndex = (_recommendations.length / 2).floor();
                      if (startIndex + index >= _recommendations.length) {
                        return null;
                      }
                      return _buildListCard(
                          context, _recommendations[startIndex + index]);
                    },
                    childCount: _recommendations.length -
                        (_recommendations.length / 2).floor(),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildBannerCard(BuildContext context, AppPackage app) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return RepaintBoundary(
      child: Container(
        width: 300,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: theme.brightness == Brightness.light
              ? colorScheme.surfaceContainerLow
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(28.0),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    AppDetailsPage(app: app),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation
                        .drive(CurveTween(curve: Curves.easeInOutExpo)),
                    child: SlideTransition(
                      position: animation.drive(Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeInOutExpo))),
                      child: child,
                    ),
                  );
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28.0),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 上半部分：类似宣传大图
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            colorScheme.primaryContainer,
                            colorScheme.tertiaryContainer,
                          ],
                        ),
                      ),
                      child: (app.screenshots != null &&
                              app.screenshots!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: app.screenshots![0],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(
                                  color:
                                      colorScheme.primary.withValues(alpha: 0.3),
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (c, e, s) => Icon(
                                Icons.image_outlined,
                                size: 48,
                                color:
                                    colorScheme.primary.withValues(alpha: 0.5),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    colorScheme.primaryContainer,
                                    colorScheme.tertiaryContainer,
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.image_outlined,
                                  size: 48,
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                    ),
                  ),
                  // 下半部分：应用信息
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        // 小图标
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(12.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: app.icon != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(12.0),
                                  child: CachedNetworkImage(
                                    imageUrl: app.icon!,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        const CircularProgressIndicator(
                                            strokeWidth: 2),
                                  ),
                                )
                              : Text(
                                  app.name[0].toUpperCase(),
                                          style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                app.name,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    "Rating 4.${(app.name.length % 5) + 5} • ",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                  _buildSourceChips(
                                      app.sources.take(2).toList()),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEssentialCard(dynamic item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final name = item['name'] as String;
    final source = item['source'] as String? ?? 'Native';

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        title: Text(name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(item['description'] ?? "",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11)),
        trailing: IconButton(
          onPressed: () => _executeInstall(name, source),
          icon: Icon(Icons.download_for_offline_rounded,
              color: colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildTrustLabel(String source) {
    String label = "社区";
    Color color = Colors.orange;
    IconData icon = Icons.people_outline;

    if (source == "Pacman" || source == "Native") {
      label = "官方";
      color = Colors.blue;
      icon = Icons.verified_user_outlined;
    } else if (source == "Flatpak") {
      label = "经校验";
      color = Colors.green;
      icon = Icons.verified_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _executeInstall(String name, String source) {
    BackendService.instance
        .executeAction("-I", name, source)
        .listen((event) {
      // 进度和状态由 BackendService 的 ValueNotifier 自动同步到全局 UI
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("正在安装 $name...")),
    );
  }

  Widget _buildListCard(BuildContext context, AppPackage app) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 获取当前可用变体
    final otherSources =
        app.sources.where((s) => s != app.primarySource).toList();
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20.0),
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  AppDetailsPage(app: app),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity:
                      animation.drive(CurveTween(curve: Curves.easeInOutExpo)),
                  child: SlideTransition(
                    position: animation.drive(Tween<Offset>(
                      begin: const Offset(0.05, 0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeInOutExpo))),
                    child: child,
                  ),
                );
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                // 方角图标（Squircle）
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: app.icon != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: CachedNetworkImage(
                            imageUrl: app.icon!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) =>
                                const CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.purple,
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            "M",
                            style: TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                            _buildTrustLabel(app.primarySource),
                            const SizedBox(width: 8),
                          Text(
                            "${(app.name.length * 12.5).toStringAsFixed(0)} MB",
                            style: TextStyle(
                                fontSize: 11,
                              color:
                                  colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (otherSources.isEmpty)
                            _buildSourceChips([app.primarySource])
                          else
                            DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: app.primarySource,
                                isDense: true,
                                icon:
                                    const Icon(Icons.arrow_drop_down, size: 14),
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue),
                                items: app.sources
                                    .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s,
                                              style: const TextStyle(
                                                  fontSize: 10)),
                                        ))
                                    .toList(),
                                onChanged: (v) {
                                  // 这里我们通常需要改变 app 的状态，但 app 是由后台生成的
                                  // 实际上跳转到详情页选择更合适，这里我们只显示所有来源
                                },
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // 安装按钮 (Google Play 风格)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            AppDetailsPage(app: app),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: animation.drive(
                                CurveTween(curve: Curves.easeInOutExpo)),
                            child: SlideTransition(
                              position: animation.drive(Tween<Offset>(
                                begin: const Offset(0.05, 0),
                                end: Offset.zero,
                              ).chain(CurveTween(curve: Curves.easeInOutExpo))),
                              child: child,
                            ),
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 500),
                      ),
                    );
                  },
                  child: Text(
                    app.installed
                        ? AppLocalizations.of(context)!.open
                        : AppLocalizations.of(context)!.install,
                    style: TextStyle(
                      color: app.installed
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceChips(List<String> sources) {
    return Builder(builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return Wrap(
        spacing: 6,
        children: sources
            .map(
              (s) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 10,
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
            .toList(),
      );
    });
  }
}
