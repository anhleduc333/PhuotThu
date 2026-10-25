import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/trip_invitation.dart';
import '../domain/trip_invitation_inbox_item.dart';
import '../domain/trip_invitation_request.dart';

abstract interface class TripInvitationRepository {
  Future<TripInvitation> inviteByEmail(CreateTripInvitationInput input);

  Future<List<TripInvitation>> getInvitationsForTrip(String tripId);

  Future<List<TripInvitationInboxItem>> getMyPendingInvitations();

  Future<String> respondToInvitation({
    required String invitationId,
    required bool accept,
  });
}

class SupabaseTripInvitationRepository implements TripInvitationRepository {
  SupabaseTripInvitationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<TripInvitation> inviteByEmail(CreateTripInvitationInput input) async {
    final response = await _client.rpc(
      'invite_trip_member_by_email',
      params: {
        'p_trip_id': input.tripId,
        'p_email': input.email,
        'p_role': input.role.key,
      },
    );

    final row = _singleRow(response);

    return TripInvitation.fromJson(row);
  }

  @override
  Future<List<TripInvitation>> getInvitationsForTrip(String tripId) async {
    final normalizedTripId = tripId.trim();

    if (normalizedTripId.isEmpty) {
      throw ArgumentError.value(tripId, 'tripId', 'tripId không được rỗng.');
    }

    final rows = await _client
        .from('trip_invitations')
        .select(
          'id, trip_id, inviter_id, invitee_user_id, role, status, '
          'created_at, expires_at, responded_at',
        )
        .eq('trip_id', normalizedTripId)
        .order('created_at', ascending: false);

    return List<TripInvitation>.unmodifiable(
      rows.map(
        (row) => TripInvitation.fromJson(Map<String, dynamic>.from(row)),
      ),
    );
  }

  @override
  Future<List<TripInvitationInboxItem>> getMyPendingInvitations() async {
    final response = await _client.rpc('get_my_pending_trip_invitations');

    if (response is! List) {
      throw StateError(
        'RPC get_my_pending_trip_invitations '
        'trả về dữ liệu không hợp lệ.',
      );
    }

    return List<TripInvitationInboxItem>.unmodifiable(
      response.map((row) {
        if (row is! Map) {
          throw StateError('Dữ liệu lời mời không hợp lệ.');
        }

        return TripInvitationInboxItem.fromJson(Map<String, dynamic>.from(row));
      }),
    );
  }

  @override
  Future<String> respondToInvitation({
    required String invitationId,
    required bool accept,
  }) async {
    final normalizedInvitationId = invitationId.trim();

    if (normalizedInvitationId.isEmpty) {
      throw ArgumentError.value(
        invitationId,
        'invitationId',
        'invitationId không được rỗng.',
      );
    }

    final response = await _client.rpc(
      'respond_trip_invitation',
      params: {'p_invitation_id': normalizedInvitationId, 'p_accept': accept},
    );

    if (response is String && response.trim().isNotEmpty) {
      return response.trim();
    }

    throw StateError(
      'RPC respond_trip_invitation '
      'không trả về tripId hợp lệ.',
    );
  }

  Map<String, dynamic> _singleRow(dynamic response) {
    if (response is List && response.length == 1) {
      final row = response.single;

      if (row is Map) {
        return Map<String, dynamic>.from(row);
      }
    }

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw StateError(
      'RPC invite_trip_member_by_email '
      'trả về dữ liệu không hợp lệ.',
    );
  }
}
