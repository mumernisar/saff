import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/imports/view_models/import_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/shared/failure_text.dart';
import 'package:saff_core/saff_core.dart';
import 'package:saff_ui/saff_ui.dart';

/// Mornings settings of a saff: card mix, Anki import, imported packs
/// (`docs/PRODUCT.md` §13, `docs/CONTENT.md` §6).
class MorningsView extends ConsumerWidget {
  /// Creates the view.
  const MorningsView({required this.saffId, super.key});

  /// The saff.
  final String saffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final uid = ref.watch(uidProvider).value;
    final packs = ref.watch(packsProvider(saffId)).value ?? const [];
    final flow = ref.watch(importViewModelProvider);
    final status = ref.watch(importStatusProvider).value;
    final vm = ref.read(importViewModelProvider.notifier);
    final saff = ref
        .watch(mySaffsProvider)
        .value
        ?.where((s) => s.id == saffId)
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.morningsTitle)),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(l10n.customMix),
            subtitle: Text(l10n.customMixBody),
            value: saff?.customMix ?? false,
            onChanged: (v) => vm.setCustomMix(saffId, on: v),
          ),
          SectionHeader(l10n.importedPacks),
          for (final p in packs)
            ListTile(
              leading: const Icon(Icons.style),
              title: Text(p.title),
              subtitle: Text(l10n.cardCount(p.cardCount)),
              trailing:
                  p.createdBy == uid || (saff?.isOwner(uid ?? '') ?? false)
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => vm.delete(saffId, p.id),
                    )
                  : null,
            ),
          if (packs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(SaffSpacing.lg),
              child: Text(
                l10n.noImportedPacks,
                style: TextStyle(color: c.muted),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(SaffSpacing.lg),
            child: PrimaryButton(
              label: l10n.importAnki,
              loading: flow.running,
              onPressed: () => vm.pickAndUpload(saffId),
            ),
          ),
          if (flow.failure != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SaffSpacing.lg),
              child: Text(
                failureText(l10n, flow.failure!),
                style: TextStyle(color: c.error),
              ),
            ),
          if (status != null)
            Padding(
              padding: const EdgeInsets.all(SaffSpacing.lg),
              child: SaffCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(switch (status.status) {
                      'done' => l10n.importDone(status.cards),
                      'failed' => failureText(
                        l10n,
                        AppFailure.fromCode(
                          FailureCode.fromWire(status.errorCode ?? '') ??
                              FailureCode.importCorrupt,
                        ),
                      ),
                      _ => l10n.importParsing,
                    }, style: const TextStyle(fontWeight: FontWeight.w700)),
                    for (final s in status.sample)
                      Text(
                        '${s.question} → ${s.answer}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (status.warnings.isNotEmpty)
                      Text(
                        l10n.importWarnings(status.warnings.join(', ')),
                        style: TextStyle(color: c.muted),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
