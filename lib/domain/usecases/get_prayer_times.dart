import 'package:adhan/adhan.dart';
import '../../core/services/location_service.dart';

class PrayerTimesResult {
  final PrayerTimes prayerTimes;
  final double latitude;
  final double longitude;

  PrayerTimesResult({
    required this.prayerTimes,
    required this.latitude,
    required this.longitude,
  });
}

class GetPrayerTimes {
  final _locationService = LocationService();

  Future<PrayerTimesResult?> call() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null) return null;

    final coordinates = Coordinates(position.latitude, position.longitude);
    final params = CalculationMethod.turkey.getParameters();
    final date = DateComponents.from(DateTime.now());
    final prayerTimes = PrayerTimes(coordinates, date, params);

    return PrayerTimesResult(
      prayerTimes: prayerTimes,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
