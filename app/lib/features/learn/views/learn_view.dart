import 'package:flutter/material.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_ui/saff_ui.dart';

/// The Learn tab. The learning track needs the Quran content gateway
/// (credentials pending), so it shows an honest empty state for now.
class LearnView extends StatelessWidget {
  /// Creates the view.
  const LearnView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabLearn)),
      body: EmptyState(
        title: l10n.learnEmptyTitle,
        message: l10n.learnEmptyBody,
        icon: Icons.school_outlined,
      ),
    );
  }
}
