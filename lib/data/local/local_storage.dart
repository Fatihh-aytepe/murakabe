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

  // Kullanıcı kayıtlı mı?
  bool get isUserRegistered => _prefs.getBool('isRegistered') ?? false;
  Future<void> setUserRegistered(bool value) =>
      _prefs.setBool('isRegistered', value);

  // Kullanıcı ID
  String? get userId => _prefs.getString('userId');
  Future<void> setUserId(String id) => _prefs.setString('userId', id);

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

  // Teheccüd alarm
  bool get tahajjudEnabled => _prefs.getBool('tahajjudEnabled') ?? false;
  Future<void> setTahajjudEnabled(bool v) =>
      _prefs.setBool('tahajjudEnabled', v);

  bool get isDarkMode => _prefs.getBool('isDarkMode') ?? false;
  Future<void> setDarkMode(bool v) => _prefs.setBool('isDarkMode', v);

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

  // ── Firebase Auth migration ────────────────────────────────────────────────
  // Eski kullanıcılar Firebase Auth'a geçiş yaptı mı?
  bool get authMigrationDone => _prefs.getBool('authMigrationDone') ?? false;
  Future<void> setAuthMigrationDone() =>
      _prefs.setBool('authMigrationDone', true);

  // Alarm bildirim kanalı versiyonu (ses güncellemesi için)
  int get alarmChannelVersion => _prefs.getInt('alarm_channel_version') ?? 0;
  Future<void> setAlarmChannelVersion(int v) =>
      _prefs.setInt('alarm_channel_version', v);

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
    accounts.removeWhere((a) => a['uid'] == uid);
    accounts.insert(0, {
      'uid': uid,
      'email': email,
      'name': name,
      'lastUsed': DateTime.now().toIso8601String(),
    });
    await _prefs.setString('savedAccounts', jsonEncode(accounts));
  }

  Future<void> removeAccount(String uid) async {
    final accounts = getSavedAccounts();
    accounts.removeWhere((a) => a['uid'] == uid);
    await _prefs.setString('savedAccounts', jsonEncode(accounts));
  }

  // ── Esmâ okuma serisi ─────────────────────────────────────────────────────
  int get esmaStreak => _prefs.getInt('esmaStreak') ?? 0;
  Future<void> setEsmaStreak(int v) => _prefs.setInt('esmaStreak', v);
  String? get lastEsmaDate => _prefs.getString('lastEsmaDate');
  Future<void> setLastEsmaDate(String d) => _prefs.setString('lastEsmaDate', d);
  int get lastRewardedEsmaStreak => _prefs.getInt('lastRewardedEsmaStreak') ?? 0;
  Future<void> setLastRewardedEsmaStreak(int v) =>
      _prefs.setInt('lastRewardedEsmaStreak', v);

  // ── Hadis okuma serisi ────────────────────────────────────────────────────
  int get hadisStreak => _prefs.getInt('hadisStreak') ?? 0;
  Future<void> setHadisStreak(int v) => _prefs.setInt('hadisStreak', v);
  String? get lastHadisDate => _prefs.getString('lastHadisDate');
  Future<void> setLastHadisDate(String d) =>
      _prefs.setString('lastHadisDate', d);
  int get lastRewardedHadisStreak => _prefs.getInt('lastRewardedHadisStreak') ?? 0;
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
}
