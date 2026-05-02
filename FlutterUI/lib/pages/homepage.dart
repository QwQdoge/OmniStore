import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _isLoading = true);
    final results = await BackendService().getRecommendations();
    if (mounted) {
      setState(() {
        _recommendations = results;
        _isLoading = false;
      });
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
                        child: Center(child: Text(AppLocalizations.of(context)!.noResults)),
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
                          itemBuilder: (context, index) =>
                              _buildBannerCard(context, _recommendations[index]),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 16),
                child: _buildSectionHeader(AppLocalizations.of(context)!.hotApps),
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
    return Container(
      width: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: theme.brightness == Brightness.light
            ? Colors.white
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
                opacity: animation.drive(CurveTween(curve: Curves.easeInOutExpo)),
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
                color: colorScheme.outlineVariant.withOpacity(0.3),
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
                  child: (app.screenshots != null && app.screenshots!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: app.screenshots![0],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              color: colorScheme.primary.withOpacity(0.3),
                              strokeWidth: 2,
                            ),
                          ),
                          errorWidget: (c, e, s) => Icon(
                            Icons.image_outlined,
                            size: 48,
                            color: colorScheme.primary.withOpacity(0.5),
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
                              color: colorScheme.primary.withOpacity(0.5),
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
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: app.icon != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
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
                              style: const TextStyle(
                                color: Colors.white,
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
                          Text(
                            "Rating 4.${(app.name.length % 5) + 5} • ${app.primarySource}",
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
  );
}

  Widget _buildListCard(BuildContext context, AppPackage app) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                AppDetailsPage(app: app),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation.drive(CurveTween(curve: Curves.easeInOutExpo)),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // 方角图标（Squircle）
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: app.icon != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: app.icon!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : Text(
                        app.name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
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
                        Text(
                          "${(app.name.length * 12.5).toStringAsFixed(0)} MB",
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSourceChips(app.sources.take(1).toList()),
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
                    borderRadius: BorderRadius.circular(20),
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
                          opacity: animation.drive(CurveTween(curve: Curves.easeInOutExpo)),
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
    );
  }

  Widget _buildSourceChips(List<String> sources) {
    return Wrap(
      spacing: 6,
      children: sources
          .map(
            (s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                s,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
