/// Kalıcı bildirim ID'leri türetmek için kullanılan, SÜRÜMDEN BAĞIMSIZ
/// deterministik string hash fonksiyonu.
///
/// NEDEN: Daha önce not/görev/hatırlatıcı bildirim ID'leri doğrudan Dart'ın
/// yerleşik `String.hashCode`'u ile türetiliyordu. Dart dokümantasyonu
/// `Object.hashCode` için (ve dolayısıyla onu override eden `String` için)
/// değerin farklı çalıştırmalar/SDK sürümleri arasında AYNI KALACAĞINI
/// GARANTİ ETMEZ — bu bir uygulama detayıdır, sabit bir sözleşme değil
/// (bkz. https://api.dart.dev/dart-core/Object/hashCode.html). Kullanıcı
/// uygulamayı güncellediğinde (yeni bir Flutter/Dart SDK ile derlenmiş APK),
/// aynı not/görev ID'si için hashCode teorik olarak FARKLI bir değer
/// üretebilir — bu durumda önceden planlanmış bildirim artık aynı ID ile
/// bulunup iptal edilemez (yetim kalır) ya da yeni bir ID'yle YENİDEN
/// planlanıp mükerrer bildirime yol açabilir.
///
/// Bu fonksiyon, Java/Dart'ın klasik `s[0]*31^(n-1) + ... + s[n-1]` string
/// hash formülünü KENDİMİZ uyguluyoruz — algoritma bize ait olduğu için SDK
/// sürümünden tamamen bağımsız olarak sonsuza dek aynı sonucu üretir.
int stableStringHash(String input) {
  var hash = 0;
  for (final unit in input.codeUnits) {
    // 0x7fffffff ile maskeleyip pozitif 32-bit aralıkta tutuyoruz — negatif
    // sonuç üretmez, ayrıca farklı platformlarda (web/native) int taşması
    // farklı davranmasın diye her adımda maskeliyoruz.
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}
