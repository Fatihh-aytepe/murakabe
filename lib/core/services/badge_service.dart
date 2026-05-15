import '../../core/constants/badge_definitions.dart';
import '../../data/local/local_storage.dart';
import '../../data/models/user_model.dart';
import '../../data/remote/firebase_service.dart';
import '../../data/repositories/badge_repository.dart';

class BadgeService {
  static final BadgeService _instance = BadgeService._();
  factory BadgeService() => _instance;
  BadgeService._()
      : _repo = BadgeRepository(),
        _storage = LocalStorage();

  // Test için constructor injection
  BadgeService.withDeps({
    required BadgeRepository repo,
    required LocalStorage storage,
  })  : _repo = repo,
        _storage = storage;

  final BadgeRepository _repo;
  final LocalStorage _storage;

  // Tüm rozet koşullarını kontrol eder; kazanılan rozetlerin listesini döner.
  Future<List<BadgeDef>> checkAndAward(UserModel user) async {
    final earned = <BadgeDef>[];

    final kuranStreak = user.streakDays;
    final esmaStreak = _storage.esmaStreak;
    final hadisStreak = _storage.hadisStreak;

    // ── Kur'ân rozetleri ──────────────────────────────────────────────────
    final lastKuran = _storage.lastRewardedKuranBadge;
    for (final entry in _kuranBadgeMilestones.entries) {
      if (kuranStreak >= entry.key && lastKuran < entry.key) {
        if (!await _repo.hasBadge(entry.value.id)) {
          await _repo.saveBadge(entry.value.id);
          earned.add(entry.value);
        }
        await _storage.setLastRewardedKuranBadge(entry.key);
      }
    }

    // ── Esmâ rozetleri ────────────────────────────────────────────────────
    final lastEsma = _storage.lastRewardedEsmaBadge;
    for (final entry in _esmaBadgeMilestones.entries) {
      if (esmaStreak >= entry.key && lastEsma < entry.key) {
        if (!await _repo.hasBadge(entry.value.id)) {
          await _repo.saveBadge(entry.value.id);
          earned.add(entry.value);
        }
        await _storage.setLastRewardedEsmaBadge(entry.key);
      }
    }

    // ── Hadis rozetleri ───────────────────────────────────────────────────
    final lastHadis = _storage.lastRewardedHadisBadge;
    for (final entry in _hadisBadgeMilestones.entries) {
      if (hadisStreak >= entry.key && lastHadis < entry.key) {
        if (!await _repo.hasBadge(entry.value.id)) {
          await _repo.saveBadge(entry.value.id);
          earned.add(entry.value);
        }
        await _storage.setLastRewardedHadisBadge(entry.key);
      }
    }

    // ── Kombine rozetleri (3 kategori birden) ─────────────────────────────
    final lastKombine = _storage.lastRewardedKombineBadge;
    final kombineStreak = [kuranStreak, esmaStreak, hadisStreak].reduce(
      (a, b) => a < b ? a : b,
    );
    for (final entry in _kombineBadgeMilestones.entries) {
      if (kombineStreak >= entry.key && lastKombine < entry.key) {
        if (!await _repo.hasBadge(entry.value.id)) {
          await _repo.saveBadge(entry.value.id);
          earned.add(entry.value);
        }
        await _storage.setLastRewardedKombineBadge(entry.key);
      }
    }

    // ── Teheccüd rozetleri ────────────────────────────────────────────────
    final totalNights = await _repo.getTahajjudTotalNights();
    final lastTahajjud = _storage.lastRewardedTahajjudBadge;
    for (final entry in _tahajjudBadgeMilestones.entries) {
      if (totalNights >= entry.key && lastTahajjud < entry.key) {
        if (!await _repo.hasBadge(entry.value.id)) {
          await _repo.saveBadge(entry.value.id);
          earned.add(entry.value);
        }
        await _storage.setLastRewardedTahajjudBadge(entry.key);
      }
    }

    // ── Veteran rozeti (1 yıllık kullanıcı) ──────────────────────────────
    if (!_storage.veteranBadgeAwarded) {
      final daysSince = DateTime.now().difference(user.createdAt).inDays;
      if (daysSince >= 365) {
        if (!await _repo.hasBadge(kBadgeVeteran1Yil.id)) {
          await _repo.saveBadge(kBadgeVeteran1Yil.id);
          earned.add(kBadgeVeteran1Yil);
        }
        await _storage.setVeteranBadgeAwarded();
        await _storage.setGoldenFrameUnlocked();
      }
    }

    // Kazanılan rozet varsa milestone'ları Firestore'a yedekle
    if (earned.isNotEmpty) {
      final uid = _storage.userId;
      if (uid != null) {
        FirebaseService().saveUserPrefs(uid, _storage.toSyncMap());
      }
    }

    return earned;
  }

  // Ay içinde 4 teheccüd koşulunu kontrol eder; kart gösterilmeli mi döner.
  Future<bool> checkTahajjudMonthlyCard() async {
    final now = DateTime.now();
    final yearMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final lastCard = _storage.lastTahajjudMonthlyCard;
    if (lastCard == yearMonth) return false;

    final count = await _repo.getTahajjudNightsInMonth(yearMonth);
    if (count >= 4) {
      await _storage.setLastTahajjudMonthlyCard(yearMonth);
      return true;
    }
    return false;
  }

  // ── Milestone eşleştirme tabloları ───────────────────────────────────────

  static const Map<int, BadgeDef> _kuranBadgeMilestones = {
    30: kBadgeKuranAy1,
    90: kBadgeKuranAy3,
    180: kBadgeKuranAy6,
    365: kBadgeKuranYil1,
  };

  static const Map<int, BadgeDef> _esmaBadgeMilestones = {
    30: kBadgeEsmaAy1,
    90: kBadgeEsmaAy3,
    180: kBadgeEsmaAy6,
    365: kBadgeEsmaYil1,
  };

  static const Map<int, BadgeDef> _hadisBadgeMilestones = {
    30: kBadgeHadisAy1,
    90: kBadgeHadisAy3,
    180: kBadgeHadisAy6,
    365: kBadgeHadisYil1,
  };

  static const Map<int, BadgeDef> _kombineBadgeMilestones = {
    30: kBadgeKombineAy1,
    90: kBadgeKombineAy3,
    180: kBadgeKombineAy6,
    365: kBadgeKombineYil1,
  };

  static const Map<int, BadgeDef> _tahajjudBadgeMilestones = {
    3: kBadgeTahajjud3,
    10: kBadgeTahajjud10,
    30: kBadgeTahajjud30,
    50: kBadgeTahajjud50,
    99: kBadgeTahajjud99,
  };
}
