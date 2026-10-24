import 'dart:math' as math;

enum RestTrigger { time, distance, both }

extension RestTriggerLabel on RestTrigger {
  String get label {
    switch (this) {
      case RestTrigger.time:
        return 'Thời gian chạy';
      case RestTrigger.distance:
        return 'Quãng đường';
      case RestTrigger.both:
        return 'Thời gian và quãng đường';
    }
  }
}

class RestPolicy {
  const RestPolicy({
    this.driveIntervalMinutes = 90,
    this.distanceIntervalKm = 100,
    this.suggestedRestMinutes = 15,
    this.minimumRemainingDistanceKm = 20,
    this.minimumRemainingTimeMinutes = 20,
    this.triggerMergeToleranceRatio = 0.03,
    this.maxStops = 20,
  });

  /// Số phút chạy liên tục tối đa trước khi ứng dụng
  /// bắt đầu đề xuất một điểm nghỉ.
  final int driveIntervalMinutes;

  /// Quãng đường tối đa giữa hai lần nghỉ.
  final double distanceIntervalKm;

  /// Thời gian nghỉ mà ứng dụng gợi ý.
  final int suggestedRestMinutes;

  /// Nếu đã rất gần đích thì không cần tạo thêm
  /// một điểm nghỉ mới.
  final double minimumRemainingDistanceKm;

  /// Ngưỡng thời gian còn lại dùng cùng với
  /// minimumRemainingDistanceKm để xác định gần đích.
  final int minimumRemainingTimeMinutes;

  /// Nếu trigger thời gian và quãng đường gần nhau
  /// trong phạm vi này thì coi là cả hai cùng kích hoạt.
  final double triggerMergeToleranceRatio;

  /// Giới hạn bảo vệ tránh tạo quá nhiều điểm nghỉ.
  final int maxStops;

  bool get isValid {
    return driveIntervalMinutes > 0 &&
        distanceIntervalKm > 0 &&
        suggestedRestMinutes > 0 &&
        minimumRemainingDistanceKm >= 0 &&
        minimumRemainingTimeMinutes >= 0 &&
        triggerMergeToleranceRatio >= 0 &&
        triggerMergeToleranceRatio <= 1 &&
        maxStops > 0;
  }
}

class RestTarget {
  const RestTarget({
    required this.stopNumber,
    required this.trigger,
    required this.progressRatio,
    required this.targetDistanceMeters,
    required this.targetElapsedSeconds,
    required this.suggestedRestMinutes,
  });

  final int stopNumber;

  /// Nguyên nhân chính tạo điểm nghỉ.
  final RestTrigger trigger;

  /// Vị trí tương đối trên toàn tuyến:
  ///
  /// 0.0 = điểm xuất phát
  /// 1.0 = điểm đến
  final double progressRatio;

  /// Vị trí mục tiêu tính từ điểm xuất phát.
  final double targetDistanceMeters;

  /// Thời gian lái xe ước tính từ điểm xuất phát
  /// tới vị trí nghỉ.
  ///
  /// Không bao gồm thời gian nghỉ.
  final double targetElapsedSeconds;

  final int suggestedRestMinutes;

  double get targetDistanceKm => targetDistanceMeters / 1000;

  double get targetElapsedMinutes => targetElapsedSeconds / 60;

  double get progressPercent => progressRatio * 100;
}

class RestPlan {
  const RestPlan({
    required this.policy,
    required this.totalDistanceMeters,
    required this.totalDurationSeconds,
    required this.targets,
  });

  final RestPolicy policy;
  final int totalDistanceMeters;
  final int totalDurationSeconds;
  final List<RestTarget> targets;

  bool get restRecommended => targets.isNotEmpty;

  int get recommendedStopCount => targets.length;

  double get totalDistanceKm => totalDistanceMeters / 1000;

  double get totalDurationMinutes => totalDurationSeconds / 60;
}

class RestPolicyCalculator {
  const RestPolicyCalculator();

  RestPlan? calculate({
    required int distanceMeters,
    required int durationSeconds,
    RestPolicy policy = const RestPolicy(),
  }) {
    if (distanceMeters <= 0 || durationSeconds <= 0 || !policy.isValid) {
      return null;
    }

    final timeProgressStep =
        (policy.driveIntervalMinutes * 60) / durationSeconds;

    final distanceProgressStep =
        (policy.distanceIntervalKm * 1000) / distanceMeters;

    if (!timeProgressStep.isFinite ||
        !distanceProgressStep.isFinite ||
        timeProgressStep <= 0 ||
        distanceProgressStep <= 0) {
      return null;
    }

    final progressStep = math.min(timeProgressStep, distanceProgressStep);

    final trigger = _resolveTrigger(
      timeProgressStep: timeProgressStep,
      distanceProgressStep: distanceProgressStep,
      tolerance: policy.triggerMergeToleranceRatio,
    );

    final targets = <RestTarget>[];

    for (var stopNumber = 1; stopNumber <= policy.maxStops; stopNumber++) {
      final progress = progressStep * stopNumber;

      if (progress >= 1) {
        break;
      }

      final remainingDistanceMeters = distanceMeters * (1 - progress);

      final remainingSeconds = durationSeconds * (1 - progress);

      final minimumRemainingDistanceMeters =
          policy.minimumRemainingDistanceKm * 1000;

      final minimumRemainingSeconds = policy.minimumRemainingTimeMinutes * 60;

      /// Nếu vừa gần đích theo cả quãng đường
      /// và thời gian thì không tạo một lần nghỉ mới.
      if (remainingDistanceMeters <= minimumRemainingDistanceMeters &&
          remainingSeconds <= minimumRemainingSeconds) {
        break;
      }

      targets.add(
        RestTarget(
          stopNumber: stopNumber,
          trigger: trigger,
          progressRatio: progress,
          targetDistanceMeters: distanceMeters * progress,
          targetElapsedSeconds: durationSeconds * progress,
          suggestedRestMinutes: policy.suggestedRestMinutes,
        ),
      );
    }

    return RestPlan(
      policy: policy,
      totalDistanceMeters: distanceMeters,
      totalDurationSeconds: durationSeconds,
      targets: List<RestTarget>.unmodifiable(targets),
    );
  }

  RestTrigger _resolveTrigger({
    required double timeProgressStep,
    required double distanceProgressStep,
    required double tolerance,
  }) {
    final difference = (timeProgressStep - distanceProgressStep).abs();

    if (difference <= tolerance) {
      return RestTrigger.both;
    }

    if (timeProgressStep < distanceProgressStep) {
      return RestTrigger.time;
    }

    return RestTrigger.distance;
  }
}
