/// A saff the user belongs to.
final class Saff {
  /// Creates a saff.
  const Saff({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.memberIds,
    required this.memberLimit,
    required this.inviteCode,
    required this.streak,
    this.whatsappGroupLink,
    this.ended = false,
    this.overLimit = false,
    this.customMix = false,
  });

  /// Document id.
  final String id;

  /// Display name.
  final String name;

  /// The owner's uid.
  final String ownerId;

  /// Member uids.
  final List<String> memberIds;

  /// Maximum members.
  final int memberLimit;

  /// Current invite code.
  final String inviteCode;

  /// Current saff streak.
  final int streak;

  /// Optional WhatsApp group link.
  final String? whatsappGroupLink;

  /// Whether the saff has ended (read-only).
  final bool ended;

  /// Whether the owner's plan no longer covers the member count.
  final bool overLimit;

  /// Whether imported packs feed the rounds.
  final bool customMix;

  /// A pair has exactly two members.
  bool get isPair => memberIds.length == 2;

  /// Number of members.
  int get memberCount => memberIds.length;

  /// Whether [uid] owns the saff.
  bool isOwner(String uid) => ownerId == uid;
}

/// One member of a saff.
final class Member {
  /// Creates a member.
  const Member({
    required this.uid,
    required this.displayName,
    required this.avatarColor,
    required this.isOwner,
    this.whatsapp = '',
    this.online = false,
    this.lastSeen,
  });

  /// The user's uid.
  final String uid;

  /// Display name.
  final String displayName;

  /// Index into the avatar palette.
  final int avatarColor;

  /// Whether this member owns the saff.
  final bool isOwner;

  /// WhatsApp number in E.164, visible only inside the saff.
  final String whatsapp;

  /// Whether the member is currently in the app.
  final bool online;

  /// When the member was last seen.
  final DateTime? lastSeen;
}

/// The signed-in user's own profile.
final class Profile {
  /// Creates a profile.
  const Profile({
    required this.uid,
    required this.displayName,
    required this.avatarColor,
    required this.saffIds,
    this.whatsapp = '',
  });

  /// The user's uid.
  final String uid;

  /// Display name.
  final String displayName;

  /// Avatar palette index.
  final int avatarColor;

  /// Saffs the user belongs to.
  final List<String> saffIds;

  /// WhatsApp number (from the private contact doc).
  final String whatsapp;
}

/// What the join confirmation shows before joining.
final class InvitePreview {
  /// Creates a preview.
  const InvitePreview({
    required this.saffId,
    required this.name,
    required this.ownerName,
    required this.memberCount,
    required this.memberLimit,
    required this.members,
  });

  /// Saff id.
  final String saffId;

  /// Saff name.
  final String name;

  /// Owner's display name.
  final String ownerName;

  /// Current members.
  final int memberCount;

  /// Limit of members.
  final int memberLimit;

  /// Names and avatar colours of members.
  final List<({String name, int avatarColor})> members;
}
