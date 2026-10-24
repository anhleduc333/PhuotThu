import 'connectivity_risk.dart';

class ConnectivityRiskZonePolicy {
  const ConnectivityRiskZonePolicy({
    this.minimumSegmentLengthMeters = 1000,
    this.mergeGapMeters = 3000,
    this.mergeSameLevelOnly = true,
  });

  /// Segment quá ngắn sẽ được cân nhắc nhập vào segment lân cận.
  final double minimumSegmentLengthMeters;

  /// Nếu khoảng trống giữa hai segment đủ nhỏ thì có thể nhập lại,
  /// tùy theo rule về mức rủi ro.
  final double mergeGapMeters;

  /// true: chỉ nhập khi cùng risk level.
  final bool mergeSameLevelOnly;

  bool get isValid => minimumSegmentLengthMeters >= 0 && mergeGapMeters >= 0;
}

class ConnectivityRiskZoneDetector {
  const ConnectivityRiskZoneDetector();

  ConnectivityRiskAssessment? detect({
    required double totalRouteMeters,
    required List<ConnectivityRiskPoint> points,
    String provider = 'unknown',
    DateTime? generatedAt,
    ConnectivityRiskZonePolicy policy = const ConnectivityRiskZonePolicy(),
  }) {
    if (totalRouteMeters <= 0 || points.isEmpty || !policy.isValid) {
      return null;
    }

    final validPoints = points
        .where(
          (point) =>
              point.distanceFromStartMeters >= 0 &&
              point.distanceFromStartMeters <= totalRouteMeters,
        )
        .toList(growable: false);

    if (validPoints.isEmpty) {
      return null;
    }

    final sortedPoints = [...validPoints]
      ..sort(
        (a, b) =>
            a.distanceFromStartMeters.compareTo(b.distanceFromStartMeters),
      );

    final deduplicatedPoints = _deduplicateByDistance(sortedPoints);

    if (deduplicatedPoints.isEmpty) {
      return null;
    }

    final rawSegments = _buildRawSegments(
      totalRouteMeters: totalRouteMeters,
      points: deduplicatedPoints,
    );

    final mergedSegments = _mergeSegments(rawSegments, policy);

    final overallRiskScore = _calculateOverallRiskScore(
      totalRouteMeters: totalRouteMeters,
      segments: mergedSegments,
      fallbackPoints: deduplicatedPoints,
    );

    return ConnectivityRiskAssessment(
      totalRouteMeters: totalRouteMeters,
      overallRiskScore: overallRiskScore,
      overallLevel: ConnectivityRiskLevelX.fromScore(overallRiskScore),
      segments: List<ConnectivityRiskSegment>.unmodifiable(mergedSegments),
      sampledPoints: List<ConnectivityRiskPoint>.unmodifiable(
        deduplicatedPoints,
      ),
      provider: provider,
      generatedAt: generatedAt,
    );
  }

  List<ConnectivityRiskPoint> _deduplicateByDistance(
    List<ConnectivityRiskPoint> points,
  ) {
    if (points.isEmpty) {
      return const [];
    }

    final result = <ConnectivityRiskPoint>[];

    for (final point in points) {
      if (result.isEmpty) {
        result.add(point);
        continue;
      }

      final previous = result.last;

      if ((point.distanceFromStartMeters - previous.distanceFromStartMeters)
              .abs() >
          0.01) {
        result.add(point);
        continue;
      }

      // Nếu hai sample ở cùng tiến độ, giữ sample có risk score cao hơn
      // để không làm giảm cảnh báo một cách không chủ ý.
      if (point.riskScore > previous.riskScore) {
        result[result.length - 1] = point;
      }
    }

    return result;
  }

  List<ConnectivityRiskSegment> _buildRawSegments({
    required double totalRouteMeters,
    required List<ConnectivityRiskPoint> points,
  }) {
    final result = <ConnectivityRiskSegment>[];

    if (points.length == 1) {
      final point = points.single;

      result.add(
        ConnectivityRiskSegment(
          startDistanceMeters: 0,
          endDistanceMeters: totalRouteMeters,
          startProgressRatio: 0,
          endProgressRatio: 1,
          averageRiskScore: point.riskScore,
          maxRiskScore: point.riskScore,
          level: point.level,
          sampleCount: 1,
          startLatitude: point.latitude,
          startLongitude: point.longitude,
          endLatitude: point.latitude,
          endLongitude: point.longitude,
        ),
      );

      return result;
    }

    var startIndex = 0;

    for (var index = 1; index < points.length; index++) {
      if (points[index].level == points[startIndex].level) {
        continue;
      }

      result.add(
        _segmentFromPointRange(
          points: points,
          startIndex: startIndex,
          endIndex: index - 1,
          startDistanceMeters: startIndex == 0
              ? 0
              : _midpoint(
                  points[startIndex - 1].distanceFromStartMeters,
                  points[startIndex].distanceFromStartMeters,
                ),
          endDistanceMeters: _midpoint(
            points[index - 1].distanceFromStartMeters,
            points[index].distanceFromStartMeters,
          ),
          totalRouteMeters: totalRouteMeters,
        ),
      );

      startIndex = index;
    }

    result.add(
      _segmentFromPointRange(
        points: points,
        startIndex: startIndex,
        endIndex: points.length - 1,
        startDistanceMeters: startIndex == 0
            ? 0
            : _midpoint(
                points[startIndex - 1].distanceFromStartMeters,
                points[startIndex].distanceFromStartMeters,
              ),
        endDistanceMeters: totalRouteMeters,
        totalRouteMeters: totalRouteMeters,
      ),
    );

    return result;
  }

  ConnectivityRiskSegment _segmentFromPointRange({
    required List<ConnectivityRiskPoint> points,
    required int startIndex,
    required int endIndex,
    required double startDistanceMeters,
    required double endDistanceMeters,
    required double totalRouteMeters,
  }) {
    var scoreSum = 0.0;
    var maxRiskScore = 0.0;

    for (var index = startIndex; index <= endIndex; index++) {
      final score = points[index].riskScore;
      scoreSum += score;

      if (score > maxRiskScore) {
        maxRiskScore = score;
      }
    }

    final sampleCount = endIndex - startIndex + 1;
    final averageRiskScore = scoreSum / sampleCount;
    final representativeLevel = ConnectivityRiskLevelX.fromScore(
      averageRiskScore,
    );

    return ConnectivityRiskSegment(
      startDistanceMeters: startDistanceMeters.clamp(0.0, totalRouteMeters),
      endDistanceMeters: endDistanceMeters.clamp(0.0, totalRouteMeters),
      startProgressRatio: totalRouteMeters <= 0
          ? 0
          : (startDistanceMeters / totalRouteMeters).clamp(0.0, 1.0),
      endProgressRatio: totalRouteMeters <= 0
          ? 0
          : (endDistanceMeters / totalRouteMeters).clamp(0.0, 1.0),
      averageRiskScore: averageRiskScore.clamp(0.0, 1.0),
      maxRiskScore: maxRiskScore.clamp(0.0, 1.0),
      level: representativeLevel,
      sampleCount: sampleCount,
      startLatitude: points[startIndex].latitude,
      startLongitude: points[startIndex].longitude,
      endLatitude: points[endIndex].latitude,
      endLongitude: points[endIndex].longitude,
    );
  }

  List<ConnectivityRiskSegment> _mergeSegments(
    List<ConnectivityRiskSegment> segments,
    ConnectivityRiskZonePolicy policy,
  ) {
    if (segments.length <= 1) {
      return segments;
    }

    var working = [...segments];

    working = _mergeAdjacentSameLevel(working, policy);

    if (policy.minimumSegmentLengthMeters > 0) {
      working = _mergeShortSegments(working, policy);
    }

    working = _mergeAdjacentSameLevel(working, policy);

    return working;
  }

  List<ConnectivityRiskSegment> _mergeAdjacentSameLevel(
    List<ConnectivityRiskSegment> segments,
    ConnectivityRiskZonePolicy policy,
  ) {
    if (segments.isEmpty) {
      return const [];
    }

    final result = <ConnectivityRiskSegment>[segments.first];

    for (final segment in segments.skip(1)) {
      final previous = result.last;
      final gap = segment.startDistanceMeters - previous.endDistanceMeters;

      final sameLevel = segment.level == previous.level;

      final canMerge =
          gap <= policy.mergeGapMeters &&
          (!policy.mergeSameLevelOnly || sameLevel);

      if (!canMerge) {
        result.add(segment);
        continue;
      }

      result[result.length - 1] = _combineSegments(previous, segment);
    }

    return result;
  }

  List<ConnectivityRiskSegment> _mergeShortSegments(
    List<ConnectivityRiskSegment> segments,
    ConnectivityRiskZonePolicy policy,
  ) {
    if (segments.length <= 1) {
      return segments;
    }

    final working = [...segments];

    var index = 0;

    while (index < working.length) {
      final current = working[index];

      if (current.lengthMeters >= policy.minimumSegmentLengthMeters ||
          working.length == 1) {
        index++;
        continue;
      }

      if (index == 0) {
        working[1] = _combineSegments(current, working[1]);
        working.removeAt(0);
        continue;
      }

      if (index == working.length - 1) {
        working[index - 1] = _combineSegments(working[index - 1], current);
        working.removeAt(index);
        index--;
        continue;
      }

      final previous = working[index - 1];
      final next = working[index + 1];

      final previousSimilarity =
          (previous.averageRiskScore - current.averageRiskScore).abs();

      final nextSimilarity = (next.averageRiskScore - current.averageRiskScore)
          .abs();

      if (previousSimilarity <= nextSimilarity) {
        working[index - 1] = _combineSegments(previous, current);
        working.removeAt(index);
        index--;
      } else {
        working[index + 1] = _combineSegments(current, next);
        working.removeAt(index);
      }
    }

    return working;
  }

  ConnectivityRiskSegment _combineSegments(
    ConnectivityRiskSegment first,
    ConnectivityRiskSegment second,
  ) {
    final firstSamples = first.sampleCount > 0 ? first.sampleCount : 1;
    final secondSamples = second.sampleCount > 0 ? second.sampleCount : 1;

    final sampleCount = firstSamples + secondSamples;

    final averageRiskScore =
        (first.averageRiskScore * firstSamples +
            second.averageRiskScore * secondSamples) /
        sampleCount;

    final maxRiskScore = first.maxRiskScore >= second.maxRiskScore
        ? first.maxRiskScore
        : second.maxRiskScore;

    return ConnectivityRiskSegment(
      startDistanceMeters: first.startDistanceMeters,
      endDistanceMeters: second.endDistanceMeters,
      startProgressRatio: first.startProgressRatio,
      endProgressRatio: second.endProgressRatio,
      averageRiskScore: averageRiskScore.clamp(0.0, 1.0),
      maxRiskScore: maxRiskScore.clamp(0.0, 1.0),
      level: ConnectivityRiskLevelX.fromScore(averageRiskScore),
      sampleCount: sampleCount,
      startLatitude: first.startLatitude,
      startLongitude: first.startLongitude,
      endLatitude: second.endLatitude,
      endLongitude: second.endLongitude,
    );
  }

  double _calculateOverallRiskScore({
    required double totalRouteMeters,
    required List<ConnectivityRiskSegment> segments,
    required List<ConnectivityRiskPoint> fallbackPoints,
  }) {
    var weightedRisk = 0.0;
    var weightedLength = 0.0;

    for (final segment in segments) {
      if (segment.lengthMeters <= 0) {
        continue;
      }

      weightedRisk += segment.averageRiskScore * segment.lengthMeters;

      weightedLength += segment.lengthMeters;
    }

    if (weightedLength > 0) {
      return (weightedRisk / weightedLength).clamp(0.0, 1.0);
    }

    if (fallbackPoints.isEmpty) {
      return 0;
    }

    final average =
        fallbackPoints.fold<double>(0, (sum, point) => sum + point.riskScore) /
        fallbackPoints.length;

    return average.clamp(0.0, 1.0);
  }

  double _midpoint(double first, double second) {
    return (first + second) / 2;
  }
}
