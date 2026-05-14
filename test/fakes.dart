import 'package:mockito/mockito.dart';
import 'package:murakabe/data/local/local_storage.dart';
import 'package:murakabe/data/models/badge_model.dart';
import 'package:murakabe/data/repositories/badge_repository.dart';
import 'package:murakabe/data/repositories/reward_repository.dart';

// ── FakeLocalStorage ─────────────────────────────────────────────────────────
// Yalnızca test edilen metotlarda kullanılan alanlar uygulanır.
// Geri kalanlar Fake.noSuchMethod aracılığıyla UnimplementedError fırlatır.

class FakeLocalStorage extends Fake implements LocalStorage {
  // Kuran ödül streak izleyici
  int lastRewardedStreak = 0;
  Future<void> setLastRewardedStreak(int v) async => lastRewardedStreak = v;

  // Esmâ serisi
  int esmaStreak = 0;
  Future<void> setEsmaStreak(int v) async => esmaStreak = v;
  String? lastEsmaDate;
  Future<void> setLastEsmaDate(String d) async => lastEsmaDate = d;
  int lastRewardedEsmaStreak = 0;
  Future<void> setLastRewardedEsmaStreak(int v) async =>
      lastRewardedEsmaStreak = v;
  Future<void> incrementEsmaCount() async {}

  // Hadis serisi
  int hadisStreak = 0;
  Future<void> setHadisStreak(int v) async => hadisStreak = v;
  String? lastHadisDate;
  Future<void> setLastHadisDate(String d) async => lastHadisDate = d;
  int lastRewardedHadisStreak = 0;
  Future<void> setLastRewardedHadisStreak(int v) async =>
      lastRewardedHadisStreak = v;
  Future<void> incrementHadisCount() async {}

  // Teheccüd koşulları
  bool tahajjudEnabled = false;
  String? tahajjudAlarmDate;

  // Rozet milestone izleyiciler
  int lastRewardedKuranBadge = 0;
  Future<void> setLastRewardedKuranBadge(int v) async =>
      lastRewardedKuranBadge = v;
  int lastRewardedEsmaBadge = 0;
  Future<void> setLastRewardedEsmaBadge(int v) async =>
      lastRewardedEsmaBadge = v;
  int lastRewardedHadisBadge = 0;
  Future<void> setLastRewardedHadisBadge(int v) async =>
      lastRewardedHadisBadge = v;
  int lastRewardedKombineBadge = 0;
  Future<void> setLastRewardedKombineBadge(int v) async =>
      lastRewardedKombineBadge = v;
  int lastRewardedTahajjudBadge = 0;
  Future<void> setLastRewardedTahajjudBadge(int v) async =>
      lastRewardedTahajjudBadge = v;

  // Veteran rozeti
  bool veteranBadgeAwarded = false;
  Future<void> setVeteranBadgeAwarded() async => veteranBadgeAwarded = true;
  Future<void> setGoldenFrameUnlocked() async {}

  // Teheccüd aylık kart
  String? lastTahajjudMonthlyCard;
  Future<void> setLastTahajjudMonthlyCard(String ym) async =>
      lastTahajjudMonthlyCard = ym;
}

// ── FakeRewardRepository ──────────────────────────────────────────────────────

class FakeRewardRepository extends Fake implements RewardRepository {
  final List<Map<String, String>> savedRewards = [];
  final Map<String, bool> _rewardDates = {};

  void stubRewardForDate(String type, String date, {bool value = true}) {
    _rewardDates['$type|$date'] = value;
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
