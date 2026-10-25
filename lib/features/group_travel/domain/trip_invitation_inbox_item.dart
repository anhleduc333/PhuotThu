import 'trip_invitation.dart';

class TripInvitationInboxItem {
  const TripInvitationInboxItem({
    required this.invitationId,
    required this.tripId,
    required this.tripName,
    required this.inviterId,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.startName,
    this.destinationName,
  });

  final String invitationId;
  final String tripId;
  final String tripName;
  final String inviterId;
  final TripInvitationRole role;
  final TripInvitationStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? startName;
  final String? destinationName;

  bool get isPending => status == TripInvitationStatus.pending;

  bool isExpiredAt(DateTime now) {
    return !expiresAt.isAfter(now.toUtc());
  }

  bool isActionableAt(DateTime now) {
    return isPending && !isExpiredAt(now);
  }

  String? get routeLabel {
    final start = startName?.trim();
    final destination = destinationName?.trim();

    if (start == null ||
        start.isEmpty ||
        destination == null ||
        destination.isEmpty) {
      return null;
    }

    return '$start → $destination';
  }

  factory TripInvitationInboxItem.fromJson(Map<String, dynamic> json) {
    return TripInvitationInboxItem(
      invitationId: _requiredString(json['invitation_id'], 'invitation_id'),
      tripId: _requiredString(json['trip_id'], 'trip_id'),
      tripName: _requiredString(json['trip_name'], 'trip_name'),
      inviterId: _requiredString(json['inviter_id'], 'inviter_id'),
      role: tripInvitationRoleFromKey(_requiredString(json['role'], 'role')),
      status: tripInvitationStatusFromKey(
        _requiredString(json['status'], 'status'),
      ),
      createdAt: _requiredDateTime(json['created_at'], 'created_at'),
      expiresAt: _requiredDateTime(json['expires_at'], 'expires_at'),
      startName: _optionalString(json['start_name']),
      destinationName: _optionalString(json['destination_name']),
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
