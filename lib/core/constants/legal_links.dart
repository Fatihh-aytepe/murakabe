import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web sitesindeki yasal sayfalar (Firebase Hosting, bkz. hosting/ klasörü).
/// Play Store, gizlilik politikasına uygulamanın içinden de erişilebilmesini
/// ister; Ayarlar → Yasal ve kayıt ekranındaki onay kutuları buraya bağlanır.
class LegalLinks {
  LegalLinks._();

  static const String _base = 'https://murakabe-7bfb6.web.app';
  static const String privacy = '$_base/gizlilik';
  static const String kvkk = '$_base/kvkk';
  static const String consent = '$_base/acik-riza';
  static const String terms = '$_base/kullanim-kosullari';
  static const String accountDeletion = '$_base/hesap-silme';

  /// Kayıtta onaylanan metinlerin sürümü (users/{uid}.consentVersion).
  /// Metinler esaslı biçimde değişirse bu tarih güncellenir.
  static const String consentVersion = '2026-10-08';

  /// Sayfayı uygulama içi tarayıcıda açar; olmazsa harici tarayıcıyı dener.
  static Future<void> open(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } catch (_) {}
    if (!opened) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sayfa açılamadı: $url')),
      );
    }
  }
}
