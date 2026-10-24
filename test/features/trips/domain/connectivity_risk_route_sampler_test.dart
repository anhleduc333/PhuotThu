import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/map/domain/route_result.dart';
import 'package:phuotthu/features/trips/domain/connectivity_risk_route_sampler.dart';

void main() {
  const sampler = ConnectivityRiskRouteSampler();

  RoutePoint routePoint(double latitude, double longitude) {
    return RoutePoint(latitude: latitude, longitude: longitude);
  }

  group('ConnectivityRiskRouteSampler', () {
    test('samples start, interval points and route end', () {
      final samples = sampler.sample(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        policy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 25000,
        ),
      );

      expect(samples, isNotEmpty);
      expect(samples.first.distanceFromStartMeters, 0);
      expect(samples.first.progressRatio, 0);
      expect(samples.last.progressRatio, closeTo(1, 0.0001));

      for (var index = 1; index < samples.length; index++) {
        expect(
          samples[index].distanceFromStartMeters,
          greaterThan(samples[index - 1].distanceFromStartMeters),
        );
      }
    });

    test('approximately respects requested spacing', () {
      final samples = sampler.sample(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        policy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 20000,
        ),
      );

      expect(samples.length, greaterThan(5));

      for (var index = 1; index < samples.length - 1; index++) {
        final delta =
            samples[index].distanceFromStartMeters -
            samples[index - 1].distanceFromStartMeters;

        expect(delta, closeTo(20000, 0.001));
      }
    });

    test('interpolates coordinate on route segment', () {
      final samples = sampler.sample(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        policy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 55597,
        ),
      );

      expect(samples.length, greaterThanOrEqualTo(3));

      final middle = samples[1];

      expect(middle.latitude, closeTo(0, 0.0001));
      expect(middle.longitude, closeTo(0.5, 0.02));
      expect(middle.progressRatio, closeTo(0.5, 0.02));
    });

    test('follows a multi-segment polyline', () {
      final samples = sampler.sample(
        routePoints: [
          routePoint(0, 0),
          routePoint(0, 0.5),
          routePoint(0.5, 0.5),
        ],
        policy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 30000,
        ),
      );

      expect(samples, isNotEmpty);

      expect(
        samples.any((sample) => sample.longitude > 0.45 && sample.latitude > 0),
        isTrue,
      );
    });

    test('can exclude route start', () {
      final samples = sampler.sample(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        policy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 25000,
          includeStart: false,
        ),
      );

      expect(samples, isNotEmpty);
      expect(samples.first.distanceFromStartMeters, greaterThan(0));
    });

    test('can exclude route end', () {
      final samples = sampler.sample(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        policy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 25000,
          includeEnd: false,
        ),
      );

      expect(samples, isNotEmpty);
      expect(samples.last.progressRatio, lessThan(1));
    });

    test('enforces maximum sample count', () {
      final samples = sampler.sample(
        routePoints: [routePoint(0, 0), routePoint(0, 5)],
        policy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 1000,
          maximumSamples: 10,
        ),
      );

      expect(samples.length, 10);
      expect(samples.last.progressRatio, closeTo(1, 0.0001));
    });

    test('returns empty for invalid route', () {
      expect(sampler.sample(routePoints: const []), isEmpty);

      expect(sampler.sample(routePoints: [routePoint(0, 0)]), isEmpty);
    });

    test('returns empty for zero-length route', () {
      final samples = sampler.sample(
        routePoints: [routePoint(0, 0), routePoint(0, 0)],
      );

      expect(samples, isEmpty);
    });

    test('returns empty for invalid policy', () {
      final samples = sampler.sample(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        policy: const ConnectivityRiskSamplingPolicy(sampleSpacingMeters: 0),
      );

      expect(samples, isEmpty);
    });

    test('sample helpers expose km and percent', () {
      final samples = sampler.sample(
        routePoints: [routePoint(0, 0), routePoint(0, 1)],
        policy: const ConnectivityRiskSamplingPolicy(
          sampleSpacingMeters: 25000,
        ),
      );

      final sample = samples[1];

      expect(sample.distanceFromStartKm, 25);
      expect(sample.progressPercent, greaterThan(0));
      expect(sample.progressPercent, lessThan(100));
    });
  });
}
