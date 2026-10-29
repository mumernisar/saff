import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_app/features/saff/view_models/saff_actions_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/shared/failure_text.dart';
import 'package:saff_ui/saff_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Start a saff: creates it, then shows the invite code
/// (`docs/design/flows.md` frames 10a, 10b).
class SaffNewView extends ConsumerStatefulWidget {
  /// Creates the view.
  const SaffNewView({super.key});

  @override
  ConsumerState<SaffNewView> createState() => _SaffNewViewState();
}

class _SaffNewViewState extends ConsumerState<SaffNewView> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final state = ref.watch(saffFlowProvider);
    final vm = ref.read(saffFlowProvider.notifier);
    final code = state.inviteCode;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.startSaff)),
      body: ListView(
        padding: const EdgeInsets.all(SaffSpacing.xl),
        children: [
          if (code == null) ...[
            Text(l10n.saffNewBody, style: TextStyle(color: c.muted)),
            const SizedBox(height: SaffSpacing.xl),
            TextField(
              key: const ValueKey('saff-name'),
              controller: _name,
              maxLength: 40,
              decoration: InputDecoration(labelText: l10n.saffNameOptional),
            ),
            if (state.failure != null)
              Padding(
                padding: const EdgeInsets.only(bottom: SaffSpacing.md),
                child: Text(
                  failureText(l10n, state.failure!),
                  style: TextStyle(color: c.error),
                ),
              ),
            const SizedBox(height: SaffSpacing.lg),
            PrimaryButton(
              label: l10n.createSaff,
              loading: state.running,
              onPressed: () => vm.create(
                name: _name.text.trim().isEmpty ? null : _name.text.trim(),
              ),
            ),
          ] else ...[
            Text(
              l10n.inviteTitle,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: SaffSpacing.lg),
            SaffCard(
              child: Center(
                child: Text(
                  code,
                  key: const ValueKey('invite-code'),
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ),
            const SizedBox(height: SaffSpacing.lg),
            PrimaryButton(
              label: l10n.shareInvite,
              onPressed: () => unawaited(
                launchUrl(
                  Uri.parse(
                    'https://wa.me/?text=${Uri.encodeComponent(l10n.inviteMessage(code))}',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
            const SizedBox(height: SaffSpacing.sm),
            OutlinedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: code));
                messenger.showSnackBar(
                  SnackBar(content: Text(l10n.codeCopied)),
                );
              },
              child: Text(l10n.copyCode),
            ),
            const SizedBox(height: SaffSpacing.xl),
            Text(
              l10n.waitingForSomeoneToJoin,
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: SaffSpacing.lg),
            OutlinedButton(
              onPressed: () => context.go('/today'),
              child: Text(l10n.done),
            ),
          ],
        ],
      ),
    );
  }
}
