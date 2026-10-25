import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/domain/trip_member.dart';
import 'package:phuotthu/features/group_travel/domain/trip_member_view.dart';

void main() {
  Map<String, dynamic> json({
    String displayName = 'Lê Đức Anh',
    String? email = 'anh@example.com',
    String role = 'member',
    bool locationSharing = false,
  }) {
    return {
      'member_id': 'member-1',
      'trip_id': 'trip-1',
      'user_id': 'user-1',
      'display_name': displayName,
      'email': email,
      'role': role,
      'location_sharing': locationSharing,
      'joined_at': '2026-10-25T03:00:00Z',
    };
  }

  test('parses member view', () {
    final member = TripMemberView.fromJson(json());

    expect(member.memberId, 'member-1');
    expect(member.tripId, 'trip-1');
    expect(member.userId, 'user-1');
    expect(member.displayName, 'Lê Đức Anh');
    expect(member.email, 'anh@example.com');
    expect(member.role, TripMemberRole.member);
    expect(member.locationSharing, isFalse);
  });

  test('normalizes joinedAt to UTC', () {
    final payload = json()..['joined_at'] = '2026-10-25T10:00:00+07:00';

    final member = TripMemberView.fromJson(payload);

    expect(member.joinedAt.isUtc, isTrue);
    expect(member.joinedAt.hour, 3);
  });

  test('identifies owner role', () {
    final member = TripMemberView.fromJson(json(role: 'owner'));

    expect(member.isOwner, isTrue);
    expect(member.isLeader, isFalse);
    expect(member.isMember, isFalse);
  });

  test('identifies leader role', () {
    final member = TripMemberView.fromJson(json(role: 'leader'));

    expect(member.isLeader, isTrue);
  });

  test('builds role and email subtitle', () {
    final member = TripMemberView.fromJson(json(role: 'leader'));

    expect(member.subtitle, 'Trưởng nhóm • anh@example.com');
  });

  test('subtitle falls back to role when email is absent', () {
    final member = TripMemberView.fromJson(json(email: null));

    expect(member.subtitle, 'Thành viên');
  });

  test('builds two-letter initials from display name', () {
    final member = TripMemberView.fromJson(json());

    expect(member.initials, 'LA');
  });

  test('builds one-letter initials from single name', () {
    final member = TripMemberView.fromJson(json(displayName: 'Anh'));

    expect(member.initials, 'A');
  });

  test('rejects malformed role', () {
    expect(
      () => TripMemberView.fromJson(json(role: 'admin')),
      throwsFormatException,
    );
  });
}
