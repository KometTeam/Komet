enum AdminChatKind { channel, group }

enum AdminRight {
  editInfo(8),
  createPosts(32 | 256),
  editPosts(512),
  deletePosts(1024),
  deleteMessages(1),
  pinMessages(16),
  manageFollowers(2 | 128),
  manageMembers(2),
  editLink(128),
  viewStats(2048),
  manageAdmins(4);

  const AdminRight(this.mask);

  final int mask;
}

class AdminRights {
  static const int ownerBits = 4095;
  static const int _groupBaseBits = 32 | 64;

  final int bits;

  const AdminRights(this.bits);

  static List<List<AdminRight>> layoutOf(AdminChatKind kind) => switch (kind) {
    AdminChatKind.channel => const [
      [AdminRight.editInfo],
      [
        AdminRight.createPosts,
        AdminRight.editPosts,
        AdminRight.deletePosts,
        AdminRight.pinMessages,
      ],
      [AdminRight.manageFollowers],
      [AdminRight.viewStats],
      [AdminRight.manageAdmins],
    ],
    AdminChatKind.group => const [
      [AdminRight.editInfo],
      [AdminRight.deleteMessages, AdminRight.pinMessages],
      [AdminRight.manageMembers, AdminRight.editLink],
      [AdminRight.manageAdmins],
    ],
  };

  static AdminRights appointDefaults(AdminChatKind kind) => switch (kind) {
    AdminChatKind.channel => _union(layoutOf(kind).expand((group) => group), 0),
    AdminChatKind.group => _union(const [
      AdminRight.editInfo,
      AdminRight.deleteMessages,
      AdminRight.pinMessages,
      AdminRight.manageMembers,
    ], _groupBaseBits),
  };

  static AdminRights _union(Iterable<AdminRight> rights, int base) =>
      AdminRights(rights.fold(base, (bits, right) => bits | right.mask));

  bool has(AdminRight right) => bits & right.mask == right.mask;

  AdminRights withRight(AdminRight right, bool enabled) =>
      AdminRights(enabled ? bits | right.mask : bits & ~right.mask);

  bool isEmptyFor(AdminChatKind kind) => layoutOf(
    kind,
  ).expand((group) => group).every((right) => bits & right.mask == 0);

  @override
  bool operator ==(Object other) => other is AdminRights && other.bits == bits;

  @override
  int get hashCode => bits.hashCode;
}
