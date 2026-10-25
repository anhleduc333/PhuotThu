import 'trip_member.dart';

class GroupTripState {
  const GroupTripState({
    required this.tripId,
    required this.ownerId,
    required this.viewerUserId,
    required this.isGroupEnabled,
    required this.members,
  });

  final String tripId;
  final String ownerId;
  final String viewerUserId;
  final bool isGroupEnabled;
  final List<TripMember> members;

  List<TripMember> get activeMembers =>
      List<TripMember>.unmodifiable(members.where((member) => member.isActive));

  TripMember? get viewerMembership {
    for (final member in members) {
      if (member.userId == viewerUserId) {
        return member;
      }
    }

    return null;
  }

  bool get viewerIsOwner => ownerId == viewerUserId;

  bool get viewerIsActiveMember =>
      viewerIsOwner || (viewerMembership?.isActive ?? false);

  bool get viewerCanManageMembers =>
      viewerIsOwner || (viewerMembership?.canManageMembers ?? false);

  int get activeMemberCount => activeMembers.length;

  int get activeNonOwnerMemberCount =>
      activeMembers.where((member) => member.userId != ownerId).length;

  int get activeLeaderCount => activeMembers
      .where((member) => member.role == TripMemberRole.leader)
      .length;

  int get locationSharingMemberCount =>
      activeMembers.where((member) => member.canShareLocation).length;

  bool get hasOtherActiveMembers => activeNonOwnerMemberCount > 0;

  bool get isSoloGroup => isGroupEnabled && activeNonOwnerMemberCount == 0;
}
