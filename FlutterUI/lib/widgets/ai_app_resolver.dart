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
    if (names.isEmpty) return;

    if (mounted) setState(() => _isLoading = true);

    List<AppPackage> found = [];
    for (final name in names.take(5)) {
      try {
        final results = await BackendService.instance.searchPackages(name);
        if (results.isNotEmpty) {
          found.add(AppPackage.fromJson(results[0]));
        }
      } catch (_) {}
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
      final startIndex = text.indexOf(widget.jsonPrefix);
      if (startIndex == -1) return [];

      final jsonPart = text.substring(startIndex + widget.jsonPrefix.length).trim();
      // Match the JSON array [ ... ]
      final match = RegExp(r'\[.*\]', dotAll: true).firstMatch(jsonPart);
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
      width: 200,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.1)),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: colorScheme.primaryContainer,
                    child: app.icon != null
                        ? CachedNetworkImage(imageUrl: app.icon!, fit: BoxFit.cover)
                        : Center(child: Text(app.name[0].toUpperCase())),
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        app.description,
                        style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
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
