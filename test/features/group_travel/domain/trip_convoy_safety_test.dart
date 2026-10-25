import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/domain/trip_convoy_safety.dart';
import 'package:phuotthu/features/group_travel/domain/trip_live_location.dart';
import 'package:phuotthu/features/group_travel/domain/trip_live_map_entry.dart';
import 'package:phuotthu/features/group_travel/domain/trip_member.dart';
import 'package:phuotthu/features/group_travel/domain/trip_member_view.dart';

void main() {
  TripLiveMapEntry entry({
    required String userId,
    double latitude = 21,
    double longitude = 105,
    int ageSeconds = 0,
    TripMemberRole role = TripMemberRole.member,
  }) {
    final now = DateTime.utc(2026, 10, 26, 3);

    return TripLiveMapEntry(
      member: TripMemberView(
        memberId: 'm-$userId',
        tripId: 'trip-1',
        userId: userId,
        displayName: userId,
        email: '$userId@example.com',
        role: role,
        locationSharing: true,
        joinedAt: DateTime.utc(2026, 10, 25),
      ),
      location: TripLiveLocation(
        id: 'l-$userId',
        tripId: 'trip-1',
        userId: userId,
        latitude: latitude,
        longitude: longitude,
        recordedAt: now.subtract(Duration(seconds: ageSeconds)),
        updatedAt: now.subtract(Duration(seconds: ageSeconds)),
      ),
    );
  }

  final now = DateTime.utc(2026, 10, 26, 3);

  test('empty convoy returns noData', () {
    const analyzer = TripConvoySafetyAnalyzer();

    final result = analyzer.analyze(entries: const [], now: now);

    expect(result.level, TripConvoySafetyLevel.noData);
    expect(result.sharingCount, 0);
    expect(result.canAssessSeparation, isFalse);
  });

  test('single fresh member is normal but separation is unknown', () {
    const analyzer = TripConvoySafetyAnalyzer();

    final result = analyzer.analyze(
      entries: [entry(userId: 'u1')],
      now: now,
    );

    expect(result.level, TripConvoySafetyLevel.normal);
    expect(result.findings.single.state, TripConvoyMemberState.solo);
    expect(result.canAssessSeparation, isFalse);
  });

  test('two close members are together', () {
    const analyzer = TripConvoySafetyAnalyzer();

    final result = analyzer.analyze(
      entries: [
        entry(userId: 'u1'),
        entry(userId: 'u2', latitude: 21.001),
      ],
      now: now,
    );

    expect(result.level, TripConvoySafetyLevel.normal);
    expect(
      result.findings.every(
        (finding) => finding.state == TripConvoyMemberState.together,
      ),
      isTrue,
    );
  });

  test('500m separation triggers caution', () {
    const analyzer = TripConvoySafetyAnalyzer();

    final result = analyzer.analyze(
      entries: [
        entry(userId: 'u1'),
        entry(userId: 'u2', latitude: 21.005),
      ],
      now: now,
    );

    expect(result.level, TripConvoySafetyLevel.caution);
    expect(result.cautionCount, 2);
  });

  test('1500m separation triggers critical', () {
    const analyzer = TripConvoySafetyAnalyzer();

    final result = analyzer.analyze(
      entries: [
        entry(userId: 'u1'),
        entry(userId: 'u2', latitude: 21.015),
      ],
      now: now,
    );

    expect(result.level, TripConvoySafetyLevel.critical);
    expect(result.criticalCount, 2);
  });

  test('GPS older than 2 minutes triggers signal warning', () {
    const analyzer = TripConvoySafetyAnalyzer();

    final result = analyzer.analyze(
      entries: [entry(userId: 'u1', ageSeconds: 121)],
      now: now,
    );

    expect(result.findings.single.state, TripConvoyMemberState.signalWarning);
    expect(result.level, TripConvoySafetyLevel.caution);
  });

  test('GPS older than 5 minutes triggers signal lost', () {
    const analyzer = TripConvoySafetyAnalyzer();

    final result = analyzer.analyze(
      entries: [entry(userId: 'u1', ageSeconds: 301)],
      now: now,
    );

    expect(result.findings.single.state, TripConvoyMemberState.signalLost);
    expect(result.level, TripConvoySafetyLevel.critical);
  });

  test('stale member is excluded from separation geometry', () {
    const analyzer = TripConvoySafetyAnalyzer();

    final result = analyzer.analyze(
      entries: [
        entry(userId: 'u1'),
        entry(userId: 'u2', latitude: 21.02, ageSeconds: 301),
      ],
      now: now,
    );

    final freshFinding = result.findings.firstWhere(
      (finding) => finding.entry.userId == 'u1',
    );

    expect(freshFinding.state, TripConvoyMemberState.solo);
    expect(result.canAssessSeparation, isFalse);
  });

  test('nearest-neighbor analysis isolates distant member', () {
    const analyzer = TripConvoySafetyAnalyzer();

    final result = analyzer.analyze(
      entries: [
        entry(userId: 'u1'),
        entry(userId: 'u2', latitude: 21.001),
        entry(userId: 'u3', latitude: 21.020),
      ],
      now: now,
    );

    final u3 = result.findings.firstWhere(
      (finding) => finding.entry.userId == 'u3',
    );

    expect(u3.state, TripConvoyMemberState.criticalSeparation);
  });

  test('summary reports maximum fresh pair distance', () {
    const analyzer = TripConvoySafetyAnalyzer();

    final result = analyzer.analyze(
      entries: [
        entry(userId: 'u1'),
        entry(userId: 'u2', latitude: 21.001),
        entry(userId: 'u3', latitude: 21.010),
      ],
      now: now,
    );

    expect(result.maxFreshPairDistanceMeters, isNotNull);
    expect(result.maxFreshPairDistanceMeters!, greaterThan(1000));
  });

  test('custom policy changes separation threshold', () {
    const analyzer = TripConvoySafetyAnalyzer(
      policy: TripConvoySafetyPolicy(
        separationWarningMeters: 50,
        separationCriticalMeters: 100,
      ),
    );

    final result = analyzer.analyze(
      entries: [
        entry(userId: 'u1'),
        entry(userId: 'u2', latitude: 21.001),
      ],
      now: now,
    );

    expect(result.level, TripConvoySafetyLevel.critical);
  });

  test('invalid distance thresholds are rejected', () {
    const analyzer = TripConvoySafetyAnalyzer(
      policy: TripConvoySafetyPolicy(
        separationWarningMeters: 1000,
        separationCriticalMeters: 500,
      ),
    );

    expect(
      () => analyzer.analyze(entries: const [], now: now),
      throwsStateError,
    );
  });

  test('invalid signal thresholds are rejected', () {
    const analyzer = TripConvoySafetyAnalyzer(
      policy: TripConvoySafetyPolicy(
        signalWarningAfter: Duration(minutes: 5),
        signalCriticalAfter: Duration(minutes: 2),
      ),
    );

    expect(
      () => analyzer.analyze(entries: const [], now: now),
      throwsStateError,
    );
  });
}
