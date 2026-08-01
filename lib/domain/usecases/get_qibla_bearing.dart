import 'package:geolocator/geolocator.dart';
import '../../core/services/location_service.dart';

class QiblaResult {
  final double bearing; // 0–360 derece, kuzeyden saat yönünde
  final double latitude;
  final double longitude;

  const QiblaResult({
    required this.bearing,
    required this.latitude,
    required this.longitude,
  });
}

class GetQiblaBearing {
  final _locationService = LocationService();

  // Kâbe (Mescid-i Haram) koordinatları — sabit, değişmez.
  static const double _kaabaLat = 21.4225;
  static const double _kaabaLng = 39.8262;

  Future<QiblaResult?> call() async {
    final position = await _locationService.getCurrentPosition();
    if (position == null) return null;

    // Geolocator.bearingBetween iki koordinat arasındaki büyük daire
    // açısını (-180..180 aralığında) döner. Elle trigonometri yazıp
    // hata riski almak yerine kütüphanenin test edilmiş fonksiyonunu
    // kullanıyoruz.
    final rawBearing = Geolocator.bearingBetween(
      position.latitude,
      position.longitude,
      _kaabaLat,
      _kaabaLng,
    );

    // 0–360 aralığına normalize et (pusula/kadran hesapları için gerekli)
    final bearing = rawBearing < 0 ? rawBearing + 360 : rawBearing;

    return QiblaResult(
      bearing: bearing,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
}
