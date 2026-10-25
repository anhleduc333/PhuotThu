import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/domain/trip_invitation.dart';
import 'package:phuotthu/features/group_travel/domain/trip_invitation_inbox_item.dart';

void main() {
  Map<String, dynamic> json({
    String status = 'pending',
    String? startName = 'Hà Nội',
    String? destinationName = 'Hà Giang',
  }) {
    return {
      'invitation_id': 'invite-1',
      'trip_id': 'trip-1',
      'trip_name': 'Hà Giang cuối tuần',
      'inviter_id': 'owner-1',
      'role': 'member',
      'status': status,
      'created_at': '2026-10-25T03:00:00Z',
      'expires_at': '2026-11-01T03:00:00Z',
      'start_name': startName,
      'destination_name': destinationName,
    };
  }

  test('parses inbox item', () {
    final item = TripInvitationInboxItem.fromJson(json());

    expect(item.invitationId, 'invite-1');
    expect(item.tripId, 'trip-1');
    expect(item.tripName, 'Hà Giang cuối tuần');
    expect(item.role, TripInvitationRole.member);
    expect(item.status, TripInvitationStatus.pending);
  });

  test('builds route label when both endpoints exist', () {
    final item = TripInvitationInboxItem.fromJson(json());

    expect(item.routeLabel, 'Hà Nội → Hà Giang');
  });

  test('route label is null when endpoint is missing', () {
    final item = TripInvitationInboxItem.fromJson(json(destinationName: null));

    expect(item.routeLabel, isNull);
  });

  test('pending invitation before expiry is actionable', () {
    final item = TripInvitationInboxItem.fromJson(json());

    expect(item.isActionableAt(DateTime.utc(2026, 10, 30)), isTrue);
  });

  test('invitation at expiry time is not actionable', () {
    final item = TripInvitationInboxItem.fromJson(json());

    expect(item.isActionableAt(DateTime.utc(2026, 11, 1, 3)), isFalse);
  });

  test('non-pending invitation is not actionable', () {
    final item = TripInvitationInboxItem.fromJson(json(status: 'declined'));

    expect(item.isActionableAt(DateTime.utc(2026, 10, 30)), isFalse);
  });

  test('rejects malformed payload', () {
    final malformed = json()..['trip_name'] = '';

    expect(
      () => TripInvitationInboxItem.fromJson(malformed),
      throwsFormatException,
    );
  });
}
