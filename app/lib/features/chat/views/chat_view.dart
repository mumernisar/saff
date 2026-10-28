import 'package:flutter/material.dart';
import 'package:saff_app/l10n/app_localizations.dart';

/// Placeholder for the Chat tab.
class ChatView extends StatelessWidget {
  /// Creates the view.
  const ChatView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabChat)),
      body: Center(child: Text(l10n.comingSoon)),
    );
  }
}
