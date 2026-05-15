import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return _getLastKnown();

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return _getLastKnown();
    }
    if (permission == LocationPermission.deniedForever) return _getLastKnown();

    try {
      // forceAndroidLocationManager: Google Play Services (DEVELOPER_ERROR)
      // yerine native Android LocationManager kullanır
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
        forceAndroidLocationManager: true,
      );
    } catch (_) {
      return _getLastKnown();
    }
  }

  Future<Position?> _getLastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (_) {
      return null;
    }
  }
}
