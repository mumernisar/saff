import 'package:flutter/material.dart';
import 'package:saff_app/l10n/app_localizations.dart';

/// Placeholder for the Stats tab.
class StatsView extends StatelessWidget {
  /// Creates the view.
  const StatsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabStats)),
      body: Center(child: Text(l10n.comingSoon)),
    );
  }
}
