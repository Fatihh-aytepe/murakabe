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

  // İçerik etkileşim sayaçları (hangi ödül verileceğini belirler)
  int get esmaOpenCount => _prefs.getInt('esmaOpenCount') ?? 0;
  Future<void> incrementEsmaCount() =>
      _prefs.setInt('esmaOpenCount', esmaOpenCount + 1);

  int get ayetOpenCount => _prefs.getInt('ayetOpenCount') ?? 0;
  Future<void> incrementAyetCount() =>
      _prefs.setInt('ayetOpenCount', ayetOpenCount + 1);

  int get hadisOpenCount => _prefs.getInt('hadisOpenCount') ?? 0;
  Future<void> incrementHadisCount() =>
      _prefs.setInt('hadisOpenCount', hadisOpenCount + 1);

  // ── YENİ: Alarm ses seçimi ────────────────────────────────────────────────
  String? get alarmSoundId => _prefs.getString('alarmSoundId');
  Future<void> setAlarmSoundId(String id) =>
      _prefs.setString('alarmSoundId', id);
}
