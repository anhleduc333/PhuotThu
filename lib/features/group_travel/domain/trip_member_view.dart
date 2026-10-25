import 'trip_member.dart';

class TripMemberView {
  const TripMemberView({
    required this.memberId,
    required this.tripId,
    required this.userId,
    required this.displayName,
    required this.email,
    required this.role,
    required this.locationSharing,
    required this.joinedAt,
  });

  final String memberId;
  final String tripId;
  final String userId;
  final String displayName;
  final String email;
  final TripMemberRole role;
  final bool locationSharing;
  final DateTime joinedAt;

  bool get isOwner => role == TripMemberRole.owner;
  bool get isLeader => role == TripMemberRole.leader;
  bool get isMember => role == TripMemberRole.member;

  String get subtitle {
    if (email.trim().isEmpty) {
      return role.label;
    }

    return '${role.label} • $email';
  }

  String get initials {
    final normalized = displayName.trim();

    if (normalized.isEmpty) {
      return '?';
    }

    final parts = normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) {
      return '?';
    }

    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return '${parts.first.substring(0, 1)}'
            '${parts.last.substring(0, 1)}'
        .toUpperCase();
  }

  factory TripMemberView.fromJson(Map<String, dynamic> json) {
    return TripMemberView(
      memberId: _requiredString(json['member_id'], 'member_id'),
      tripId: _requiredString(json['trip_id'], 'trip_id'),
      userId: _requiredString(json['user_id'], 'user_id'),
      displayName: _requiredString(json['display_name'], 'display_name'),
      email: _optionalString(json['email']) ?? '',
      role: tripMemberRoleFromKey(_requiredString(json['role'], 'role')),
      locationSharing: _requiredBool(
        json['location_sharing'],
        'location_sharing',
      ),
      joinedAt: _requiredDateTime(json['joined_at'], 'joined_at'),
    );
  }
}

String _requiredString(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field không hợp lệ.');
  }

  return value.trim();
}

String? _optionalString(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is! String) {
    throw const FormatException('Giá trị chuỗi tùy chọn không hợp lệ.');
  }

  final normalized = value.trim();

  return normalized.isEmpty ? null : normalized;
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
