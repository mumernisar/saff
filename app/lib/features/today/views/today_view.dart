import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:saff_app/features/today/view_models/emulator_status_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';

/// Placeholder for the Today tab. Shows whether the emulators are reachable
/// (dev builds only).
class TodayView extends ConsumerWidget {
  /// Creates the view.
  const TodayView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final status = ref.watch(emulatorStatusProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabToday)),
      body: Center(
        child: status.when(
          loading: () => const CircularProgressIndicator(),
          error: (error, _) => Text(l10n.emulatorsCheckFailed),
          data: (reaches) {
            if (reaches == null) return Text(l10n.emulatorsNotUsed);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final r in reaches)
                  ListTile(
                    key: ValueKey('emulator-${r.name}'),
                    leading: Icon(
                      r.reachable ? Icons.check_circle : Icons.cancel,
                    ),
                    title: Text(r.name),
                    subtitle: Text(
                      r.reachable
                          ? l10n.emulatorReachable
                          : l10n.emulatorUnreachable,
                    ),
                  ),
                TextButton(
                  onPressed: () =>
                      ref.read(emulatorStatusProvider.notifier).recheck(),
                  child: Text(l10n.emulatorsRecheck),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
