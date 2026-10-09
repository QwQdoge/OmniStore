import 'package:flutter/material.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/core/widgets/empty_state.dart';

class AppsPageEmptyState extends StatelessWidget {
  const AppsPageEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return EmptyState(icon: Icons.inventory_2_outlined, title: l10n.noResults);
  }
}
