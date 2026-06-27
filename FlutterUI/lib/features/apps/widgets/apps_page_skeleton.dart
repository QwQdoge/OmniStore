import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/skeleton.dart';

class AppsPageSkeleton extends StatelessWidget {
  const AppsPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      prototypeItem: const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: AppCard(
          child: ListTile(
            leading: Skeleton(width: 40, height: 40, borderRadius: 12),
            title: Skeleton(width: 120, height: 16),
            subtitle: Skeleton(
              width: double.infinity,
              height: 12,
              borderRadius: 8,
            ),
            trailing: Skeleton(width: 60, height: 24, borderRadius: 12),
          ),
        ),
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: ListTile(
              leading: Skeleton(width: 40, height: 40, borderRadius: 12),
              title: Skeleton(width: 120, height: 16),
              subtitle: Skeleton(
                width: double.infinity,
                height: 12,
                borderRadius: 8,
              ),
              trailing: Skeleton(width: 60, height: 24, borderRadius: 12),
            ),
          ),
        );
      },
    );
  }
}
