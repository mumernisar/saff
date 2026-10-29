/// A chat message or system card.
final class ChatMessage {
  /// Creates a message.
  const ChatMessage({
    required this.id,
    required this.type,
    required this.authorId,
    required this.createdAt,
    required this.seenBy,
    this.text,
    this.replyToId,
    this.payload = const {},
    this.deleted = false,
    this.pending = false,
  });

  /// Document id.
  final String id;

  /// `text` or a system type (`proposal`, `member_joined`, ...).
  final String type;

  /// Author uid, or `system`.
  final String authorId;

  /// Server time; the local time while [pending].
  final DateTime createdAt;

  /// uids that have seen it.
  final Set<String> seenBy;

  /// Text of a `text` message.
  final String? text;

  /// The message replied to.
  final String? replyToId;

  /// System payload.
  final Map<String, Object?> payload;

  /// Whether the author deleted it.
  final bool deleted;

  /// Whether the server has not confirmed the write yet.
  final bool pending;

  /// Whether this is a person's text message.
  bool get isText => type == 'text';
}
