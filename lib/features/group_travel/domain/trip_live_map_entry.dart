import 'trip_live_location.dart';
import 'trip_member.dart';
import 'trip_member_view.dart';

class TripLiveMapEntry {
  const TripLiveMapEntry({required this.member, required this.location});

  final TripMemberView member;
  final TripLiveLocation location;

  String get userId => member.userId;
  String get displayName => member.displayName;
  String get initials => member.initials;
  TripMemberRole get role => member.role;

  bool isFreshAt(
    DateTime now, {
    Duration freshnessWindow = TripLiveLocation.defaultFreshnessWindow,
  }) {
    return location.isFreshAt(now, freshnessWindow: freshnessWindow);
  }

  Duration ageAt(DateTime now) {
    return location.ageAt(now);
  }
}

class TripLiveMapEntryAssembler {
  const TripLiveMapEntryAssembler();

  List<TripLiveMapEntry> assemble({
    required String tripId,
    required List<TripMemberView> members,
    required List<TripLiveLocation> locations,
  }) {
    final normalizedTripId = tripId.trim();

    if (normalizedTripId.isEmpty) {
      throw ArgumentError.value(tripId, 'tripId', 'tripId không được rỗng.');
    }

    final latestLocationByUser = <String, TripLiveLocation>{};

    for (final location in locations) {
      if (location.tripId != normalizedTripId) {
        continue;
      }

      final current = latestLocationByUser[location.userId];

      if (current == null || location.recordedAt.isAfter(current.recordedAt)) {
        latestLocationByUser[location.userId] = location;
      }
    }

    final entries = <TripLiveMapEntry>[];

    for (final member in members) {
      if (member.tripId != normalizedTripId || !member.locationSharing) {
        continue;
      }

      final location = latestLocationByUser[member.userId];

      if (location == null) {
        continue;
      }

      entries.add(TripLiveMapEntry(member: member, location: location));
    }

    entries.sort(_compareEntries);

    return List<TripLiveMapEntry>.unmodifiable(entries);
  }

  int _compareEntries(TripLiveMapEntry a, TripLiveMapEntry b) {
    final roleCompare = _roleRank(a.role).compareTo(_roleRank(b.role));

    if (roleCompare != 0) {
      return roleCompare;
    }

    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  }

  int _roleRank(TripMemberRole role) {
    switch (role) {
      case TripMemberRole.owner:
        return 0;
      case TripMemberRole.leader:
        return 1;
      case TripMemberRole.member:
        return 2;
    }
  }
}
