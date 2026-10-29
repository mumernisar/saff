import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/saff/view_models/saff_actions_view_model.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/shared/failure_text.dart';
import 'package:saff_ui/saff_ui.dart';

/// One saff: members, invite, rename, leave (`docs/PRODUCT.md` §3).
class SaffDetailView extends ConsumerWidget {
  /// Creates the view.
  const SaffDetailView({required this.saffId, super.key});

  /// The saff.
  final String saffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final uid = ref.watch(uidProvider).value;
    final saff = ref
        .watch(mySaffsProvider)
        .value
        ?.where((s) => s.id == saffId)
        .firstOrNull;
    final members = ref.watch(membersProvider(saffId)).value ?? const [];
    final manage = ref.watch(saffManageProvider);
    final vm = ref.read(saffManageProvider.notifier);
    if (saff == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    final owner = uid != null && saff.isOwner(uid);

    Future<void> confirm(
      String title,
      Future<bool> Function() action, {
      bool leave = false,
    }) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.confirm),
            ),
          ],
        ),
      );
      if (ok != true) return;
      final done = await action();
      if (done && leave && context.mounted) context.go('/today');
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(saff.name),
        actions: [
          if (owner)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final ctl = TextEditingController(text: saff.name);
                final name = await showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l10n.renameSaff),
                    content: TextField(controller: ctl, maxLength: 40),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, ctl.text),
                        child: Text(l10n.save),
                      ),
                    ],
                  ),
                );
                if (name != null && name.trim().isNotEmpty) {
                  unawaited(vm.rename(saffId, name.trim()));
                }
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          if (manage.failure != null)
            Padding(
              padding: const EdgeInsets.all(SaffSpacing.lg),
              child: Text(
                failureText(l10n, manage.failure!),
                style: TextStyle(color: c.error),
              ),
            ),
          SectionHeader(l10n.members),
          for (final m in members)
            ListTile(
              leading: SaffAvatar(
                name: m.displayName,
                colorIndex: m.avatarColor,
              ),
              title: Text(m.displayName),
              subtitle: m.isOwner ? Text(l10n.ownerLabel) : null,
              trailing: owner && m.uid != uid
                  ? IconButton(
                      icon: const Icon(Icons.person_remove),
                      onPressed: () => confirm(
                        l10n.removeMemberConfirm(m.displayName),
                        () => vm.remove(saffId, m.uid),
                      ),
                    )
                  : null,
            ),
          SectionHeader(l10n.inviteTitle),
          ListTile(
            title: Text(
              saff.inviteCode,
              style: const TextStyle(
                fontSize: 28,
                letterSpacing: 4,
                fontWeight: FontWeight.w800,
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () => Clipboard.setData(
                ClipboardData(text: saff.inviteCode),
              ),
            ),
          ),
          if (owner)
            ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(l10n.regenerateInvite),
              onTap: () => vm.regenerate(saffId),
            ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.logout, color: c.error),
            title: Text(l10n.leaveSaff, style: TextStyle(color: c.error)),
            onTap: () => confirm(
              l10n.leaveSaffConfirm(saff.name),
              () => vm.leave(saffId),
              leave: true,
            ),
          ),
        ],
      ),
    );
  }
}
