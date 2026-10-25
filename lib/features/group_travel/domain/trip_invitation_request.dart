import 'trip_invitation.dart';

class CreateTripInvitationInput {
  CreateTripInvitationInput({
    required String tripId,
    required String email,
    this.role = TripInvitationRole.member,
  }) : tripId = _normalizeTripId(tripId),
       email = _normalizeEmail(email);

  final String tripId;
  final String email;
  final TripInvitationRole role;

  static final RegExp _basicEmailPattern = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  static String _normalizeTripId(String value) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'tripId', 'tripId không được rỗng.');
    }

    return normalized;
  }

  static String _normalizeEmail(String value) {
    final normalized = value.trim().toLowerCase();

    if (normalized.isEmpty || !_basicEmailPattern.hasMatch(normalized)) {
      throw ArgumentError.value(value, 'email', 'Email không hợp lệ.');
    }

    return normalized;
  }
}
