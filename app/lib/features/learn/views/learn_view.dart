import 'package:flutter/material.dart';
import 'package:saff_app/l10n/app_localizations.dart';

/// Placeholder for the Learn tab.
class LearnView extends StatelessWidget {
  /// Creates the view.
  const LearnView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabLearn)),
      body: Center(child: Text(l10n.comingSoon)),
    );
  }
}
