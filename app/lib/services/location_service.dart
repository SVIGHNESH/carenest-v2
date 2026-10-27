import 'package:geolocator/geolocator.dart';

import 'geo.dart';

enum LocationFailure { denied, deniedForever, serviceOff, unavailable }

class LocationException implements Exception {
  const LocationException(this.failure);
  final LocationFailure failure;
}

abstract class LocationService {
  /// Current position, or throws [LocationException].
  Future<GeoPoint> current();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<GeoPoint> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationException(LocationFailure.serviceOff);
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied) {
        throw const LocationException(LocationFailure.denied);
      }
      if (perm == LocationPermission.deniedForever) {
        throw const LocationException(LocationFailure.deniedForever);
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return GeoPoint(p.latitude, p.longitude);
    } on LocationException {
      rethrow;
    } catch (_) {
      throw const LocationException(LocationFailure.unavailable);
    }
  }
}
