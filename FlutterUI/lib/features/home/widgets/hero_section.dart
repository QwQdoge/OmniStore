import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/app_package.dart';
import 'package:frontend/features/home/widgets/banner_card.dart';
import 'package:frontend/core/widgets/section_header.dart';

class HeroSection extends StatelessWidget {
  final List<AppPackage> apps;
  final ScrollController scrollController;

  const HeroSection({
    super.key,
    required this.apps,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        SectionHeader(title: AppLocalizations.of(context)!.featured),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            child: ListView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              scrollDirection: Axis.horizontal,
              // ⚡ Bolt: Use prototypeItem for better scroll virtualization and scrollbar accuracy
              prototypeItem: const SizedBox(
                width: 460, // 440 + 20 (manual spacing)
                child: SizedBox.shrink(),
              ),
              itemCount: apps.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: BannerCard(app: apps[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
