import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/bus_stop.dart';
import '../../domain/repositories/stop_repository.dart';
import '../models/bus_stop_model.dart';

class FirestoreStopRepository implements StopRepository {
  static const _cacheKey = 'cached_stops_v1';
  static const _cacheTimeKey = 'cached_stops_at_v1';

  final FirebaseFirestore _db;

  FirestoreStopRepository(this._db);

  CollectionReference<Map<String, dynamic>> get _stops =>
      _db.collection('stops');

  @override
  Stream<List<BusStop>> watchStops() {
    // Sorting client-side keeps this a single-field query (no composite
    // index) and lets each screen sort its own way (by count vs by name).
    return _stops
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snap) => snap.docs.map(BusStopModel.fromDoc).toList());
  }

  @override
  Future<List<BusStop>> getCachedStops() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return const [];
    final list = (jsonDecode(raw) as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(BusStopModel.fromCacheJson)
        .toList();
    return list;
  }

  @override
  Future<void> cacheStops(List<BusStop> stops) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _cacheKey,
      jsonEncode(stops.map(BusStopModel.toCacheJson).toList()),
    );
    await prefs.setInt(_cacheTimeKey, DateTime.now().millisecondsSinceEpoch);
  }

  @override
  Future<DateTime?> lastCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final millis = prefs.getInt(_cacheTimeKey);
    return millis == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  Future<void> markEnRoute(String stopId, String driverUid) =>
      _stops.doc(stopId).update(<String, dynamic>{
        'enRouteBy': driverUid,
        'enRouteAt': FieldValue.serverTimestamp(),
        'arrivedAt': null,
      });

  @override
  Future<void> markArrived(String stopId, String driverUid) =>
      _stops.doc(stopId).update(<String, dynamic>{
        'enRouteBy': driverUid,
        'arrivedAt': FieldValue.serverTimestamp(),
      });

  @override
  Future<void> clearEnRoute(String stopId) =>
      _stops.doc(stopId).update(<String, dynamic>{
        'enRouteBy': null,
        'enRouteAt': null,
        'arrivedAt': null,
      });

  @override
  Future<void> upsertStop(BusStop stop) => _stops
      .doc(stop.id)
      .set(BusStopModel.toMap(stop), SetOptions(merge: true));

  @override
  Future<void> deactivateStop(String stopId) =>
      _stops.doc(stopId).update(<String, dynamic>{'active': false});
}
