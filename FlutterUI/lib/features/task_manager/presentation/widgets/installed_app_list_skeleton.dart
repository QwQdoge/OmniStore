import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/skeleton.dart';

class InstalledAppListSkeleton extends StatelessWidget {
  const InstalledAppListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      prototypeItem: const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: AppCard(
          borderRadius: 8,
          child: ListTile(
            leading: Skeleton(width: 40, height: 40, borderRadius: 8),
            title: Skeleton(width: 120, height: 16),
            subtitle: Skeleton(width: double.infinity, height: 12),
            trailing: Skeleton(width: 60, height: 24, borderRadius: 6),
          ),
        ),
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: AppCard(
            borderRadius: 8,
            child: ListTile(
              leading: Skeleton(width: 40, height: 40, borderRadius: 8),
              title: Skeleton(width: 120, height: 16),
              subtitle: Skeleton(width: double.infinity, height: 12),
              trailing: Skeleton(width: 60, height: 24, borderRadius: 6),
            ),
          ),
        );
      },
    );
  }
}
