import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_ui/saff_ui.dart';

/// Saff Plus status (`docs/PRODUCT.md` §15). Purchasing needs Google Play
/// products; until they exist the page explains the plan and offers the
/// emulator-only switch in dev builds.
class PlusView extends ConsumerWidget {
  /// Creates the view.
  const PlusView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final e = ref.watch(entitlementProvider).value;
    final isDev = ref.watch(environmentConfigProvider).isDev;
    final plus = e?.plan == 'plus';
    return Scaffold(
      appBar: AppBar(title: Text(l10n.plusTitle)),
      body: ListView(
        padding: const EdgeInsets.all(SaffSpacing.xl),
        children: [
          SaffCard(
            color: plus ? c.soft : null,
            child: Text(
              plus
                  ? (e?.status == 'grace' ? l10n.plusGrace : l10n.plusActive)
                  : l10n.plusFree,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: SaffSpacing.lg),
          Text(l10n.plusBenefits, style: TextStyle(color: c.muted)),
          const SizedBox(height: SaffSpacing.lg),
          Text(l10n.plusNoPurchaseYet, style: TextStyle(color: c.muted)),
          if (isDev) ...[
            const SizedBox(height: SaffSpacing.xl),
            OutlinedButton(
              onPressed: () =>
                  ref.read(saffRepositoryProvider).devSetPlus(on: !plus),
              child: Text(plus ? l10n.devRevokePlus : l10n.devGrantPlus),
            ),
          ],
        ],
      ),
    );
  }
}
