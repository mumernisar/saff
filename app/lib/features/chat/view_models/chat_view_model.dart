import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/src/providers/stream_provider.dart';
import 'package:saff_app/di/providers.dart';
import 'package:saff_app/features/auth/view_models/auth_view_model.dart';
import 'package:saff_core/saff_core.dart';
import 'package:saff_domain/saff_domain.dart';

/// Live messages of a saff, newest first.
final StreamProviderFamily<List<ChatMessage>, String> messagesProvider =
    StreamProvider.autoDispose.family<List<ChatMessage>, String>(
      (ref, saffId) => ref.watch(chatRepositoryProvider).watch(saffId),
    );

/// A message the user is replying to.
class ReplyTarget extends Notifier<ChatMessage?> {
  @override
  ChatMessage? build() => null;

  /// Sets or clears the target.
  // ignore: use_setters_to_change_properties
  void set(ChatMessage? m) => state = m;
}

/// Provider of the reply target.
final replyTargetProvider = NotifierProvider<ReplyTarget, ChatMessage?>(
  ReplyTarget.new,
);

/// Chat actions for one saff.
class ChatActions extends Notifier<ActionState> {
  @override
  ActionState build() => const ActionState();

  /// Sends [text].
  Future<void> send(String saffId, String text, {String? replyToId}) async {
    final uid = ref.read(uidProvider).value;
    if (uid == null || text.trim().isEmpty) return;
    final r = await ref
        .read(chatRepositoryProvider)
        .send(saffId, uid, text, replyToId: replyToId);
    state = ActionState(failure: r is Err<void> ? r.failure : null);
  }

  /// Marks other people's messages as seen.
  Future<void> markSeen(String saffId, List<ChatMessage> messages) async {
    final uid = ref.read(uidProvider).value;
    if (uid == null) return;
    final unseen = [
      for (final m in messages)
        if (!m.seenBy.contains(uid) && !m.pending) m.id,
    ];
    if (unseen.isEmpty) return;
    await ref.read(chatRepositoryProvider).markSeen(saffId, uid, unseen);
  }

  /// Deletes an own message.
  Future<void> delete(String saffId, String id) async {
    final r = await ref.read(chatRepositoryProvider).delete(saffId, id);
    state = ActionState(failure: r is Err<void> ? r.failure : null);
  }
}

/// Provider of [ChatActions].
final chatActionsProvider = NotifierProvider<ChatActions, ActionState>(
  ChatActions.new,
);
