import 'package:flutter_test/flutter_test.dart';
import 'package:phuotthu/features/group_travel/domain/trip_checkpoint.dart';
import 'package:phuotthu/features/group_travel/domain/trip_checkpoint_inputs.dart';

void main() {
  Map<String, dynamic> sample() => {
    'id': 'checkpoint-1',
    'trip_id': 'trip-1',
    'created_by': null,
    'name': 'Điểm hẹn Quản Bạ',
    'note': null,
    'latitude': 23.05,
    'longitude': 105.00,
    'radius_m': 100,
    'sort_order': 2,
    'planned_at': '2026-10-26T10:00:00+07:00',
    'is_required': true,
    'auto_arrival_enabled': false,
    'created_at': '2026-10-25T01:00:00+00:00',
    'updated_at': '2026-10-25T02:00:00Z',
  };

  group('TripCheckpoint', () {
    test('parses DB row and converts timestamps to UTC', () {
      final model = TripCheckpoint.fromJson(sample());
      expect(model.name, 'Điểm hẹn Quản Bạ');
      expect(model.latitude, 23.05);
      expect(model.plannedAt!.isUtc, isTrue);
      expect(model.plannedAt!.hour, 3);
      expect(model.autoArrivalEnabled, isFalse);
      expect(TripCheckpoint.fromJson(model.toJson()).radiusM, 100);
    });

    test('rejects malformed DB data', () {
      expect(
        () => TripCheckpoint.fromJson({...sample(), 'latitude': 999.0}),
        throwsFormatException,
      );
      expect(
        () => TripCheckpoint.fromJson({...sample(), 'is_required': 'yes'}),
        throwsFormatException,
      );
      expect(
        () => TripCheckpoint.fromJson({...sample(), 'created_at': 'invalid'}),
        throwsFormatException,
      );
    });
  });

  group('CreateTripCheckpointInput', () {
    test('produces DB-ready payload without user-controlled creator', () {
      final input = CreateTripCheckpointInput(
        tripId: ' trip-1 ',
        name: ' Điểm hẹn A ',
        latitude: 21.03,
        longitude: 105.85,
        plannedAt: DateTime.parse('2026-10-26T10:00:00+07:00'),
      );
      expect(input.isValid, isTrue);
      final payload = input.toInsertJson();
      expect(payload['trip_id'], 'trip-1');
      expect(payload['name'], 'Điểm hẹn A');
      expect(payload.containsKey('created_by'), isFalse);
      expect(payload.containsKey('id'), isFalse);
      expect(payload['planned_at'], '2026-10-26T03:00:00.000Z');
    });

    test('rejects invalid coordinates and distance', () {
      expect(
        const CreateTripCheckpointInput(
          tripId: 't',
          name: 'A',
          latitude: 100,
          longitude: 20,
        ).isValid,
        isFalse,
      );
      expect(
        const CreateTripCheckpointInput(
          tripId: 't',
          name: 'A',
          latitude: 10,
          longitude: 20,
          radiusM: 2,
        ).toInsertJson,
        throwsStateError,
      );
    });
  });

  group('UpdateTripCheckpointInput', () {
    test('does not accidentally clear nullable fields', () {
      const input = UpdateTripCheckpointInput(name: 'Mới');
      expect(input.toUpdateJson(), {'name': 'Mới'});
    });

    test('explicitly clears note and planned time', () {
      const input = UpdateTripCheckpointInput(
        clearNote: true,
        clearPlannedAt: true,
      );
      expect(input.toUpdateJson(), {'note': null, 'planned_at': null});
    });

    test('rejects conflicting or empty changes', () {
      expect(
        const UpdateTripCheckpointInput(note: 'foo', clearNote: true).isValid,
        isFalse,
      );
      expect(const UpdateTripCheckpointInput().toUpdateJson, throwsStateError);
    });
  });
}
