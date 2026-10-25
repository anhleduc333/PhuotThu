enum TripInvitationRole { leader, member }

extension TripInvitationRoleX on TripInvitationRole {
  String get key {
    switch (this) {
      case TripInvitationRole.leader:
        return 'leader';
      case TripInvitationRole.member:
        return 'member';
    }
  }

  String get label {
    switch (this) {
      case TripInvitationRole.leader:
        return 'Trưởng nhóm';
      case TripInvitationRole.member:
        return 'Thành viên';
    }
  }
}

TripInvitationRole tripInvitationRoleFromKey(String value) {
  final normalized = value.trim().toLowerCase();

  for (final role in TripInvitationRole.values) {
    if (role.key == normalized) {
      return role;
    }
  }

  throw FormatException('Trip invitation role không hợp lệ: $value');
}

enum TripInvitationStatus { pending, accepted, declined, cancelled, expired }

extension TripInvitationStatusX on TripInvitationStatus {
  String get key {
    switch (this) {
      case TripInvitationStatus.pending:
        return 'pending';
      case TripInvitationStatus.accepted:
        return 'accepted';
      case TripInvitationStatus.declined:
        return 'declined';
      case TripInvitationStatus.cancelled:
        return 'cancelled';
      case TripInvitationStatus.expired:
        return 'expired';
    }
  }

  String get label {
    switch (this) {
      case TripInvitationStatus.pending:
        return 'Đang chờ';
      case TripInvitationStatus.accepted:
        return 'Đã chấp nhận';
      case TripInvitationStatus.declined:
        return 'Đã từ chối';
      case TripInvitationStatus.cancelled:
        return 'Đã hủy';
      case TripInvitationStatus.expired:
        return 'Đã hết hạn';
    }
  }

  bool get isPending => this == TripInvitationStatus.pending;
}

TripInvitationStatus tripInvitationStatusFromKey(String value) {
  final normalized = value.trim().toLowerCase();

  for (final status in TripInvitationStatus.values) {
    if (status.key == normalized) {
      return status;
    }
  }

  throw FormatException('Trip invitation status không hợp lệ: $value');
}

class TripInvitation {
  const TripInvitation({
    required this.id,
    required this.tripId,
    required this.inviterId,
    required this.inviteeUserId,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
  });

  final String id;
  final String tripId;
  final String inviterId;
  final String inviteeUserId;
  final TripInvitationRole role;
  final TripInvitationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;

  bool get isPending => status.isPending;

  bool isExpiredAt(DateTime now) {
    return !expiresAt.isAfter(now.toUtc());
  }

  bool isActionableAt(DateTime now) {
    return isPending && !isExpiredAt(now);
  }

  TripInvitation copyWith({
    String? id,
    String? tripId,
    String? inviterId,
    String? inviteeUserId,
    TripInvitationRole? role,
    TripInvitationStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    DateTime? respondedAt,
    bool clearRespondedAt = false,
  }) {
    return TripInvitation(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      inviterId: inviterId ?? this.inviterId,
      inviteeUserId: inviteeUserId ?? this.inviteeUserId,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      respondedAt: clearRespondedAt ? null : respondedAt ?? this.respondedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'trip_id': tripId,
    'inviter_id': inviterId,
    'invitee_user_id': inviteeUserId,
    'role': role.key,
    'status': status.key,
    'created_at': createdAt.toUtc().toIso8601String(),
    'expires_at': expiresAt.toUtc().toIso8601String(),
    'responded_at': respondedAt?.toUtc().toIso8601String(),
  };

  factory TripInvitation.fromJson(Map<String, dynamic> json) {
    return TripInvitation(
      id: _requiredString(json['id'], 'id'),
      tripId: _requiredString(json['trip_id'], 'trip_id'),
      inviterId: _requiredString(json['inviter_id'], 'inviter_id'),
      inviteeUserId: _requiredString(
        json['invitee_user_id'],
        'invitee_user_id',
      ),
      role: tripInvitationRoleFromKey(_requiredString(json['role'], 'role')),
      status: tripInvitationStatusFromKey(
        _requiredString(json['status'], 'status'),
      ),
      createdAt: _requiredDateTime(json['created_at'], 'created_at'),
      expiresAt: _requiredDateTime(json['expires_at'], 'expires_at'),
      respondedAt: _optionalDateTime(json['responded_at'], 'responded_at'),
    );
  }
}

String _requiredString(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field không được rỗng.');
  }
  return value.trim();
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
