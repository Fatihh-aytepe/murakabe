import 'dart:convert';
import 'package:adhan/adhan.dart';
import 'package:flutter/services.dart';
import '../../data/local/local_storage.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/zikir_repository.dart';
import '../../domain/usecases/get_prayer_times.dart';

/// Ana ekran widget'ları (namaz vakitleri, zikir sayacı, günlük içerik) ile
/// Flutter tarafı arasındaki köprü. Üçüncü parti bir eklentiye bağlı değil:
/// veriler `shared_preferences` üzerinden (native Android kodu aynı
/// SharedPreferences dosyasını `flutter.<key>` önekiyle okuyor) yazılır,
/// ardından tek bir MethodChannel çağrısıyla native tarafa "verileri tekrar
/// oku ve widget'ları yeniden çiz" denir.
///
/// Ne zaman çağrılmalı: uygulama açılışında (main.dart), HomeScreen içerik
/// yüklendiğinde, zikir sayısı/hedefi değiştiğinde. Konum izni yoksa namaz
/// vakitleri güncellenemez — widget o durumda son bilinen veriyi göstermeye
/// devam eder (bkz. PrayerTimesWidgetProvider.kt).
class WidgetBridgeService {
  static final WidgetBridgeService _instance =
      WidgetBridgeService._internal();
  factory WidgetBridgeService() => _instance;
  WidgetBridgeService._internal();

  static const _channel = MethodChannel('com.murakabe.app/widgets');

  final _storage = LocalStorage();
  final _contentRepo = ContentRepository();
  final _zikirRepo = ZikirRepository();
  final _getPrayerTimes = GetPrayerTimes();

  /// Widget tablolarının kaç gün ileriye yazılacağı. Uygulama/arka plan
  /// görevi bu süre içinde bir kez bile çalışırsa tablo uzar.
  static const _tableDays = 30;

  String _dateKey(DateTime d) => d.toIso8601String().substring(0, 10);

  static const _prayerNamesOrdered = [
    'İmsak',
    'Güneş',
    'Öğle',
    'İkindi',
    'Akşam',
    'Yatsı',
  ];

  /// Üç widget'ın da verisini tazeler ve native tarafa haber verir.
  /// Herhangi bir adım başarısız olursa (ör. konum yok) sessizce devam eder
  /// — widget'lar açık aşamayı atlayıp elindeki son veriyle görünmeye devam
  /// eder, hata kullanıcıya sızmaz.
  /// [isBackground] true ise (bkz. BackgroundRefreshService'in WorkManager
  /// izolesi) konum izni istemi TAMAMEN atlanır — o bağlamda görünür bir
  /// Activity yok, sistem izin diyaloğu gösterilemez (bkz. LocationService.
  /// getCurrentPosition). Ön planda (uygulama açıkken) her zaman false.
  Future<void> refreshAll({bool isBackground = false}) async {
    await Future.wait([
      _refreshPrayer(isBackground: isBackground),
      _refreshZikir(),
      _refreshDailyContent(),
      _refreshAppearance(),
    ]);
    await _notifyNative();
  }

  /// Sadece görünüm ayarları değiştiğinde (bkz. WidgetAppearanceScreen)
  /// çağrılır — içerikleri yeniden hesaplamadan hızlıca yeniden çizdirir.
  Future<void> refreshAppearanceOnly() async {
    await _notifyNative();
  }

  /// Zikir sayacı arttığında/sıfırlandığında (bkz. ZikirSayacScreen) çağrılır.
  /// Konum gerektirmediği için hızlıdır; widget açık ekrandaysa anında
  /// güncellenmesini sağlar (sayacın kendisi zaten paylaşılan
  /// 'zikirCurrentCount' anahtarı üzerinden anlık senkron).
  Future<void> refreshZikirAndNotify() async {
    await _refreshZikir();
    await _notifyNative();
  }

  // ÖNCEDEN: yalnızca BUGÜNÜN vakitleri yazılıyordu ve bunun için her
  // seferinde konum gerekiyordu. Arka planda (WorkManager) konum çoğu
  // zaman alınamadığından widget ertesi gün eski günün vakitlerinde
  // kalıyordu. ŞİMDİ: konumla (yoksa son kaydedilen konumla) 30 günlük
  // vakit tablosu yazılıyor; native widget bugünün tarihine göre okuyor.
  Future<void> _refreshPrayer({bool isBackground = false}) async {
    try {
      final result = await _getPrayerTimes(
        requestPermissionIfNeeded: !isBackground,
      ).timeout(
        const Duration(seconds: 12),
        onTimeout: () => null,
      );

      double? lat = result?.latitude;
      double? lng = result?.longitude;
      if (lat != null && lng != null) {
        await _storage.setLastPrayerLocation(lat, lng);
      } else {
        lat = _storage.lastPrayerLat;
        lng = _storage.lastPrayerLng;
      }
      if (lat == null || lng == null) return; // hiç konum yok

      final coords = Coordinates(lat, lng);
      final params = CalculationMethod.turkey.getParameters();
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day);
      final table = <String, dynamic>{};
      List<DateTime>? todayTimes;

      for (var i = 0; i < _tableDays; i++) {
        final day = base.add(Duration(days: i));
        final pt = PrayerTimes(coords, DateComponents.from(day), params);
        final times = [
          pt.fajr,
          pt.sunrise,
          pt.dhuhr,
          pt.asr,
          pt.maghrib,
          pt.isha,
        ];
        todayTimes ??= times;
        table[_dateKey(day)] = {
          't': times.map((t) => t.toIso8601String()).toList(),
          'h': _hijriString(day),
        };
      }

      await _storage.setWidgetPrayerNames(_prayerNamesOrdered.join(','));
      await _storage.setWidgetPrayerDays(jsonEncode(table));
      // Eski tek günlük anahtarlar da yazılmaya devam ediyor (geri uyum —
      // tablo bir şekilde okunamazsa native taraf bunlara düşer).
      await _storage.setWidgetPrayerTimesIso(
          todayTimes!.map((t) => t.toIso8601String()).join(','));
      await _storage.setWidgetPrayerHijri(_hijriString(now));
    } catch (_) {
      // Konum/izin yoksa widget son bilinen veriyi göstermeye devam eder.
    }
  }

  Future<void> _refreshZikir() async {
    try {
      final active = await _zikirRepo.getActiveZikir();
      await _storage.setWidgetZikirTarget(active.target);
      await _storage.setWidgetZikirTurkish(active.turkish);
      await _storage.setWidgetZikirArabic(active.arabic);

      // 30 günlük zikir tablosu — gün değişince widget kendiliğinden
      // yeni günün zikrine geçer.
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day);
      final table = <String, dynamic>{};
      for (var i = 0; i < _tableDays; i++) {
        final day = base.add(Duration(days: i));
        final z = await _zikirRepo.getZikirForDate(day);
        table[_dateKey(day)] = {'g': z.target, 't': z.turkish, 'a': z.arabic};
      }
      await _storage.setWidgetZikirDays(jsonEncode(table));
    } catch (_) {}
  }

  // Uygulamanın "günün içeriği" formülüyle (ContentRepository: yılın günü %
  // liste uzunluğu) birebir aynı — widget ile uygulama hep aynı içeriği
  // gösterir.
  int _dayOfYear(DateTime date) =>
      date.difference(DateTime(date.year, 1, 1)).inDays;

  Future<void> _refreshDailyContent() async {
    try {
      final esma = await _contentRepo.getTodayEsma();
      final ayet = await _contentRepo.getTodayAyet();
      final hadis = await _contentRepo.getTodayHadis();
      await _storage.setWidgetEsmaTr(esma.turkish);
      await _storage.setWidgetEsmaAr(esma.arabic);
      await _storage.setWidgetEsmaMeaning(esma.meaning);
      await _storage.setWidgetAyetText(ayet.turkish);
      await _storage.setWidgetAyetSource('${ayet.surah} ${ayet.ayahNumber}');
      await _storage.setWidgetHadisText(hadis.text);
      await _storage.setWidgetHadisSource(_cleanHadisSource(hadis.source));

      // 30 günlük içerik tablosu.
      final esmas = await _contentRepo.getEsmas();
      final ayets = await _contentRepo.getAyets();
      final hadises = await _contentRepo.getHadises();
      if (esmas.isEmpty || ayets.isEmpty || hadises.isEmpty) return;
      final now = DateTime.now();
      final base = DateTime(now.year, now.month, now.day);
      final table = <String, dynamic>{};
      for (var i = 0; i < _tableDays; i++) {
        final day = base.add(Duration(days: i));
        final doy = _dayOfYear(day);
        final e = esmas[doy % esmas.length];
        final a = ayets[doy % ayets.length];
        final h = hadises[doy % hadises.length];
        table[_dateKey(day)] = {
          'et': e.turkish,
          'ea': e.arabic,
          'em': e.meaning,
          'at': a.turkish,
          'as': '${a.surah} ${a.ayahNumber}',
          'ht': h.text,
          'hs': _cleanHadisSource(h.source),
        };
      }
      await _storage.setWidgetContentDays(jsonEncode(table));
    } catch (_) {}
  }

  /// Ham veri setindeki hadis kaynak alanları bazen "Tirmizî, demiştir ki,
  /// hadis hasendir" gibi tutarsız ek ifadeler içeriyor — widget'ta sadece
  /// kaynağın adı (ör. "Tirmizî, Buhârî") gösterilsin diye "demiştir" ailesi
  /// ifadeleri ve bunların bıraktığı yalın virgül artıklarını temizliyoruz.
  /// Not: sadece widget görünümü içindir, uygulama içindeki hadis detay
  /// ekranı ham veriyi olduğu gibi göstermeye devam eder.
  String _cleanHadisSource(String source) {
    var s = source;
    s = s.replaceAll(
      RegExp(r'\s*,?\s*demiş(tir)?(\s+ki)?\.?', caseSensitive: false),
      '',
    );
    s = s.replaceAll(RegExp(r'\s*,\s*,'), ',');
    s = s.replaceAll(RegExp(r'^\s*,\s*|\s*,\s*$'), '');
    s = s.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    return s;
  }

  Future<void> _refreshAppearance() async {
    // Görünüm ayarları zaten LocalStorage'da (varsayılanlarıyla) hazır;
    // burada ekstra bir şey yazmaya gerek yok, sadece native'in okuyacağı
    // anahtarların var olduğundan emin oluyoruz.
    if (_storage.widgetThemeMode.isEmpty) {
      await _storage.setWidgetThemeMode('signature');
    }
  }

  Future<void> _notifyNative() async {
    try {
      await _channel.invokeMethod('refreshAllWidgets');
    } catch (_) {
      // Widget eklentisiz platformlarda (iOS, web, masaüstü) bu kanal yok —
      // sessizce yut, uygulamanın geri kalanını etkilemesin.
    }
  }

  String _hijriString(DateTime now) {
    final h = _toHijri(now.year, now.month, now.day);
    const months = [
      '',
      'Muharrem',
      'Safer',
      'Rebiülevvel',
      'Rebiülahir',
      'Cemaziyelevvel',
      'Cemaziyelahir',
      'Recep',
      'Şaban',
      'Ramazan',
      'Şevval',
      'Zilkade',
      'Zilhicce',
    ];
    return '${h[2]} ${months[h[1]]} ${h[0]}';
  }

  // PrayerTimesWidget (in-app) ile birebir aynı hesaplama — tutarlılık için.
  List<int> _toHijri(int gy, int gm, int gd) {
    int a = (14 - gm) ~/ 12;
    int y = gy + 4800 - a;
    int m = gm + 12 * a - 3;
    int jdn = gd +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
        32045;
    int l = jdn - 1948440 + 10632;
    int n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    int j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    int hm = (24 * l) ~/ 709;
    int hd = l - (709 * hm) ~/ 24;
    int hy = 30 * n + j - 30;
    return [hy, hm, hd];
  }
}
