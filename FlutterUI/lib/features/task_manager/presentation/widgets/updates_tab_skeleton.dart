import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_card.dart';
import 'package:frontend/core/widgets/skeleton.dart';

class UpdatesTabSkeleton extends StatelessWidget {
  const UpdatesTabSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    const skeletonItem = Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: AppCard(
        borderRadius: 16,
        child: ListTile(
          leading: Skeleton(width: 44, height: 44, borderRadius: 16),
          title: Skeleton(width: 140, height: 16),
          subtitle: Padding(
            padding: EdgeInsets.only(top: 4.0),
            child: Row(
              children: [
                Skeleton(width: 60, height: 20, borderRadius: 10),
                SizedBox(width: 8),
                Skeleton(width: 120, height: 14),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Skeleton(width: 40, height: 40, borderRadius: 20),
              SizedBox(width: 8),
              Skeleton(width: 80, height: 40, borderRadius: 20),
            ],
          ),
        ),
      ),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Skeleton(width: 150, height: 20),
              const Skeleton(width: 120, height: 40, borderRadius: 20),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 6,
            prototypeItem: skeletonItem,
            itemBuilder: (context, index) => skeletonItem,
          ),
        ),
      ],
    );
  }
}
