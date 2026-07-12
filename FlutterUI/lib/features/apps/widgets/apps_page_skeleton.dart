import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/skeleton.dart';

class AppsPageSkeleton extends StatelessWidget {
  const AppsPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      prototypeItem: const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: AppCard(
          child: ListTile(
            leading: Skeleton(width: 40, height: 40, borderRadius: 16),
            title: Skeleton(width: 120, height: 16),
            subtitle: Row(
              children: [
                Skeleton(width: 40, height: 12, borderRadius: 16),
                SizedBox(width: 8),
                Skeleton(width: 60, height: 12, borderRadius: 16),
                SizedBox(width: 8),
                Expanded(child: Skeleton(height: 12, borderRadius: 16)),
              ],
            ),
          ),
        ),
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: ListTile(
              leading: Skeleton(width: 40, height: 40, borderRadius: 16),
              title: Skeleton(width: 120, height: 16),
              subtitle: Row(
                children: [
                  Skeleton(width: 40, height: 12, borderRadius: 16),
                  SizedBox(width: 8),
                  Skeleton(width: 60, height: 12, borderRadius: 16),
                  SizedBox(width: 8),
                  Expanded(child: Skeleton(height: 12, borderRadius: 16)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
