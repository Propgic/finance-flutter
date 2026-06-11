import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// A best-effort GPS reading captured at the moment of an action.
class CapturedLocation {
  final double latitude;
  final double longitude;
  final double? accuracy;
  const CapturedLocation(this.latitude, this.longitude, this.accuracy);

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        if (accuracy != null) 'locationAccuracy': accuracy,
      };
}

/// Tries to obtain the device's current position without ever throwing.
///
/// Returns `null` when location services are off, permission is denied, or a
/// fix can't be obtained in time — callers should treat location as optional
/// and proceed regardless (best-effort capture, never blocks the action).
Future<CapturedLocation?> tryGetCurrentLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
    return CapturedLocation(pos.latitude, pos.longitude, pos.accuracy);
  } catch (e) {
    debugPrint('location capture failed: $e');
    return null;
  }
}
