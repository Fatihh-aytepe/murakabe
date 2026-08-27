import 'dart:io';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/services/location_service.dart';

class QiblaResult {
  final double bearing; // 0–360 derece, kuzeyden saat yönünde
  final double latitude;
  final double longitude;
  // Manyetik sapma (derece) — SADECE Android'de doldurulur (bkz.
  // MainActivity.getMagneticDeclination). Android'de flutter_compass ham
  // manyetik heading verdiğinden, pusula ekranı gerçek kuzeyle karşılaştırma
  // yaparken heading'e bunu eklemelidir (trueHeading = magneticHeading +
  // declination). iOS zaten trueHeading döndürdüğü için burada null kalır.
  final double? magneticDeclination;

  const QiblaResult({
    required this.bearing,
    required this.latitude,
    required this.longitude,
    this.magneticDeclination,
  });
}

class GetQiblaBearing {
  final _locationService = LocationService();
  static const _channel = MethodChannel('com.murakabe.app/qibla');

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
      magneticDeclination: await _magneticDeclination(
        position.latitude,
        position.longitude,
      ),
    );
  }

  Future<double?> _magneticDeclination(double lat, double lng) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMethod<double>(
        'getMagneticDeclination',
        {'lat': lat, 'lng': lng},
      );
      return result;
    } catch (_) {
      // Kanal/hesap başarısız olursa düzeltmesiz (ham manyetik) heading'e
      // düşülür — önceki davranışla aynı, en azından pusula çalışmaya devam
      // eder.
      return null;
    }
  }
}
