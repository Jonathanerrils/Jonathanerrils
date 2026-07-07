import 'package:flutter_test/flutter_test.dart';
import 'package:knust_shuttle_connect/domain/entities/bus_stop.dart';
import 'package:knust_shuttle_connect/domain/entities/check_in.dart';
import 'package:knust_shuttle_connect/domain/repositories/check_in_repository.dart';
import 'package:knust_shuttle_connect/domain/usecases/check_in_at_stop.dart';

class _FakeCheckInRepository implements CheckInRepository {
  BusStop? lastCheckedInStop;
  String? lastUid;
  bool cancelled = false;

  @override
  Future<void> checkIn({required String uid, required BusStop stop}) async {
    lastUid = uid;
    lastCheckedInStop = stop;
  }

  @override
  Future<void> cancel(String uid) async => cancelled = true;

  @override
  Stream<CheckIn?> watchMyCheckIn(String uid) => const Stream.empty();
}

void main() {
  const stop = BusStop(
    id: 'commercial-area',
    name: 'Commercial Area',
    latitude: 6.6828,
    longitude: -1.5760,
    geofenceRadiusMeters: 75,
  );

  late _FakeCheckInRepository repo;
  late CheckInAtStop useCase;

  setUp(() {
    repo = _FakeCheckInRepository();
    useCase = CheckInAtStop(repo);
  });

  test('succeeds when inside the geofence and not rate-limited', () async {
    final result = await useCase(
      uid: 'student1',
      stop: stop,
      latitude: stop.latitude + 0.0001, // ~11 m away
      longitude: stop.longitude,
    );
    expect(result.isSuccess, isTrue);
    expect(repo.lastCheckedInStop?.id, 'commercial-area');
    expect(repo.lastUid, 'student1');
  });

  test('rejects check-in outside the geofence (GPS verification)', () async {
    final result = await useCase(
      uid: 'student1',
      stop: stop,
      latitude: stop.latitude + 0.01, // ~1.1 km away
      longitude: stop.longitude,
    );
    expect(result.isFailure, isTrue);
    expect(result.error, contains('must be at'));
    expect(repo.lastCheckedInStop, isNull);
  });

  test('rejects rapid repeated check-ins (rate limiting)', () async {
    final result = await useCase(
      uid: 'student1',
      stop: stop,
      latitude: stop.latitude,
      longitude: stop.longitude,
      lastActionAt: DateTime.now().subtract(const Duration(seconds: 10)),
    );
    expect(result.isFailure, isTrue);
    expect(result.error, contains('wait'));
    expect(repo.lastCheckedInStop, isNull);
  });

  test('allows a new check-in after the cooldown has passed', () async {
    final result = await useCase(
      uid: 'student1',
      stop: stop,
      latitude: stop.latitude,
      longitude: stop.longitude,
      lastActionAt: DateTime.now().subtract(const Duration(seconds: 61)),
    );
    expect(result.isSuccess, isTrue);
  });

  test('check-in entity reports expiry correctly (auto-expiry)', () {
    final expired = CheckIn(
      studentUid: 'student1',
      stopId: stop.id,
      stopName: stop.name,
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    final fresh = CheckIn(
      studentUid: 'student1',
      stopId: stop.id,
      stopName: stop.name,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(minutes: 25)),
    );
    expect(expired.isExpired, isTrue);
    expect(fresh.isExpired, isFalse);
  });
}
