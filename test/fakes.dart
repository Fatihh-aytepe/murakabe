import 'package:mockito/mockito.dart';
import 'package:murakabe/data/local/local_storage.dart';
import 'package:murakabe/data/models/badge_model.dart';
import 'package:murakabe/data/repositories/badge_repository.dart';
import 'package:murakabe/data/repositories/reward_repository.dart';

// ── FakeLocalStorage ─────────────────────────────────────────────────────────
// Yalnızca test edilen metotlarda kullanılan alanlar uygulanır.
// Geri kalanlar Fake.noSuchMethod aracılığıyla UnimplementedError fırlatır.

class FakeLocalStorage extends Fake implements LocalStorage {
  // Oturum yok (null): BadgeService/RewardService ödül sonrası Firestore'a
  // yedekleme yaparken `userId`'yi okuyor; null olduğunda yedeklemeyi
  // atlıyorlar — testlerde Firebase'e hiç dokunulmamış olur. Önceden bu alan
  // tanımlı olmadığı için tüm rozet/ödül testleri UnimplementedError ile
  // düşüyordu.
  @override
  String? userId;

  // Kuran ödül streak izleyici
  @override
  int lastRewardedStreak = 0;
  @override
  Future<void> setLastRewardedStreak(int v) async => lastRewardedStreak = v;

  // Esmâ serisi
  @override
  int esmaStreak = 0;
  @override
  Future<void> setEsmaStreak(int v) async => esmaStreak = v;
  @override
  String? lastEsmaDate;
  @override
  Future<void> setLastEsmaDate(String d) async => lastEsmaDate = d;
  @override
  int lastRewardedEsmaStreak = 0;
  @override
  Future<void> setLastRewardedEsmaStreak(int v) async =>
      lastRewardedEsmaStreak = v;
  @override
  Future<void> incrementEsmaCount() async {}

  // Hadis serisi
  @override
  int hadisStreak = 0;
  @override
  Future<void> setHadisStreak(int v) async => hadisStreak = v;
  @override
  String? lastHadisDate;
  @override
  Future<void> setLastHadisDate(String d) async => lastHadisDate = d;
  @override
  int lastRewardedHadisStreak = 0;
  @override
  Future<void> setLastRewardedHadisStreak(int v) async =>
      lastRewardedHadisStreak = v;
  @override
  Future<void> incrementHadisCount() async {}

  // Teheccüd koşulları
  @override
  bool tahajjudEnabled = false;
  @override
  String? tahajjudAlarmDate;

  // Rozet milestone izleyiciler
  @override
  int lastRewardedKuranBadge = 0;
  @override
  Future<void> setLastRewardedKuranBadge(int v) async =>
      lastRewardedKuranBadge = v;
  @override
  int lastRewardedEsmaBadge = 0;
  @override
  Future<void> setLastRewardedEsmaBadge(int v) async =>
      lastRewardedEsmaBadge = v;
  @override
  int lastRewardedHadisBadge = 0;
  @override
  Future<void> setLastRewardedHadisBadge(int v) async =>
      lastRewardedHadisBadge = v;
  @override
  int lastRewardedKombineBadge = 0;
  @override
  Future<void> setLastRewardedKombineBadge(int v) async =>
      lastRewardedKombineBadge = v;
  @override
  int lastRewardedTahajjudBadge = 0;
  @override
  Future<void> setLastRewardedTahajjudBadge(int v) async =>
      lastRewardedTahajjudBadge = v;

  // Veteran rozeti
  @override
  bool veteranBadgeAwarded = false;
  @override
  Future<void> setVeteranBadgeAwarded() async => veteranBadgeAwarded = true;
  @override
  Future<void> setGoldenFrameUnlocked() async {}

  // Teheccüd aylık kart
  @override
  String? lastTahajjudMonthlyCard;
  @override
  Future<void> setLastTahajjudMonthlyCard(String ym) async =>
      lastTahajjudMonthlyCard = ym;
}

// ── FakeRewardRepository ──────────────────────────────────────────────────────

class FakeRewardRepository extends Fake implements RewardRepository {
  final List<Map<String, String>> savedRewards = [];
  final Map<String, bool> _rewardDates = {};
  final Set<String> _tahajjudAskedDates = {};
  final List<Map<String, Object>> tahajjudAnswers = [];

  void stubRewardForDate(String type, String date, {bool value = true}) {
    _rewardDates['$type|$date'] = value;
  }

  /// checkTahajjudReward/shouldPromptTahajjud testlerinde "bugün zaten
  /// soruldu" durumunu simüle etmek için.
  void stubTahajjudAskedToday(String date, {bool value = true}) {
    if (value) {
      _tahajjudAskedDates.add(date);
    } else {
      _tahajjudAskedDates.remove(date);
    }
  }

  @override
  Future<void> saveReward({
    required String type,
    required String title,
    required String message,
  }) async {
    savedRewards.add({'type': type, 'title': title, 'message': message});
  }

  @override
  Future<bool> hasRewardForDate(String type, String date) async =>
      _rewardDates['$type|$date'] ?? false;

  @override
  Future<bool> tahajjudAskedToday(String date) async =>
      _tahajjudAskedDates.contains(date);

  @override
  Future<void> recordTahajjudAnswer(String date, {required bool prayed}) async {
    _tahajjudAskedDates.add(date);
    tahajjudAnswers.add({'date': date, 'prayed': prayed});
  }
}

// ── FakeBadgeRepository ───────────────────────────────────────────────────────

class FakeBadgeRepository extends Fake implements BadgeRepository {
  final Set<String> earnedBadges = {};
  int tahajjudTotalNights = 0;
  int tahajjudNightsInMonth = 0;

  @override
  Future<bool> hasBadge(String badgeId) async =>
      earnedBadges.contains(badgeId);

  @override
  Future<BadgeModel> saveBadge(String badgeId) async {
    earnedBadges.add(badgeId);
    return BadgeModel(id: 'fake', badgeId: badgeId, earnedAt: DateTime.now());
  }

  @override
  Future<int> getTahajjudTotalNights() async => tahajjudTotalNights;

  @override
  Future<int> getTahajjudNightsInMonth(String yearMonth) async =>
      tahajjudNightsInMonth;
}
