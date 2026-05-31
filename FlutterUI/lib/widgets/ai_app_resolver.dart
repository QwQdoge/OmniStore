import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/app_package.dart';
import '../services/backend_service.dart';
import '../pages/app_details_page.dart';

class AIAppResolver extends StatefulWidget {
  final String aiText;
  final String jsonPrefix; // e.g., "APPS_JSON:" or "SUGGESTIONS_JSON:"

  const AIAppResolver({
    super.key,
    required this.aiText,
    required this.jsonPrefix,
  });

  @override
  State<AIAppResolver> createState() => _AIAppResolverState();
}

class _AIAppResolverState extends State<AIAppResolver> {
  List<AppPackage> _resolvedApps = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _resolveApps();
  }

  @override
  void didUpdateWidget(AIAppResolver oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aiText != widget.aiText) {
      _resolveApps();
    }
  }

  Future<void> _resolveApps() async {
    final names = _extractNames(widget.aiText);
    if (names.isEmpty) {
      if (mounted) setState(() => _resolvedApps = []);
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    List<AppPackage> found = [];
    // Use Future.wait to speed up name resolution
    final results = await Future.wait(
      names.take(5).map((name) => BackendService.instance.searchPackages(name, cancelOngoing: false))
    );

    for (var i = 0; i < results.length; i++) {
      final appList = results[i];
      if (appList.isNotEmpty) {
        found.add(AppPackage.fromJson(appList[0] as Map<String, dynamic>));
      }
    }

    if (mounted) {
      setState(() {
        _resolvedApps = found;
        _isLoading = false;
      });
    }
  }

  List<String> _extractNames(String text) {
    try {
      String target = text;
      const separator = "###JSON_START###";
      if (text.contains(separator)) {
        target = text.split(separator).last.trim();
      }

      // Match the JSON array [ ... ]
      final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(target);
      if (match != null) {
        final list = jsonDecode(match.group(0)!) as List;
        return list.map((e) => e.toString()).toList();
      }
    } catch (e) {
      debugPrint("AIAppResolver Error: $e");
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    if (_resolvedApps.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: _resolvedApps.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => _buildAppCard(_resolvedApps[index]),
      ),
    );
  }

  Widget _buildAppCard(AppPackage app) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AppDetailsPage(app: app)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Hero(
                  tag: 'app-icon-shelf-${app.name}-${app.primarySource}',
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: app.icon != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12.0),
                            child: CachedNetworkImage(
                              imageUrl: app.icon!,
                              fit: BoxFit.cover,
                              errorWidget: (c, e, s) => Center(
                                child: Text(
                                  app.name[0].toUpperCase(),
                                  style: TextStyle(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18),
                                ),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              app.name[0].toUpperCase(),
                              style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.name,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: -0.2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        app.description,
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
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
}
