import 'package:flutter/material.dart';
import 'package:frontend/core/widgets/app_card.dart';

class WelcomeConfigCard extends StatelessWidget {
  final Widget child;

  const WelcomeConfigCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: child,
      ),
    );
  }
}
