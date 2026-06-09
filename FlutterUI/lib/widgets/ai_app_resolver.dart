import "package:frontend/data/repositories/package_repository.dart";
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/features/explore/presentation/pages/details_page.dart';

class AIAppResolver extends StatefulWidget {
  final String aiText;
  final String jsonPrefix;

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
    _resolve();
  }

  Future<void> _resolve() async {
    if (!widget.aiText.contains(widget.jsonPrefix)) return;

    setState(() => _isLoading = true);
    try {
      final jsonPart = widget.aiText.split(widget.jsonPrefix).last.trim();
      final List<dynamic> names = jsonDecode(jsonPart);

      final packageRepo = context.read<PackageRepository>();
      List<AppPackage> apps = [];

      for (var name in names) {
        final results = await packageRepo.searchPackages(name.toString());
        if (results.isNotEmpty) {
          apps.add(results[0]);
        }
      }

      if (mounted) {
        setState(() {
          _resolvedApps = apps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const LinearProgressIndicator();
    if (_resolvedApps.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.relatedApps,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _resolvedApps.length,
            itemBuilder: (context, index) => ActionChip(
              label: Text(_resolvedApps[index].name),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      AppDetailsPage(app: _resolvedApps[index]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
