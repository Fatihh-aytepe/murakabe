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
}
