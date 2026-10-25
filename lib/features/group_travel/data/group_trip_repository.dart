import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/group_trip_state.dart';
import '../domain/trip_member.dart';
import '../domain/trip_member_view.dart';

abstract interface class GroupTripRepository {
  Future<GroupTripState> getGroupTripState(String tripId);

  Future<GroupTripState> enableGroupTrip(String tripId);

  Future<List<TripMemberView>> getMemberViews(String tripId);

  Future<void> setMemberRole({
    required String tripId,
    required String memberUserId,
    required TripMemberRole role,
  });

  Future<void> removeMember({
    required String tripId,
    required String memberUserId,
  });

  Future<void> leaveTrip(String tripId);

  Future<void> setMyLocationSharing({
    required String tripId,
    required bool enabled,
  });
}

class SupabaseGroupTripRepository implements GroupTripRepository {
  SupabaseGroupTripRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<GroupTripState> getGroupTripState(String tripId) async {
    final normalizedTripId = _normalizeTripId(tripId);
    final userId = _currentUserId();

    final tripJson = await _client
        .from('trips')
        .select('id, owner_id, group_enabled')
        .eq('id', normalizedTripId)
        .single();

    final memberRows = await _client
        .from('trip_members')
        .select(
          'id, trip_id, user_id, role, status, '
          'location_sharing, joined_at, updated_at',
        )
        .eq('trip_id', normalizedTripId)
        .order('joined_at');

    final members = memberRows
        .map((row) => TripMember.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);

    return GroupTripState(
      tripId: _requiredString(tripJson['id'], 'id'),
      ownerId: _requiredString(tripJson['owner_id'], 'owner_id'),
      viewerUserId: userId,
      isGroupEnabled: _requiredBool(tripJson['group_enabled'], 'group_enabled'),
      members: List<TripMember>.unmodifiable(members),
    );
  }

  @override
  Future<GroupTripState> enableGroupTrip(String tripId) async {
    final normalizedTripId = _normalizeTripId(tripId);
    final userId = _currentUserId();

    final updatedRows = await _client
        .from('trips')
        .update({'group_enabled': true})
        .eq('id', normalizedTripId)
        .eq('owner_id', userId)
        .select('id');

    if (updatedRows.isEmpty) {
      throw StateError(
        'Không thể bật chuyến đi nhóm. '
        'Chỉ chủ chuyến mới có quyền thực hiện thao tác này.',
      );
    }

    return getGroupTripState(normalizedTripId);
  }

  @override
  Future<List<TripMemberView>> getMemberViews(String tripId) async {
    final normalizedTripId = _normalizeTripId(tripId);

    _currentUserId();

    final response = await _client.rpc(
      'get_trip_member_views',
      params: {'p_trip_id': normalizedTripId},
    );

    if (response is! List) {
      throw StateError(
        'RPC get_trip_member_views '
        'trả về dữ liệu không hợp lệ.',
      );
    }

    return List<TripMemberView>.unmodifiable(
      response.map((row) {
        if (row is! Map) {
          throw StateError('Dữ liệu thành viên không hợp lệ.');
        }

        return TripMemberView.fromJson(Map<String, dynamic>.from(row));
      }),
    );
  }

  @override
  Future<void> setMemberRole({
    required String tripId,
    required String memberUserId,
    required TripMemberRole role,
  }) async {
    final normalizedTripId = _normalizeTripId(tripId);

    final normalizedUserId = _normalizeUserId(memberUserId);

    _currentUserId();

    if (role == TripMemberRole.owner) {
      throw ArgumentError.value(
        role,
        'role',
        'Không thể gán Owner bằng thao tác đổi vai trò.',
      );
    }

    await _client.rpc(
      'set_trip_member_role',
      params: {
        'p_trip_id': normalizedTripId,
        'p_member_user_id': normalizedUserId,
        'p_role': role.key,
      },
    );
  }

  @override
  Future<void> removeMember({
    required String tripId,
    required String memberUserId,
  }) async {
    final normalizedTripId = _normalizeTripId(tripId);

    final normalizedUserId = _normalizeUserId(memberUserId);

    _currentUserId();

    await _client.rpc(
      'remove_trip_member',
      params: {
        'p_trip_id': normalizedTripId,
        'p_member_user_id': normalizedUserId,
      },
    );
  }

  @override
  Future<void> leaveTrip(String tripId) async {
    final normalizedTripId = _normalizeTripId(tripId);

    _currentUserId();

    await _client.rpc('leave_trip', params: {'p_trip_id': normalizedTripId});
  }

  @override
  Future<void> setMyLocationSharing({
    required String tripId,
    required bool enabled,
  }) async {
    final normalizedTripId = _normalizeTripId(tripId);

    _currentUserId();

    await _client.rpc(
      'set_my_trip_location_sharing',
      params: {'p_trip_id': normalizedTripId, 'p_enabled': enabled},
    );
  }

  String _currentUserId() {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw StateError('Người dùng chưa đăng nhập.');
    }

    return user.id;
  }

  String _normalizeTripId(String tripId) {
    final normalized = tripId.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(tripId, 'tripId', 'tripId không được rỗng.');
    }

    return normalized;
  }

  String _normalizeUserId(String userId) {
    final normalized = userId.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(
        userId,
        'memberUserId',
        'memberUserId không được rỗng.',
      );
    }

    return normalized;
  }
}

String _requiredString(dynamic value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field không hợp lệ.');
  }

  return value.trim();
}

bool _requiredBool(dynamic value, String field) {
  if (value is! bool) {
    throw FormatException('$field phải là boolean.');
  }

  return value;
}
