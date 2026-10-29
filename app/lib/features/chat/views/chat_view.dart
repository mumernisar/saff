import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/alarms/view_models/proposal_view_model.dart';
import 'package:saff_app/features/alarms/widgets/propose_sheet.dart';
import 'package:saff_app/features/chat/view_models/chat_view_model.dart';
import 'package:saff_app/features/chat/widgets/proposal_card.dart';
import 'package:saff_app/features/saff/view_models/selected_saff.dart';
import 'package:saff_app/l10n/app_localizations.dart';
import 'package:saff_app/shared/failure_text.dart';
import 'package:saff_app/shared/format.dart';
import 'package:saff_domain/saff_domain.dart';
import 'package:saff_ui/saff_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Chat tab: a list of saffs (`docs/design/flows.md` frame 6a).
class ChatListView extends ConsumerWidget {
  /// Creates the view.
  const ChatListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final saffs = ref.watch(mySaffsProvider).value ?? const <Saff>[];
    final uid = ref.watch(uidProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabChat)),
      body: saffs.isEmpty
          ? EmptyState(
              title: l10n.chatsEmptyTitle,
              message: l10n.chatsEmptyBody,
              icon: Icons.chat_bubble_outline,
            )
          : ListView(
              children: [
                for (final s in saffs)
                  Consumer(
                    builder: (context, ref, _) {
                      final members =
                          ref.watch(membersProvider(s.id)).value ?? const [];
                      final last = ref
                          .watch(messagesProvider(s.id))
                          .value
                          ?.firstOrNull;
                      final title = s.isPair
                          ? (members
                                    .where((m) => m.uid != uid)
                                    .firstOrNull
                                    ?.displayName ??
                                s.name)
                          : s.name;
                      return ListTile(
                        leading: SaffAvatar(
                          name: title,
                          colorIndex:
                              members
                                  .where((m) => m.uid != uid)
                                  .firstOrNull
                                  ?.avatarColor ??
                              0,
                          size: 44,
                        ),
                        title: Text(title),
                        subtitle: Text(
                          last == null
                              ? l10n.sayHello
                              : last.isText
                              ? (last.deleted
                                    ? l10n.messageDeleted
                                    : last.text ?? '')
                              : l10n.systemMessagePreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing:
                            last != null &&
                                !last.seenBy.contains(uid) &&
                                last.authorId != uid
                            ? Icon(
                                Icons.circle,
                                size: 12,
                                color: context.saff.accent,
                              )
                            : null,
                        onTap: () {
                          ref
                              .read(selectedSaffIdProvider.notifier)
                              .select(s.id);
                          context.go('/chat/${s.id}');
                        },
                      );
                    },
                  ),
              ],
            ),
    );
  }
}

/// A saff's conversation.
class ChatView extends ConsumerStatefulWidget {
  /// Creates the view.
  const ChatView({required this.saffId, super.key});

  /// The saff.
  final String saffId;

  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView>
    with WidgetsBindingObserver {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_presence(online: true));
  }

  Future<void> _presence({required bool online}) async {
    final uid = ref.read(uidProvider).value;
    if (uid == null) return;
    await ref
        .read(chatRepositoryProvider)
        .setPresence(widget.saffId, uid, online: online);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(_presence(online: state == AppLifecycleState.resumed));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _text.dispose();
    super.dispose();
  }

  Future<void> _call(Member m, {required bool call}) async {
    final digits = m.whatsapp.replaceAll('+', '');
    await launchUrl(
      Uri.parse(
        call ? 'https://wa.me/$digits' : 'https://wa.me/$digits',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final saffId = widget.saffId;
    final uid = ref.watch(uidProvider).value ?? '';
    final saff = ref
        .watch(mySaffsProvider)
        .value
        ?.where((s) => s.id == saffId)
        .firstOrNull;
    final members =
        ref.watch(membersProvider(saffId)).value ?? const <Member>[];
    final messages =
        ref.watch(messagesProvider(saffId)).value ?? const <ChatMessage>[];
    final proposals = <String, Proposal>{
      for (final p
          in ref.watch(proposalsProvider(saffId)).value ?? const <Proposal>[])
        p.id: p,
    };
    final alarms = ref.watch(alarmsProvider(saffId)).value ?? const <Alarm>[];
    final upcoming = ref.watch(upcomingProvider(saffId)).value ?? const [];
    final reply = ref.watch(replyTargetProvider);
    final actions = ref.read(chatActionsProvider.notifier);
    final failure = ref.watch(chatActionsProvider).failure;
    final byUid = {for (final m in members) m.uid: m};
    final others = members.where((m) => m.uid != uid).toList();
    final isPair = saff?.isPair ?? false;
    final title = saff == null
        ? ''
        : isPair
        ? (others.firstOrNull?.displayName ?? saff.name)
        : saff.name;
    final online = others.any((m) => m.online);

    ref.listen(messagesProvider(saffId), (_, next) {
      final list = next.value;
      if (list != null) unawaited(actions.markSeen(saffId, list));
    });

    final nextOcc = upcoming
        .where((o) => o.requires(uid) && o.ringAt.isAfter(DateTime.now()))
        .firstOrNull;
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/chat')),
        title: GestureDetector(
          onTap: () => context.push('/saff/$saffId'),
          child: Row(
            children: [
              SaffAvatar(
                name: title,
                colorIndex: others.firstOrNull?.avatarColor ?? 0,
                size: 36,
              ),
              const SizedBox(width: SaffSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 17),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      online ? l10n.online : l10n.memberCount(members.length),
                      style: TextStyle(fontSize: 12, color: c.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (isPair && others.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.chat),
              tooltip: l10n.whatsappChat,
              onPressed: () => _call(others.first, call: false),
            ),
            IconButton(
              icon: const Icon(Icons.call),
              tooltip: l10n.whatsappCall,
              onPressed: () => _call(others.first, call: true),
            ),
          ] else if (saff?.whatsappGroupLink != null)
            IconButton(
              icon: const Icon(Icons.chat),
              onPressed: () => launchUrl(
                Uri.parse(saff!.whatsappGroupLink!),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          if (nextOcc != null)
            Container(
              width: double.infinity,
              color: c.soft,
              padding: const EdgeInsets.symmetric(
                horizontal: SaffSpacing.lg,
                vertical: SaffSpacing.sm,
              ),
              child: Text(
                l10n.pinnedAlarm(
                  nextOcc.alarmName,
                  clock(nextOcc.ringAt),
                  untilText(l10n, nextOcc.ringAt.difference(DateTime.now())),
                ),
              ),
            ),
          Expanded(
            child: messages.isEmpty
                ? EmptyState(
                    title: l10n.sayHello,
                    icon: Icons.chat_bubble_outline,
                  )
                : ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.all(SaffSpacing.md),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final m = messages[i];
                      return _MessageRow(
                        message: m,
                        mine: m.authorId == uid,
                        author: byUid[m.authorId],
                        showName: !isPair && m.authorId != uid,
                        everyoneSeen: members.every(
                          (x) =>
                              x.uid == m.authorId || m.seenBy.contains(x.uid),
                        ),
                        proposals: proposals,
                        saffId: saffId,
                        members: members,
                        byUid: byUid,
                        allMessages: messages,
                        uid: uid,
                      );
                    },
                  ),
          ),
          if (failure != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SaffSpacing.lg),
              child: Text(
                failureText(l10n, failure),
                style: TextStyle(color: c.error),
              ),
            ),
          if (reply != null)
            ListTile(
              dense: true,
              tileColor: c.soft,
              title: Text(
                reply.text ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () =>
                    ref.read(replyTargetProvider.notifier).set(null),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(SaffSpacing.sm),
              child: Row(
                children: [
                  IconButton(
                    key: const ValueKey('chat-plus'),
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => _plusSheet(context, alarms, upcoming, uid),
                  ),
                  Expanded(
                    child: TextField(
                      key: const ValueKey('chat-input'),
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: l10n.messageHint,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('chat-send'),
                    icon: Icon(Icons.send, color: c.accent),
                    onPressed: () {
                      final text = _text.text;
                      _text.clear();
                      final r = ref.read(replyTargetProvider);
                      ref.read(replyTargetProvider.notifier).set(null);
                      unawaited(
                        actions.send(saffId, text, replyToId: r?.id),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _plusSheet(
    BuildContext context,
    List<Alarm> alarms,
    List<Occurrence> upcoming,
    String uid,
  ) {
    final l10n = AppLocalizations.of(context);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.alarm_add),
              title: Text(l10n.proposeAlarm),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(showProposeSheet(context, saffId: widget.saffId));
              },
            ),
            for (final a in alarms.where((a) => a.status != 'deleted')) ...[
              ListTile(
                leading: const Icon(Icons.edit_calendar),
                title: Text(l10n.changeAlarm(a.name)),
                onTap: () {
                  Navigator.pop(ctx);
                  unawaited(
                    showProposeSheet(
                      context,
                      saffId: widget.saffId,
                      existing: a,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.deleteAlarm(a.name)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(proposalViewModelProvider.notifier)
                      .delete(widget.saffId, a.id);
                },
              ),
            ],
            ListTile(
              leading: const Icon(Icons.event_busy),
              title: Text(l10n.skipMorning),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(_skipSheet(context, upcoming, uid));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _skipSheet(
    BuildContext context,
    List<Occurrence> upcoming,
    String uid,
  ) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final minNotice = ref
        .read(environmentConfigProvider)
        .constants
        .skipMinNotice;
    final options = upcoming
        .where((o) => o.status == 'planned' && o.participantIds.contains(uid))
        .take(5)
        .toList();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(SaffSpacing.lg),
              child: Text(
                l10n.skipMorning,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (options.isEmpty) Text(l10n.nothingToSkip),
            for (final o in options)
              Builder(
                builder: (_) {
                  final tooLate =
                      o.ringAt.difference(DateTime.now().toUtc()) < minNotice;
                  final skipped = o.skippedIds.contains(uid);
                  return ListTile(
                    enabled: !tooLate && !skipped,
                    title: Text(
                      '${weekday(o.ringAt)} · ${o.alarmName} ${clock(o.ringAt)}',
                    ),
                    subtitle: tooLate
                        ? Text(l10n.skipTooLateHint(weekday(o.ringAt)))
                        : skipped
                        ? Text(l10n.alreadySkipping)
                        : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await ref
                          .read(proposalViewModelProvider.notifier)
                          .skip(widget.saffId, o.id);
                      if (!ok && context.mounted) {
                        final f = ref.read(proposalViewModelProvider).failure;
                        if (f != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(failureText(l10n, f))),
                          );
                        }
                      }
                    },
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(SaffSpacing.lg),
              child: Text(
                l10n.skipFootnote,
                style: TextStyle(color: c.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageRow extends ConsumerWidget {
  const _MessageRow({
    required this.message,
    required this.mine,
    required this.author,
    required this.showName,
    required this.everyoneSeen,
    required this.proposals,
    required this.saffId,
    required this.members,
    required this.byUid,
    required this.allMessages,
    required this.uid,
  });

  final ChatMessage message;
  final bool mine;
  final Member? author;
  final bool showName;
  final bool everyoneSeen;
  final Map<String, Proposal> proposals;
  final String saffId;
  final List<Member> members;
  final Map<String, Member> byUid;
  final List<ChatMessage> allMessages;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final c = context.saff;
    final m = message;
    String nameOf(Object? id) => byUid['$id']?.displayName ?? l10n.deletedUser;

    Widget system(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: SaffSpacing.sm),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 13),
        ),
      ),
    );

    switch (m.type) {
      case 'proposal':
        final p = proposals['${m.payload['proposalId']}'];
        if (p == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: SaffSpacing.sm),
          child: ProposalCard(
            saffId: saffId,
            proposal: p,
            proposerName: nameOf(p.proposerId),
            members: members,
          ),
        );
      case 'proposal_outcome':
        return const SizedBox.shrink();
      case 'member_joined':
        return system(l10n.memberJoined(nameOf(m.payload['uid'])));
      case 'member_left':
        return system(l10n.memberLeft(nameOf(m.payload['uid'])));
      case 'member_removed':
        return system(l10n.memberRemoved(nameOf(m.payload['uid'])));
      case 'pack_added':
        return system(
          l10n.packAdded(
            '${m.payload['by'] ?? ''}',
            '${m.payload['title'] ?? ''}',
            (m.payload['cards'] as num?)?.toInt() ?? 0,
          ),
        );
      case 'skip':
        return system(l10n.memberSkipping(nameOf(m.payload['uid'])));
      case 'round_result':
        final winner = m.payload['winnerUid'];
        final players = m.payload['players'] ?? 0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: SaffSpacing.sm),
          child: SaffCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.roundResultTitle('${m.payload['alarmName'] ?? ''}'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  winner == null
                      ? l10n.roundResultNoWinner(players as int)
                      : l10n.roundResultWinner(
                          nameOf(winner),
                          players as int,
                        ),
                  style: TextStyle(color: c.muted),
                ),
              ],
            ),
          ),
        );
    }
    if (m.deleted) return system(l10n.messageDeleted);
    final reply = m.replyToId == null
        ? null
        : allMessages.where((x) => x.id == m.replyToId).firstOrNull;
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.75,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? c.accent : c.surface,
        borderRadius: BorderRadius.circular(SaffRadii.md),
        border: mine ? null : Border.all(color: c.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showName)
            Text(
              nameOf(m.authorId),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: mine ? const Color(0xFF161A22) : c.muted,
              ),
            ),
          if (reply != null)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: c.muted, width: 2)),
              ),
              child: Text(
                reply.text ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: c.muted),
              ),
            ),
          Text(
            m.text ?? '',
            style: TextStyle(
              fontSize: 16,
              color: mine ? const Color(0xFF161A22) : c.text,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                clock(m.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: mine ? const Color(0xFF4A4232) : c.muted,
                ),
              ),
              if (mine) ...[
                const SizedBox(width: 4),
                Icon(
                  m.pending
                      ? Icons.schedule
                      : everyoneSeen
                      ? Icons.done_all
                      : Icons.done,
                  size: 14,
                  color: everyoneSeen && !m.pending
                      ? const Color(0xFF1B5E8E)
                      : const Color(0xFF4A4232),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Dismissible(
          key: ValueKey('swipe-${m.id}'),
          direction: DismissDirection.startToEnd,
          confirmDismiss: (_) async {
            ref.read(replyTargetProvider.notifier).set(m);
            return false;
          },
          child: GestureDetector(
            onLongPress: () => _seenSheet(context, ref),
            child: bubble,
          ),
        ),
      ),
    );
  }

  void _seenSheet(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final seen = members.where(
      (x) => message.seenBy.contains(x.uid) && x.uid != message.authorId,
    );
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(title: Text(l10n.seenBy)),
              if (seen.isEmpty) ListTile(title: Text(l10n.seenByNobody)),
              for (final m in seen) ListTile(title: Text(m.displayName)),
              if (mine && !message.deleted)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.deleteMessage),
                  onTap: () {
                    Navigator.pop(ctx);
                    unawaited(
                      ref
                          .read(chatActionsProvider.notifier)
                          .delete(saffId, message.id),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
