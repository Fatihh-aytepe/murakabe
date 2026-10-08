import 'dart:convert';

import 'package:crypto/crypto.dart';

class AppStrings {
  // Uygulama
  static const String appName = 'Murakabe';

  // Splash Yazıları
  static const List<String> splashMessages = [
    'Elhamdülillah',
    'Estağfirullah',
    'Sabret',
    'Şükret',
    'Dua Et',
    'Korkma, Allah Seninle Beraber',
    'Allah Bize Yeter, O Ne Güzel Bir Vekildir',
  ];

  // Login
  static const String loginTitle = 'Hoş Geldiniz';
  static const String loginSubtitle =
      'Murakabe\'ye başlamak için bilgilerinizi girin';
  static const String nameSurname = 'Ad Soyad';
  static const String phone = 'Telefon Numarası';
  static const String email = 'E-Posta Adresi';
  static const String startButton = 'Başla';

  // Ana Sayfa
  static const String dailyEsma = 'Günün Esması';
  static const String dailyAyet = 'Günün Ayeti';
  static const String dailyHadis = 'Günün Hadisi';
  static const String myNotes = 'Notlarım';

  // İçerik Aksiyonları
  static const String read = 'Okudum';
  static const String remind = 'Tekrar Hatırlat';
  static const String save = 'Kaydet';
  static const String saved = 'Kaydedildi';

  // Profil
  static const String profile = 'Profilim';
  static const String savedEsmas = 'Kaydedilen Esmalar';
  static const String savedAyets = 'Kaydedilen Ayetler';
  static const String savedHadises = 'Kaydedilen Hadisler';
  static const String quranDays = 'Kuran Okuma Günlerim';
  static const String tahajjud = 'Teheccüd Namazlarım';

  // Admin
  // Sahip e-postası kodda AÇIK metin olarak tutulmaz; yalnızca
  // küçük harfe çevrilmiş adresin SHA-256 özeti (base64) saklanır.
  // Aynı özet firestore.rules içindeki roles/owner kuralında da kullanılır —
  // sahip e-postası değişirse İKİ yeri birlikte güncelleyin.
  static const String _ownerEmailSha256B64 =
      'DH3seHl0DvxTaVUKm4NWyoeruJ/RW2EZE78IhpavpSw=';

  /// Verilen e-posta sahip hesabının e-postası mı?
  static bool isOwnerEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    final digest = sha256.convert(utf8.encode(email.trim().toLowerCase()));
    return base64Encode(digest.bytes) == _ownerEmailSha256B64;
  }

  // Bildirimler
  static const String quranReminder = 'Bugün Kuran Okudun mu?';
  static const String quranReminderBody =
      'Bugün Kuran okumayı unutma. Allah\'ın kelamı kalplere şifa verir.';
  static const String tahajjudTitle = 'Teheccüd Vakti';
  static const String tahajjudBody =
      'Gece namazı vakti geldi. Rabbine seccadeyi ser...';
  static const String weeklyReminder = 'Haftalık Özet';
}
