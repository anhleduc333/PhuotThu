enum TripMemberRole { owner, leader, member }

extension TripMemberRoleX on TripMemberRole {
  String get key {
    switch (this) {
      case TripMemberRole.owner:
        return 'owner';
      case TripMemberRole.leader:
        return 'leader';
      case TripMemberRole.member:
        return 'member';
    }
  }

  String get label {
    switch (this) {
      case TripMemberRole.owner:
        return 'Chủ chuyến';
      case TripMemberRole.leader:
        return 'Trưởng nhóm';
      case TripMemberRole.member:
        return 'Thành viên';
    }
  }

  bool get canManageMembers =>
      this == TripMemberRole.owner || this == TripMemberRole.leader;

  bool get canManageTrip =>
      this == TripMemberRole.owner || this == TripMemberRole.leader;

  bool get canTransferOwnership => this == TripMemberRole.owner;
}

TripMemberRole tripMemberRoleFromKey(String value) {
  final normalized = value.trim().toLowerCase();

  for (final role in TripMemberRole.values) {
    if (role.key == normalized) {
      return role;
    }
  }

  throw FormatException('Trip member role không hợp lệ: $value');
}

enum TripMemberStatus { active, left, removed }

extension TripMemberStatusX on TripMemberStatus {
  String get key {
    switch (this) {
      case TripMemberStatus.active:
        return 'active';
      case TripMemberStatus.left:
        return 'left';
      case TripMemberStatus.removed:
        return 'removed';
    }
  }

  String get label {
    switch (this) {
      case TripMemberStatus.active:
        return 'Đang tham gia';
      case TripMemberStatus.left:
        return 'Đã rời nhóm';
      case TripMemberStatus.removed:
        return 'Đã bị xóa';
    }
  }

  bool get isActive => this == TripMemberStatus.active;
}

TripMemberStatus tripMemberStatusFromKey(String value) {
  final normalized = value.trim().toLowerCase();

  for (final status in TripMemberStatus.values) {
    if (status.key == normalized) {
      return status;
    }
  }

  throw FormatException('Trip member status không hợp lệ: $value');
}

class TripMember {
  const TripMember({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.role,
    required this.status,
    required this.locationSharing,
    required this.joinedAt,
    this.updatedAt,
  });

  final String id;
  final String tripId;
  final String userId;
  final TripMemberRole role;
  final TripMemberStatus status;
  final bool locationSharing;
  final DateTime joinedAt;
  final DateTime? updatedAt;

  bool get isActive => status.isActive;
  bool get isOwner => role == TripMemberRole.owner;
  bool get isLeader => role == TripMemberRole.leader;
  bool get canManageMembers => isActive && role.canManageMembers;
  bool get canManageTrip => isActive && role.canManageTrip;
  bool get canLeave => isActive && !isOwner;
  bool get canShareLocation => isActive && locationSharing;

  TripMember copyWith({
    String? id,
    String? tripId,
    String? userId,
    TripMemberRole? role,
    TripMemberStatus? status,
    bool? locationSharing,
    DateTime? joinedAt,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
  }) {
    return TripMember(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      locationSharing: locationSharing ?? this.locationSharing,
      joinedAt: joinedAt ?? this.joinedAt,
      updatedAt: clearUpdatedAt ? null : updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trip_id': tripId,
    'user_id': userId,
    'role': role.key,
    'status': status.key,
    'location_sharing': locationSharing,
    'joined_at': joinedAt.toUtc().toIso8601String(),
    'updated_at': updatedAt?.toUtc().toIso8601String(),
  };

  factory TripMember.fromJson(Map<String, dynamic> json) {
    return TripMember(
      id: _requiredString(json['id'], 'id'),
      tripId: _requiredString(json['trip_id'], 'trip_id'),
      userId: _requiredString(json['user_id'], 'user_id'),
      role: tripMemberRoleFromKey(_requiredString(json['role'], 'role')),
      status: tripMemberStatusFromKey(
        _requiredString(json['status'], 'status'),
      ),
      locationSharing: _requiredBool(
        json['location_sharing'],
        'location_sharing',
      ),
      joinedAt: _requiredDateTime(json['joined_at'], 'joined_at'),
      updatedAt: _optionalDateTime(json['updated_at'], 'updated_at'),
    );
  }
}

String _requiredString(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field không được rỗng.');
  }
  return value.trim();
}

bool _requiredBool(dynamic value, String field) {
  if (value is! bool) {
    throw FormatException('$field phải là boolean.');
  }
  return value;
}

DateTime _requiredDateTime(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field không hợp lệ.');
  }
  final parsed = DateTime.tryParse(value.trim());
  if (parsed == null) {
    throw FormatException('$field không hợp lệ.');
  }
  return parsed.toUtc();
}

DateTime? _optionalDateTime(dynamic value, String field) {
  if (value == null) {
    return null;
  }
  return _requiredDateTime(value, field);
}
