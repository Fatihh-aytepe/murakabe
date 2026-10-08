import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/legal_links.dart';

/// Kullanım Koşulları / Gizlilik Politikası / KVKK açık rıza onayının
/// takibi. Onay hem Firestore'da (users/{uid}.consentVersion — ispat için)
/// hem cihazda (hızlı ve çevrimdışı kontrol için) tutulur.
///
/// Metinler esaslı biçimde değişirse [LegalLinks.consentVersion] güncellenir;
/// bu durumda herkese onay ekranı yeniden gösterilir.
class ConsentService {
  ConsentService._();

  static String _key(String uid) => 'consent_version_$uid';

  /// Kullanıcı güncel metinleri onaylamış mı?
  /// Önce cihazdaki kayda bakar; yoksa Firestore'a sorar (en fazla 5 sn).
  /// Sunucuya ulaşılamazsa ve cihazda kayıt yoksa `false` döner — yani onay
  /// ekranı gösterilir (kabul edilince yazma işlemi çevrimdışı kuyruğa alınır).
  static Future<bool> hasAccepted(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_key(uid)) == LegalLinks.consentVersion) return true;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 5));
      if (doc.data()?['consentVersion'] == LegalLinks.consentVersion) {
        await prefs.setString(_key(uid), LegalLinks.consentVersion);
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Onayı kaydeder. Firestore yazımı çevrimdışıysa kuyruğa alınır; cihaz
  /// kaydı hemen yapılır ki kullanıcı tekrar tekrar sorulmasın.
  static Future<void> recordAcceptance(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), LegalLinks.consentVersion);
    unawaited(FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({
          'consentVersion': LegalLinks.consentVersion,
          'consentAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .catchError((_) {}));
  }
}
