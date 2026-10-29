import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_app/features/saff/view_models/saff_actions_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/shared/failure_text.dart';
import 'package:saff_ui/saff_ui.dart';

/// Enter an invite code, confirm, join (`docs/design/flows.md` 10c).
class SaffJoinView extends ConsumerStatefulWidget {
  /// Creates the view; [code] pre-fills it (invite links).
  const SaffJoinView({this.code, super.key});

  /// Pre-filled code.
  final String? code;

  @override
  ConsumerState<SaffJoinView> createState() => _SaffJoinViewState();
}

class _SaffJoinViewState extends ConsumerState<SaffJoinView> {
  late final _code = TextEditingController(text: widget.code ?? '');

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final state = ref.watch(saffFlowProvider);
    final vm = ref.read(saffFlowProvider.notifier);
    ref.listen(saffFlowProvider.select((s) => s.joinedSaffId), (_, id) {
      if (id != null) context.go('/chat/$id');
    });
    final preview = state.preview;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinSaffTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SaffSpacing.xl),
        children: [
          if (preview == null) ...[
            Text(l10n.joinBody, style: TextStyle(color: c.muted)),
            const SizedBox(height: SaffSpacing.xl),
            TextField(
              key: const ValueKey('join-code'),
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 6,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(labelText: l10n.inviteCodeLabel),
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
              label: l10n.continueLabel,
              loading: state.running,
              onPressed: () => vm.preview(_code.text),
            ),
          ] else ...[
            Text(
              l10n.joinConfirmTitle(preview.ownerName),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: SaffSpacing.lg),
            Row(
              children: [
                for (final m in preview.members)
                  Padding(
                    padding: const EdgeInsets.only(right: SaffSpacing.sm),
                    child: SaffAvatar(
                      name: m.name,
                      colorIndex: m.avatarColor,
                      size: 48,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: SaffSpacing.sm),
            Text(
              l10n.memberCount(preview.memberCount),
              style: TextStyle(color: c.muted),
            ),
            if (state.failure != null)
              Padding(
                padding: const EdgeInsets.only(top: SaffSpacing.md),
                child: Text(
                  failureText(l10n, state.failure!),
                  style: TextStyle(color: c.error),
                ),
              ),
            const SizedBox(height: SaffSpacing.xl),
            PrimaryButton(
              label: l10n.join,
              loading: state.running,
              onPressed: () => vm.join(_code.text),
            ),
            const SizedBox(height: SaffSpacing.sm),
            OutlinedButton(onPressed: vm.reset, child: Text(l10n.notNow)),
          ],
        ],
      ),
    );
  }
}
