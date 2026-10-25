import 'dart:math' as math;

import 'trip_live_map_entry.dart';

enum TripConvoySafetyLevel { noData, normal, caution, critical }

extension TripConvoySafetyLevelX on TripConvoySafetyLevel {
  String get label {
    switch (this) {
      case TripConvoySafetyLevel.noData:
        return 'Chưa có dữ liệu';
      case TripConvoySafetyLevel.normal:
        return 'Đoàn ổn định';
      case TripConvoySafetyLevel.caution:
        return 'Cần chú ý';
      case TripConvoySafetyLevel.critical:
        return 'Cảnh báo';
    }
  }
}

enum TripConvoyMemberState {
  solo,
  together,
  separated,
  criticalSeparation,
  signalWarning,
  signalLost,
}

extension TripConvoyMemberStateX on TripConvoyMemberState {
  TripConvoySafetyLevel get level {
    switch (this) {
      case TripConvoyMemberState.solo:
      case TripConvoyMemberState.together:
        return TripConvoySafetyLevel.normal;
      case TripConvoyMemberState.separated:
      case TripConvoyMemberState.signalWarning:
        return TripConvoySafetyLevel.caution;
      case TripConvoyMemberState.criticalSeparation:
      case TripConvoyMemberState.signalLost:
        return TripConvoySafetyLevel.critical;
    }
  }

  String get label {
    switch (this) {
      case TripConvoyMemberState.solo:
        return 'Chưa đủ dữ liệu đoàn';
      case TripConvoyMemberState.together:
        return 'Trong đoàn';
      case TripConvoyMemberState.separated:
        return 'Có dấu hiệu tách đoàn';
      case TripConvoyMemberState.criticalSeparation:
        return 'Cách đoàn quá xa';
      case TripConvoyMemberState.signalWarning:
        return 'GPS cập nhật chậm';
      case TripConvoyMemberState.signalLost:
        return 'Mất tín hiệu vị trí';
    }
  }
}

class TripConvoySafetyPolicy {
  const TripConvoySafetyPolicy({
    this.separationWarningMeters = 500,
    this.separationCriticalMeters = 1500,
    this.signalWarningAfter = const Duration(minutes: 2),
    this.signalCriticalAfter = const Duration(minutes: 5),
  });

  final double separationWarningMeters;
  final double separationCriticalMeters;
  final Duration signalWarningAfter;
  final Duration signalCriticalAfter;

  bool get isValid {
    return separationWarningMeters.isFinite &&
        separationWarningMeters >= 0 &&
        separationCriticalMeters.isFinite &&
        separationCriticalMeters > separationWarningMeters &&
        !signalWarningAfter.isNegative &&
        signalCriticalAfter > signalWarningAfter;
  }

  void validate() {
    if (!isValid) {
      throw StateError('TripConvoySafetyPolicy không hợp lệ.');
    }
  }
}

class TripConvoyMemberFinding {
  const TripConvoyMemberFinding({
    required this.entry,
    required this.state,
    required this.locationAge,
    this.nearestMemberUserId,
    this.nearestDistanceMeters,
  });

  final TripLiveMapEntry entry;
  final TripConvoyMemberState state;
  final Duration locationAge;
  final String? nearestMemberUserId;
  final double? nearestDistanceMeters;

  TripConvoySafetyLevel get level => state.level;
}

class TripConvoySafetySummary {
  const TripConvoySafetySummary({
    required this.level,
    required this.findings,
    required this.sharingCount,
    required this.freshCount,
    required this.staleCount,
    required this.canAssessSeparation,
    this.maxFreshPairDistanceMeters,
  });

  final TripConvoySafetyLevel level;
  final List<TripConvoyMemberFinding> findings;
  final int sharingCount;
  final int freshCount;
  final int staleCount;
  final bool canAssessSeparation;
  final double? maxFreshPairDistanceMeters;

  int get cautionCount => findings
      .where((finding) => finding.level == TripConvoySafetyLevel.caution)
      .length;

  int get criticalCount => findings
      .where((finding) => finding.level == TripConvoySafetyLevel.critical)
      .length;

  bool get hasIssues => cautionCount > 0 || criticalCount > 0;
}

class TripConvoySafetyAnalyzer {
  const TripConvoySafetyAnalyzer({
    this.policy = const TripConvoySafetyPolicy(),
  });

  final TripConvoySafetyPolicy policy;

  TripConvoySafetySummary analyze({
    required List<TripLiveMapEntry> entries,
    required DateTime now,
  }) {
    policy.validate();

    if (entries.isEmpty) {
      return const TripConvoySafetySummary(
        level: TripConvoySafetyLevel.noData,
        findings: [],
        sharingCount: 0,
        freshCount: 0,
        staleCount: 0,
        canAssessSeparation: false,
      );
    }

    final normalizedNow = now.toUtc();

    final freshEntries = <TripLiveMapEntry>[];
    final staleFindings = <TripConvoyMemberFinding>[];

    for (final entry in entries) {
      final age = entry.ageAt(normalizedNow);

      if (age >= policy.signalCriticalAfter) {
        staleFindings.add(
          TripConvoyMemberFinding(
            entry: entry,
            state: TripConvoyMemberState.signalLost,
            locationAge: age,
          ),
        );
        continue;
      }

      if (age >= policy.signalWarningAfter) {
        staleFindings.add(
          TripConvoyMemberFinding(
            entry: entry,
            state: TripConvoyMemberState.signalWarning,
            locationAge: age,
          ),
        );
        continue;
      }

      freshEntries.add(entry);
    }

    final freshFindings = <TripConvoyMemberFinding>[];

    if (freshEntries.length == 1) {
      final entry = freshEntries.single;

      freshFindings.add(
        TripConvoyMemberFinding(
          entry: entry,
          state: TripConvoyMemberState.solo,
          locationAge: entry.ageAt(normalizedNow),
        ),
      );
    } else if (freshEntries.length >= 2) {
      for (final entry in freshEntries) {
        final nearest = _nearestNeighbor(entry, freshEntries);

        final distance = nearest.distanceMeters;

        freshFindings.add(
          TripConvoyMemberFinding(
            entry: entry,
            state: _stateForDistance(distance),
            locationAge: entry.ageAt(normalizedNow),
            nearestMemberUserId: nearest.entry.userId,
            nearestDistanceMeters: distance,
          ),
        );
      }
    }

    final findings = <TripConvoyMemberFinding>[
      ...freshFindings,
      ...staleFindings,
    ];

    final level = _overallLevel(findings);

    return TripConvoySafetySummary(
      level: level,
      findings: List<TripConvoyMemberFinding>.unmodifiable(findings),
      sharingCount: entries.length,
      freshCount: freshEntries.length,
      staleCount: staleFindings.length,
      canAssessSeparation: freshEntries.length >= 2,
      maxFreshPairDistanceMeters: _maxPairDistance(freshEntries),
    );
  }

  TripConvoyMemberState _stateForDistance(double distanceMeters) {
    if (distanceMeters >= policy.separationCriticalMeters) {
      return TripConvoyMemberState.criticalSeparation;
    }

    if (distanceMeters >= policy.separationWarningMeters) {
      return TripConvoyMemberState.separated;
    }

    return TripConvoyMemberState.together;
  }

  TripConvoySafetyLevel _overallLevel(List<TripConvoyMemberFinding> findings) {
    var result = TripConvoySafetyLevel.normal;

    for (final finding in findings) {
      if (finding.level == TripConvoySafetyLevel.critical) {
        return TripConvoySafetyLevel.critical;
      }

      if (finding.level == TripConvoySafetyLevel.caution) {
        result = TripConvoySafetyLevel.caution;
      }
    }

    return result;
  }

  _NearestNeighbor _nearestNeighbor(
    TripLiveMapEntry target,
    List<TripLiveMapEntry> entries,
  ) {
    TripLiveMapEntry? nearestEntry;
    var nearestDistance = double.infinity;

    for (final candidate in entries) {
      if (candidate.userId == target.userId) {
        continue;
      }

      final distance = _distanceMeters(
        target.location.latitude,
        target.location.longitude,
        candidate.location.latitude,
        candidate.location.longitude,
      );

      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestEntry = candidate;
      }
    }

    if (nearestEntry == null) {
      throw StateError('Không tìm được thành viên gần nhất.');
    }

    return _NearestNeighbor(
      entry: nearestEntry,
      distanceMeters: nearestDistance,
    );
  }

  double? _maxPairDistance(List<TripLiveMapEntry> entries) {
    if (entries.length < 2) {
      return null;
    }

    var maxDistance = 0.0;

    for (var i = 0; i < entries.length; i++) {
      for (var j = i + 1; j < entries.length; j++) {
        final distance = _distanceMeters(
          entries[i].location.latitude,
          entries[i].location.longitude,
          entries[j].location.latitude,
          entries[j].location.longitude,
        );

        if (distance > maxDistance) {
          maxDistance = distance;
        }
      }
    }

    return maxDistance;
  }

  double _distanceMeters(
    double latitudeA,
    double longitudeA,
    double latitudeB,
    double longitudeB,
  ) {
    const earthRadiusMeters = 6371000.0;

    double radians(double degrees) => degrees * math.pi / 180;

    final lat1 = radians(latitudeA);
    final lat2 = radians(latitudeB);
    final deltaLat = radians(latitudeB - latitudeA);
    final deltaLon = radians(longitudeB - longitudeA);

    final sinLat = math.sin(deltaLat / 2);
    final sinLon = math.sin(deltaLon / 2);

    final a =
        sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadiusMeters * c;
  }
}

class _NearestNeighbor {
  const _NearestNeighbor({required this.entry, required this.distanceMeters});

  final TripLiveMapEntry entry;
  final double distanceMeters;
}
