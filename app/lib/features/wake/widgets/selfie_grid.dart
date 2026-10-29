import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_core/saff_core.dart';
import 'package:saff_domain/saff_domain.dart';
import 'package:saff_ui/saff_ui.dart';

/// Everyone's selfies together after the reveal, with Save to gallery.
/// Gone selfies (older than the retention) show a placeholder.
class SelfieGrid extends ConsumerWidget {
  /// Creates the grid.
  const SelfieGrid({required this.selfies, required this.rows, super.key});

  /// (uid, storage path) of each selfie.
  final List<({String uid, String path})> selfies;

  /// Reveal rows, for names.
  final List<RevealRow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: SaffSpacing.md,
      crossAxisSpacing: SaffSpacing.md,
      children: [
        for (final s in selfies)
          FutureBuilder<Result<Uint8List?>>(
            future: ref.read(roundRepositoryProvider).selfieBytes(s.path),
            builder: (context, snap) {
              final bytes = snap.data?.getOrNull();
              final name =
                  rows.where((r) => r.uid == s.uid).firstOrNull?.name ?? '';
              return ClipRRect(
                borderRadius: BorderRadius.circular(SaffRadii.md),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bytes != null)
                      Image.memory(bytes, fit: BoxFit.cover)
                    else
                      ColoredBox(
                        color: context.saff.line,
                        child: Center(
                          child: Text(
                            snap.connectionState == ConnectionState.done
                                ? l10n.selfieExpired
                                : '',
                          ),
                        ),
                      ),
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(blurRadius: 4)],
                        ),
                      ),
                    ),
                    if (bytes != null)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: IconButton(
                          icon: const Icon(Icons.download, color: Colors.white),
                          tooltip: l10n.selfieSave,
                          onPressed: () async {
                            await Gal.putImageBytes(bytes);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.selfieSaved)),
                              );
                            }
                          },
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
