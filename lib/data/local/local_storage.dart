import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// SharedPreferences'ı diskten yeniden okur. `_prefs` uygulama açılışında
  /// BİR KEZ alınıp bellekte önbelleklendiği için, ana ekran widget'ları gibi
  /// Flutter motorunun dışından (native Kotlin kodu) doğrudan diske yazan
  /// taraflar yaptığı değişiklikler, uygulama arka plandan öne dönene kadar
  /// bu önbelleğe hiç yansımaz — ör. zikir sayacı widget'tan artırıldığında
  /// uygulama içi ekran eski sayıyı göstermeye devam eder. Bu metod, o
  /// senkron kopukluğunu gidermek için uygulama öne döndüğünde/ilgili
  /// ekranlar açıldığında çağrılmalı.
  Future<void> reload() => _prefs.reload();

  // Kullanıcı kayıtlı mı?
  bool get isUserRegistered => _prefs.getBool('isRegistered') ?? false;
  Future<void> setUserRegistered(bool value) =>
      _prefs.setBool('isRegistered', value);

  // Kullanıcı ID
  String? get userId => _prefs.getString('userId');
  Future<void> setUserId(String id) => _prefs.setString('userId', id);

  /// DÜZELTME: çıkış yaparken önceden `setUserId('')` çağrılıyordu —
  /// bu, anahtarı BOŞ STRING ile bırakır, SİLMEZ. `userId` getter'ı bu
  /// durumda `null` değil `''` döner; kod tabanındaki yaygın
  /// `if (uid != null) { ... _firebase.saveX(uid!, ...) }` deseni bu
  /// kontrolü GEÇER ve boş bir UID ile Firestore çağrıları yapılmaya
  /// çalışılabilirdi (çoğu zaten try/catch içinde olduğundan sessizce
  /// yutuluyordu, ama bu yine de yanlış ve kırılgan bir durumdu). Bu
  /// metod anahtarı gerçekten KALDIRIR, `userId` sonrasında gerçek
  /// `null` döner.
  Future<void> clearUserId() => _prefs.remove('userId');

  // Admin kontrolü
  bool get isAdmin => _prefs.getBool('isAdmin') ?? false;
  Future<void> setAdmin(bool value) => _prefs.setBool('isAdmin', value);

  // Günün içerik indeksleri
  int get todayEsmaIndex => _prefs.getInt('esmaIndex') ?? 0;
  Future<void> setEsmaIndex(int i) => _prefs.setInt('esmaIndex', i);

  int get todayHadisIndex => _prefs.getInt('hadisIndex') ?? 0;
  Future<void> setHadisIndex(int i) => _prefs.setInt('hadisIndex', i);

  int get todayAyetIndex => _prefs.getInt('ayetIndex') ?? 0;
  Future<void> setAyetIndex(int i) => _prefs.setInt('ayetIndex', i);

  // Son güncelleme tarihi
  String? get lastUpdateDate => _prefs.getString('lastUpdateDate');
  Future<void> setLastUpdateDate(String d) =>
      _prefs.setString('lastUpdateDate', d);

  // Ertelenen güncelleme versiyonu ("Sonra" denilen sürümü tekrar sorma)
  String? get skippedVersion => _prefs.getString('skippedVersion');
  Future<void> setSkippedVersion(String v) =>
      _prefs.setString('skippedVersion', v);

  // Teheccüd alarm
  bool get tahajjudEnabled => _prefs.getBool('tahajjudEnabled') ?? false;
  Future<void> setTahajjudEnabled(bool v) =>
      _prefs.setBool('tahajjudEnabled', v);

  bool get isDarkMode => _prefs.getBool('isDarkMode') ?? false;
  Future<void> setDarkMode(bool v) => _prefs.setBool('isDarkMode', v);

  // Notlar ekranı görünüm tercihi: 'list' veya 'grid'
  String get notesViewMode => _prefs.getString('notesViewMode') ?? 'list';
  Future<void> setNotesViewMode(String v) =>
      _prefs.setString('notesViewMode', v);

  String? get profilePhotoPath => _prefs.getString('profilePhotoPath');
  Future<void> setProfilePhotoPath(String path) =>
      _prefs.setString('profilePhotoPath', path);

  // İlk açılış (hoş geldin ödülü)
  bool get isFirstOpen => _prefs.getBool('isFirstOpen') ?? true;
  Future<void> setFirstOpenDone() => _prefs.setBool('isFirstOpen', false);

  // Streak ödülü son verilen milestone
  int get lastRewardedStreak => _prefs.getInt('lastRewardedStreak') ?? 0;
  Future<void> setLastRewardedStreak(int s) =>
      _prefs.setInt('lastRewardedStreak', s);

  // Teheccüd alarm kurulduğu gece tarihi
  String? get tahajjudAlarmDate => _prefs.getString('tahajjudAlarmDate');
  Future<void> setTahajjudAlarmDate(String d) =>
      _prefs.setString('tahajjudAlarmDate', d);

  // İçerik etkileşim sayaçları
  int get esmaOpenCount => _prefs.getInt('esmaOpenCount') ?? 0;
  Future<void> incrementEsmaCount() =>
      _prefs.setInt('esmaOpenCount', esmaOpenCount + 1);

  int get ayetOpenCount => _prefs.getInt('ayetOpenCount') ?? 0;
  Future<void> incrementAyetCount() =>
      _prefs.setInt('ayetOpenCount', ayetOpenCount + 1);

  int get hadisOpenCount => _prefs.getInt('hadisOpenCount') ?? 0;
  Future<void> incrementHadisCount() =>
      _prefs.setInt('hadisOpenCount', hadisOpenCount + 1);

  // Alarm ses seçimi
  String? get alarmSoundId => _prefs.getString('alarmSoundId');
  Future<void> setAlarmSoundId(String id) =>
      _prefs.setString('alarmSoundId', id);

  // Kullanıcının yüklediği özel alarm sesleri — JSON liste olarak saklanır:
  // [{"id": "...", "label": "...", "contentUri": "content://media/..."}]
  // contentUri, native tarafta MediaStore'a (IS_NOTIFICATION=1 ile) eklenen
  // dosyanın sistem çapında okunabilir URI'sidir — ses fiziksel olarak
  // cihazın Bildirimler/Murakabe klasöründe, MediaStore üzerinden tutulur.
  List<Map<String, String>> get customAlarmSounds {
    final raw = _prefs.getString('customAlarmSounds');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> setCustomAlarmSounds(List<Map<String, String>> sounds) =>
      _prefs.setString('customAlarmSounds', jsonEncode(sounds));

  // ── Firebase Auth migration ────────────────────────────────────────────────
  // Eski kullanıcılar Firebase Auth'a geçiş yaptı mı?
  bool get authMigrationDone => _prefs.getBool('authMigrationDone') ?? false;
  Future<void> setAuthMigrationDone() =>
      _prefs.setBool('authMigrationDone', true);

  // Alarm bildirim kanalı versiyonu (ses güncellemesi için)
  int get alarmChannelVersion => _prefs.getInt('alarm_channel_version') ?? 0;
  Future<void> setAlarmChannelVersion(int v) =>
      _prefs.setInt('alarm_channel_version', v);

  // ── Bildirim + konum izin akışı ──────────────────────────────────────────
  // Kayıt/giriş sonrası izin tanıtım ekranı bir kez gösterildi mi?
  // (Play Store: izinler kullanıcı akışının doğal bir parçası olarak,
  // gerekçesiyle birlikte istenmeli — uygulama açılır açılmaz değil.)
  bool get permissionOnboardingDone =>
      _prefs.getBool('permissionOnboardingDone') ?? false;
  Future<void> setPermissionOnboardingDone() =>
      _prefs.setBool('permissionOnboardingDone', true);

  // ── Ana ekran widget'ları ─────────────────────────────────────────────────
  // Bu değerler native (Kotlin) widget kodu tarafından da OKUNUYOR — anahtar
  // isimlerini değiştirirsen android/app/.../WidgetPrefs.kt içindeki KEY_*
  // sabitlerini de güncellemen gerekir. shared_preferences eklentisi Android
  // tarafında bu anahtarları "flutter.<key>" olarak saklar.

  // Namaz vakitleri widget'ı — 6 vakit + hicri tarih. Vakit isimleri ve ISO
  // zamanları paralel iki liste olarak virgülle ayrılmış tek string halinde
  // tutulur (native tarafta basit split ile okunur).
  String get widgetPrayerHijri => _prefs.getString('widget_prayer_hijri') ?? '';
  Future<void> setWidgetPrayerHijri(String v) =>
      _prefs.setString('widget_prayer_hijri', v);

  String get widgetPrayerNames => _prefs.getString('widget_prayer_names') ?? '';
  Future<void> setWidgetPrayerNames(String v) =>
      _prefs.setString('widget_prayer_names', v);

  String get widgetPrayerTimesIso =>
      _prefs.getString('widget_prayer_times_iso') ?? '';
  Future<void> setWidgetPrayerTimesIso(String v) =>
      _prefs.setString('widget_prayer_times_iso', v);

  // Zikir sayacı widget'ı — sayacın kendisi mevcut 'zikirCurrentCount'
  // anahtarını paylaşır (widget'tan +1 dokunuşu doğrudan bu anahtarı
  // günceller, uygulama açılınca ekstra senkron gerekmez).
  int get widgetZikirTarget => _prefs.getInt('widget_zikir_target') ?? 33;
  Future<void> setWidgetZikirTarget(int v) =>
      _prefs.setInt('widget_zikir_target', v);

  String get widgetZikirTurkish =>
      _prefs.getString('widget_zikir_turkish') ?? '';
  Future<void> setWidgetZikirTurkish(String v) =>
      _prefs.setString('widget_zikir_turkish', v);

  String get widgetZikirArabic => _prefs.getString('widget_zikir_arabic') ?? '';
  Future<void> setWidgetZikirArabic(String v) =>
      _prefs.setString('widget_zikir_arabic', v);

  // Günlük içerik widget'ı — esmâ/âyet/hadis, ok ile aralarında gezinilir.
  String get widgetEsmaTr => _prefs.getString('widget_esma_tr') ?? '';
  Future<void> setWidgetEsmaTr(String v) => _prefs.setString('widget_esma_tr', v);
  String get widgetEsmaAr => _prefs.getString('widget_esma_ar') ?? '';
  Future<void> setWidgetEsmaAr(String v) => _prefs.setString('widget_esma_ar', v);
  String get widgetEsmaMeaning => _prefs.getString('widget_esma_meaning') ?? '';
  Future<void> setWidgetEsmaMeaning(String v) =>
      _prefs.setString('widget_esma_meaning', v);

  String get widgetAyetText => _prefs.getString('widget_ayet_text') ?? '';
  Future<void> setWidgetAyetText(String v) =>
      _prefs.setString('widget_ayet_text', v);
  String get widgetAyetSource => _prefs.getString('widget_ayet_source') ?? '';
  Future<void> setWidgetAyetSource(String v) =>
      _prefs.setString('widget_ayet_source', v);

  String get widgetHadisText => _prefs.getString('widget_hadis_text') ?? '';
  Future<void> setWidgetHadisText(String v) =>
      _prefs.setString('widget_hadis_text', v);
  String get widgetHadisSource => _prefs.getString('widget_hadis_source') ?? '';
  Future<void> setWidgetHadisSource(String v) =>
      _prefs.setString('widget_hadis_source', v);

  // 0=esmâ, 1=âyet, 2=hadis — widget üzerindeki ‹ › okları bu indeksi
  // doğrudan native tarafta değiştirir; Dart tarafı sadece ilk değeri yazar.
  int get widgetContentIndex => _prefs.getInt('widget_content_index') ?? 0;
  Future<void> setWidgetContentIndex(int v) =>
      _prefs.setInt('widget_content_index', v);

  // ── Widget görünüm ayarları ──────────────────────────────────────────────
  // 'signature' (uygulamanın imza teması — lacivert/altın/turkuaz, varsayılan),
  // 'light' veya 'dark'.
  String get widgetThemeMode =>
      _prefs.getString('widget_theme_mode') ?? 'signature';
  Future<void> setWidgetThemeMode(String v) =>
      _prefs.setString('widget_theme_mode', v);

  // Arka plan saydamlığı: 0 (tamamen saydam) – 100 (tamamen opak).
  int get widgetBgOpacity => _prefs.getInt('widget_bg_opacity') ?? 100;
  Future<void> setWidgetBgOpacity(int v) =>
      _prefs.setInt('widget_bg_opacity', v);

  // Vurgu rengi — '#' olmadan 6 haneli hex (ör. 'D4AF37').
  String get widgetAccentHex =>
      _prefs.getString('widget_accent_hex') ?? 'D4AF37';
  Future<void> setWidgetAccentHex(String v) =>
      _prefs.setString('widget_accent_hex', v);

  // ── Hesap silme ──────────────────────────────────────────────────────────
  /// Hesap kalıcı olarak silinirken tüm yerel tercih/ayar verisini temizler
  /// (kayıtlı hesap listesi dahil). Cihazda bu kullanıcıya ait hiçbir iz
  /// bırakmaz; bir sonraki açılışta uygulama sıfırdan kayıt/giriş ekranına
  /// döner.
  /// [deletedUid] verilirse, tüm tercih/ayar verisi temizlenir AMA kayıtlı
  /// hesaplar listesinden (`savedAccounts`) yalnızca SİLİNEN hesap çıkarılır
  /// — cihazda başka hesaplar da kayıtlıysa hesap değiştirme ekranındaki
  /// listeleri kaybetmezler. Önceden `_prefs.clear()` doğrudan çağrıldığı
  /// için tek bir hesabı silmek cihazdaki TÜM kayıtlı hesap listesini de
  /// siliyordu. Geriye dönük uyumluluk için [deletedUid] verilmezse eski
  /// davranış (tam temizlik) korunur.
  Future<void> clearAllForAccountDeletion([String? deletedUid]) async {
    if (deletedUid == null || deletedUid.isEmpty) {
      await _prefs.clear();
      return;
    }
    final accounts = getSavedAccounts()
      ..removeWhere((a) => a['uid'] == deletedUid);
    await _prefs.clear();
    await _prefs.setString('savedAccounts', jsonEncode(accounts));
  }

  /// Farklı bir hesaba GEÇİLİRKEN (hesap silme değil) çağrılır. Kayıtlı
  /// hesaplar listesini (`savedAccounts` — hesap değiştirme ekranında
  /// gösterilir) korur, geri kalan TÜM yerel tercih/ayar/streak/rozet
  /// verisini temizler. Bu olmadan, örn. A hesabından B hesabına aynı
  /// cihazda geçildiğinde B, A'nın streak/rozet/bildirim tercihi gibi
  /// verilerini miras alıyordu (bkz. DatabaseHelper.wipeAllTables — SQLite
  /// tarafındaki eşleniği, ikisi birlikte çağrılmalı).
  Future<void> clearForAccountSwitch() async {
    final savedAccountsRaw = _prefs.getString('savedAccounts');
    await _prefs.clear();
    if (savedAccountsRaw != null) {
      await _prefs.setString('savedAccounts', savedAccountsRaw);
    }
  }

  // ── Çoklu hesap yönetimi ─────────────────────────────────────────────────
  // Her hesap: {uid, email, name, lastUsed}
  List<Map<String, dynamic>> getSavedAccounts() {
    final raw = _prefs.getString('savedAccounts');
    if (raw == null || raw.isEmpty) return [];
    try {
      return List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAccount({
    required String uid,
    required String email,
    required String name,
  }) async {
    final accounts = getSavedAccounts();
    // Sadece UID'e göre duplicate kontrolü — email değişse bile aynı hesap
    accounts.removeWhere((a) => a['uid'] == uid);
    accounts.insert(0, {
      'uid': uid,
      'email': email,
      'name': name,
      'lastUsed': DateTime.now().toIso8601String(),
      'isLoggedIn': true,
    });
    await _prefs.setString('savedAccounts', jsonEncode(accounts));
  }

  /// Çıkış yapıldığında hesabı listeden silmez, sadece oturum kapalı işaretler.
  Future<void> markAccountLoggedOut(String uid) async {
    final accounts = getSavedAccounts();
    final idx = accounts.indexWhere((a) => a['uid'] == uid);
    if (idx >= 0) {
      accounts[idx] = {...accounts[idx], 'isLoggedIn': false};
      await _prefs.setString('savedAccounts', jsonEncode(accounts));
    }
  }

  Future<void> removeAccount(String uid) async {
    final accounts = getSavedAccounts();
    accounts.removeWhere((a) => a['uid'] == uid);
    await _prefs.setString('savedAccounts', jsonEncode(accounts));
  }

  /// UserRepository.restoreFromFirestore'un alt koleksiyonları (notlar,
  /// görevler, ödüller vb.) TAM olarak geri yükleyemediği durumlarda o
  /// hesabın uid'sini burada tutar — HomeScreen açılışında best-effort
  /// olarak retryPendingSubcollectionRestore ile tekrar denenir.
  String? get pendingSubcollectionRestoreUid =>
      _prefs.getString('pendingSubcollectionRestoreUid');
  Future<void> setPendingSubcollectionRestore(String uid) =>
      _prefs.setString('pendingSubcollectionRestoreUid', uid);
  Future<void> clearPendingSubcollectionRestore() =>
      _prefs.remove('pendingSubcollectionRestoreUid');

  /// Kayıtlı hesap kartındaki e-postayı günceller — bkz. UserRepository.
  /// syncEmailFromAuth: kullanıcı e-posta değiştirip Firebase'in gönderdiği
  /// doğrulama linkine tıkladığında, Auth'taki e-posta arka planda
  /// değişiyor; bu güncelleme yapılmazsa "kayıtlı hesaplar" listesindeki
  /// kart eski e-postayı göstermeye devam eder ve kullanıcı o karta
  /// dokununca artık geçersiz olan eski e-postayla giriş denemesi yapılır.
  Future<void> updateAccountEmail(String uid, String newEmail) async {
    final accounts = getSavedAccounts();
    final idx = accounts.indexWhere((a) => a['uid'] == uid);
    if (idx >= 0 && accounts[idx]['email'] != newEmail) {
      accounts[idx] = {...accounts[idx], 'email': newEmail};
      await _prefs.setString('savedAccounts', jsonEncode(accounts));
    }
  }

  // ── Esmâ okuma serisi ─────────────────────────────────────────────────────
  int get esmaStreak => _prefs.getInt('esmaStreak') ?? 0;
  Future<void> setEsmaStreak(int v) => _prefs.setInt('esmaStreak', v);
  String? get lastEsmaDate => _prefs.getString('lastEsmaDate');
  Future<void> setLastEsmaDate(String d) => _prefs.setString('lastEsmaDate', d);
  int get lastRewardedEsmaStreak =>
      _prefs.getInt('lastRewardedEsmaStreak') ?? 0;
  Future<void> setLastRewardedEsmaStreak(int v) =>
      _prefs.setInt('lastRewardedEsmaStreak', v);

  // ── Hadis okuma serisi ────────────────────────────────────────────────────
  int get hadisStreak => _prefs.getInt('hadisStreak') ?? 0;
  Future<void> setHadisStreak(int v) => _prefs.setInt('hadisStreak', v);
  String? get lastHadisDate => _prefs.getString('lastHadisDate');
  Future<void> setLastHadisDate(String d) =>
      _prefs.setString('lastHadisDate', d);
  int get lastRewardedHadisStreak =>
      _prefs.getInt('lastRewardedHadisStreak') ?? 0;
  Future<void> setLastRewardedHadisStreak(int v) =>
      _prefs.setInt('lastRewardedHadisStreak', v);

  // ── Kur\'ân serisi (lastRewardedStreak → kuran milestone izleyici) ─────────
  // Not: lastRewardedStreak mevcut alan; kuran için yeniden kullanılır.

  // ── Rozet milestone izleyiciler ───────────────────────────────────────────
  int get lastRewardedKuranBadge => _prefs.getInt('lrKuranBadge') ?? 0;
  Future<void> setLastRewardedKuranBadge(int v) =>
      _prefs.setInt('lrKuranBadge', v);

  int get lastRewardedEsmaBadge => _prefs.getInt('lrEsmaBadge') ?? 0;
  Future<void> setLastRewardedEsmaBadge(int v) =>
      _prefs.setInt('lrEsmaBadge', v);

  int get lastRewardedHadisBadge => _prefs.getInt('lrHadisBadge') ?? 0;
  Future<void> setLastRewardedHadisBadge(int v) =>
      _prefs.setInt('lrHadisBadge', v);

  int get lastRewardedKombineBadge => _prefs.getInt('lrKombineBadge') ?? 0;
  Future<void> setLastRewardedKombineBadge(int v) =>
      _prefs.setInt('lrKombineBadge', v);

  int get lastRewardedTahajjudBadge => _prefs.getInt('lrTahajjudBadge') ?? 0;
  Future<void> setLastRewardedTahajjudBadge(int v) =>
      _prefs.setInt('lrTahajjudBadge', v);

  bool get veteranBadgeAwarded => _prefs.getBool('veteranBadge') ?? false;
  Future<void> setVeteranBadgeAwarded() => _prefs.setBool('veteranBadge', true);

  // Teheccüd aylık kart: son verilen ay-yıl kaydı (örn. "2026-05")
  String? get lastTahajjudMonthlyCard =>
      _prefs.getString('lastTahajjudMonthlyCard');
  Future<void> setLastTahajjudMonthlyCard(String ym) =>
      _prefs.setString('lastTahajjudMonthlyCard', ym);

  // Profilde gösterilecek rozet ID\'si
  String? get displayedBadgeId => _prefs.getString('displayedBadgeId');
  Future<void> setDisplayedBadgeId(String id) =>
      _prefs.setString('displayedBadgeId', id);
  Future<void> clearDisplayedBadgeId() => _prefs.remove('displayedBadgeId');

  // Altın çerçeve (1 yıllık özel özellik)
  bool get goldenFrameUnlocked => _prefs.getBool('goldenFrame') ?? false;
  Future<void> setGoldenFrameUnlocked() => _prefs.setBool('goldenFrame', true);

  // ── Firestore yedekleme ───────────────────────────────────────────────────
  // Cihaz yerel verilerinin Firestore'a gönderilecek haritası.
  // Yeni alan eklendiğinde buraya ve restoreFromMap'e de ekle.
  Map<String, dynamic> toSyncMap() => {
        'esmaStreak': esmaStreak,
        'lastEsmaDate': lastEsmaDate ?? '',
        'lastRewardedEsmaStreak': lastRewardedEsmaStreak,
        'hadisStreak': hadisStreak,
        'lastHadisDate': lastHadisDate ?? '',
        'lastRewardedHadisStreak': lastRewardedHadisStreak,
        'lastRewardedStreak': lastRewardedStreak,
        'lastRewardedKuranBadge': lastRewardedKuranBadge,
        'lastRewardedEsmaBadge': lastRewardedEsmaBadge,
        'lastRewardedHadisBadge': lastRewardedHadisBadge,
        'lastRewardedKombineBadge': lastRewardedKombineBadge,
        'lastRewardedTahajjudBadge': lastRewardedTahajjudBadge,
        'veteranBadgeAwarded': veteranBadgeAwarded,
        'isFirstOpen': isFirstOpen,
        'goldenFrameUnlocked': goldenFrameUnlocked,
        'tahajjudEnabled': tahajjudEnabled,
        'isDarkMode': isDarkMode,
        'displayedBadgeId': displayedBadgeId ?? '',
        'lastTahajjudMonthlyCard': lastTahajjudMonthlyCard ?? '',
        'lastRewardedStreak_v2': lastRewardedStreak,
      };

  // Firestore'dan gelen Map ile SharedPreferences'ı geri yükler.
  // Mevcut değerlerin üzerine yalnızca Firestore'daki daha büyük değerler yazılır
  // (geriye doğru veri kaybını önlemek için).
  Future<void> restoreFromMap(Map<String, dynamic> data) async {
    Future<void> bigger(
        int current, dynamic raw, Future<void> Function(int) setter) async {
      final v = raw is int ? raw : (raw as num?)?.toInt();
      if (v != null && v > current) await setter(v);
    }

    await bigger(esmaStreak, data['esmaStreak'], setEsmaStreak);
    await bigger(hadisStreak, data['hadisStreak'], setHadisStreak);
    await bigger(lastRewardedEsmaStreak, data['lastRewardedEsmaStreak'],
        setLastRewardedEsmaStreak);
    await bigger(lastRewardedHadisStreak, data['lastRewardedHadisStreak'],
        setLastRewardedHadisStreak);
    await bigger(
        lastRewardedStreak, data['lastRewardedStreak'], setLastRewardedStreak);
    await bigger(lastRewardedKuranBadge, data['lastRewardedKuranBadge'],
        setLastRewardedKuranBadge);
    await bigger(lastRewardedEsmaBadge, data['lastRewardedEsmaBadge'],
        setLastRewardedEsmaBadge);
    await bigger(lastRewardedHadisBadge, data['lastRewardedHadisBadge'],
        setLastRewardedHadisBadge);
    await bigger(lastRewardedKombineBadge, data['lastRewardedKombineBadge'],
        setLastRewardedKombineBadge);
    await bigger(lastRewardedTahajjudBadge, data['lastRewardedTahajjudBadge'],
        setLastRewardedTahajjudBadge);

    final esmaDate = data['lastEsmaDate'] as String? ?? '';
    if (esmaDate.isNotEmpty &&
        (lastEsmaDate == null || esmaDate.compareTo(lastEsmaDate!) > 0)) {
      await setLastEsmaDate(esmaDate);
    }
    final hadisDate = data['lastHadisDate'] as String? ?? '';
    if (hadisDate.isNotEmpty &&
        (lastHadisDate == null || hadisDate.compareTo(lastHadisDate!) > 0)) {
      await setLastHadisDate(hadisDate);
    }

    if (data['veteranBadgeAwarded'] == true && !veteranBadgeAwarded) {
      await setVeteranBadgeAwarded();
    }
    if (data['isFirstOpen'] == false && isFirstOpen) {
      await setFirstOpenDone();
    }
    if (data['goldenFrameUnlocked'] == true && !goldenFrameUnlocked) {
      await setGoldenFrameUnlocked();
    }
    if (data['tahajjudEnabled'] is bool) {
      await setTahajjudEnabled(data['tahajjudEnabled'] as bool);
    }
    if (data['isDarkMode'] is bool) {
      await setDarkMode(data['isDarkMode'] as bool);
    }
    final badge = data['displayedBadgeId'] as String? ?? '';
    if (badge.isNotEmpty && displayedBadgeId == null) {
      await setDisplayedBadgeId(badge);
    }
    final monthly = data['lastTahajjudMonthlyCard'] as String? ?? '';
    if (monthly.isNotEmpty && lastTahajjudMonthlyCard == null) {
      await setLastTahajjudMonthlyCard(monthly);
    }
  }

  // ── Bildirim tercihleri ───────────────────────────────────────────────────
  bool get esmaNotifEnabled => _prefs.getBool('notif_esma') ?? true;
  bool get hadisNotifEnabled => _prefs.getBool('notif_hadis') ?? true;
  bool get ayetNotifEnabled => _prefs.getBool('notif_ayet') ?? true;
  bool get kuranNotifEnabled => _prefs.getBool('notif_kuran') ?? true;
  Future<void> setEsmaNotif(bool v) => _prefs.setBool('notif_esma', v);
  Future<void> setHadisNotif(bool v) => _prefs.setBool('notif_hadis', v);
  Future<void> setAyetNotif(bool v) => _prefs.setBool('notif_ayet', v);
  Future<void> setKuranNotif(bool v) => _prefs.setBool('notif_kuran', v);

  // Bildirim saatleri — kullanıcı ayarlar ekranından değiştirebilir.
  // Varsayılanlar, önceden koddaki sabit saatlerle aynı: Esma 09:00,
  // Hadis 13:00, Ayet 18:00, Kuran Hatırlatıcı 19:00.
  int get esmaNotifHour => _prefs.getInt('esmaNotifHour') ?? 9;
  int get esmaNotifMinute => _prefs.getInt('esmaNotifMinute') ?? 0;
  Future<void> setEsmaNotifTime(int hour, int minute) async {
    await _prefs.setInt('esmaNotifHour', hour);
    await _prefs.setInt('esmaNotifMinute', minute);
  }

  int get hadisNotifHour => _prefs.getInt('hadisNotifHour') ?? 13;
  int get hadisNotifMinute => _prefs.getInt('hadisNotifMinute') ?? 0;
  Future<void> setHadisNotifTime(int hour, int minute) async {
    await _prefs.setInt('hadisNotifHour', hour);
    await _prefs.setInt('hadisNotifMinute', minute);
  }

  int get ayetNotifHour => _prefs.getInt('ayetNotifHour') ?? 18;
  int get ayetNotifMinute => _prefs.getInt('ayetNotifMinute') ?? 0;
  Future<void> setAyetNotifTime(int hour, int minute) async {
    await _prefs.setInt('ayetNotifHour', hour);
    await _prefs.setInt('ayetNotifMinute', minute);
  }

  int get kuranNotifHour => _prefs.getInt('kuranNotifHour') ?? 19;
  int get kuranNotifMinute => _prefs.getInt('kuranNotifMinute') ?? 0;
  Future<void> setKuranNotifTime(int hour, int minute) async {
    await _prefs.setInt('kuranNotifHour', hour);
    await _prefs.setInt('kuranNotifMinute', minute);
  }

// ── Zikir bildirimi ─────────────────────────────────────────────────────
  bool get zikirNotifEnabled => _prefs.getBool('notif_zikir') ?? true;
  Future<void> setZikirNotif(bool v) => _prefs.setBool('notif_zikir', v);

  // Varsayılan saat: 20:00 — kullanıcı ayarlar ekranından değiştirebilir
  int get zikirNotifHour => _prefs.getInt('zikirNotifHour') ?? 20;
  int get zikirNotifMinute => _prefs.getInt('zikirNotifMinute') ?? 0;
  Future<void> setZikirNotifTime(int hour, int minute) async {
    await _prefs.setInt('zikirNotifHour', hour);
    await _prefs.setInt('zikirNotifMinute', minute);
  }

  // ── Topluluk sohbet okunma takibi ─────────────────────────────────────────
  // hasChatUnread: bu toplulukta okunmamış mesaj var mı (push bildirim kontrolü)
  bool hasChatUnread(String communityId) =>
      _prefs.getBool('chat_unread_$communityId') ?? false;
  Future<void> setChatUnread(String communityId, bool value) =>
      _prefs.setBool('chat_unread_$communityId', value);

  // getChatReadTime: kullanıcının bu topluluğu en son açtığı zaman (epoch ms)
  int getChatReadTime(String communityId) =>
      _prefs.getInt('chat_read_at_$communityId') ?? 0;
  Future<void> setChatReadTime(String communityId) => _prefs.setInt(
      'chat_read_at_$communityId', DateTime.now().millisecondsSinceEpoch);

  // ── Gizlenmiş duyurular (topluluk bazında, sadece bu cihazda) ─────────────
  // Key: hidden_announcements_{communityId} | Value: JSON string liste

  Set<String> getHiddenAnnouncements(String communityId) {
    final raw = _prefs.getString('hidden_announcements_$communityId');
    if (raw == null || raw.isEmpty) return {};
    try {
      return List<String>.from(jsonDecode(raw) as List).toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> addHiddenAnnouncement(String communityId, String docId) async {
    final current = getHiddenAnnouncements(communityId);
    current.add(docId);
    await _prefs.setString(
        'hidden_announcements_$communityId', jsonEncode(current.toList()));
  }

  Future<void> clearHiddenAnnouncements(String communityId) async {
    await _prefs.remove('hidden_announcements_$communityId');
  } // ── Zikir ────────────────────────────────────────────────────────────────

  String get zikirMode => _prefs.getString('zikirMode') ?? 'default';
  Future<void> setZikirMode(String mode) => _prefs.setString('zikirMode', mode);

  int get zikirDefaultTarget => _prefs.getInt('zikirDefaultTarget') ?? 33;
  Future<void> setZikirDefaultTarget(int t) =>
      _prefs.setInt('zikirDefaultTarget', t);

  String? get customZikirTurkish => _prefs.getString('customZikirTurkish');
  Future<void> setCustomZikirTurkish(String v) =>
      _prefs.setString('customZikirTurkish', v);

  String? get customZikirArabic => _prefs.getString('customZikirArabic');
  Future<void> setCustomZikirArabic(String v) =>
      _prefs.setString('customZikirArabic', v);

  int get customZikirTarget => _prefs.getInt('customZikirTarget') ?? 33;
  Future<void> setCustomZikirTarget(int t) =>
      _prefs.setInt('customZikirTarget', t);

  String? get customZikirEndDate => _prefs.getString('customZikirEndDate');
  Future<void> setCustomZikirEndDate(String d) =>
      _prefs.setString('customZikirEndDate', d);
  Future<void> clearCustomZikirEndDate() => _prefs.remove('customZikirEndDate');

  int get zikirCurrentCount => _prefs.getInt('zikirCurrentCount') ?? 0;
  Future<void> setZikirCurrentCount(int c) =>
      _prefs.setInt('zikirCurrentCount', c);

  String? get zikirProgressDate => _prefs.getString('zikirProgressDate');
  Future<void> setZikirProgressDate(String d) =>
      _prefs.setString('zikirProgressDate', d);

  bool get zikirCelebrationShown =>
      _prefs.getBool('zikirCelebrationShown') ?? false;
  Future<void> setZikirCelebrationShown(bool v) =>
      _prefs.setBool('zikirCelebrationShown', v);

  // ── Ana ekran bölüm görünürlüğü (kullanıcı gizleyebilir) ──────────────────
  bool get tasksSectionHidden => _prefs.getBool('tasksSectionHidden') ?? false;
  Future<void> setTasksSectionHidden(bool v) =>
      _prefs.setBool('tasksSectionHidden', v);

  bool get communitySectionHidden =>
      _prefs.getBool('communitySectionHidden') ?? false;
  Future<void> setCommunitySectionHidden(bool v) =>
      _prefs.setBool('communitySectionHidden', v);

  // ── Bottom nav kısayolları (Ana Sayfa hariç, sıralı en fazla 3 id) ────────
  List<String> get navShortcutIds {
    final raw = _prefs.getStringList('navShortcutIds');
    if (raw == null) return ['notes', 'community', 'profile'];
    return raw;
  }

  Future<void> setNavShortcutIds(List<String> ids) =>
      _prefs.setStringList('navShortcutIds', ids);
}
