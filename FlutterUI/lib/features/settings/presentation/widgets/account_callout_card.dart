import 'package:flutter/material.dart';
import 'package:frontend/features/ai/widgets/ai_mark.dart';

class AccountCalloutCard extends StatelessWidget {
  final Color background;
  final String title;
  final String detail;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onPressed;

  const AccountCalloutCard({
    super.key,
    required this.background,
    required this.title,
    required this.detail,
    required this.actionLabel,
    required this.actionIcon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 470;
          final detailColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(detail),
            ],
          );
          final action = FilledButton.tonalIcon(
            onPressed: onPressed,
            icon: Icon(actionIcon),
            label: Text(actionLabel),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AiMark(size: 48),
                    const SizedBox(width: 14),
                    Expanded(child: detailColumn),
                  ],
                ),
                const SizedBox(height: 12),
                action,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AiMark(size: 48),
              const SizedBox(width: 14),
              Expanded(child: detailColumn),
              const SizedBox(width: 12),
              action,
            ],
          );
        },
      ),
    );
  }}
