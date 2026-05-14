import 'package:flutter_test/flutter_test.dart';
import 'package:murakabe/core/services/badge_service.dart';
import 'package:murakabe/data/models/user_model.dart';
import '../fakes.dart';

UserModel _user({int streak = 0, DateTime? createdAt}) => UserModel(
      id: 'test',
      nameSurname: 'Test Kullanıcı',
      phone: '',
      email: 'test@test.com',
      createdAt: createdAt ?? DateTime.now(),
      streakDays: streak,
    );

void main() {
  late FakeLocalStorage storage;
  late FakeBadgeRepository repo;
  late BadgeService service;

  setUp(() {
    storage = FakeLocalStorage();
    repo = FakeBadgeRepository();
    service = BadgeService.withDeps(repo: repo, storage: storage);
  });

  // ── Hiç streak yoksa rozet kazanılmaz ────────────────────────────────────

  test('sıfır streak → hiç rozet kazanılmaz', () async {
    final badges = await service.checkAndAward(_user(streak: 0));
    expect(badges, isEmpty);
    expect(repo.earnedBadges, isEmpty);
  });

  // ── Kur'ân rozetleri ─────────────────────────────────────────────────────

  group('Kur\'ân rozetleri', () {
    test('30 günlük streak → kuran_ay_1 kazanılır', () async {
      storage.lastRewardedKuranBadge = 0;
      final badges = await service.checkAndAward(_user(streak: 30));

      expect(badges.any((b) => b.id == 'kuran_ay_1'), isTrue);
      expect(repo.earnedBadges, contains('kuran_ay_1'));
      expect(storage.lastRewardedKuranBadge, 30);
    });

    test('30 günlük streak, badge zaten kazanılmışsa tekrar verilmez', () async {
      storage.lastRewardedKuranBadge = 30;
      final badges = await service.checkAndAward(_user(streak: 30));

      expect(badges.any((b) => b.id == 'kuran_ay_1'), isFalse);
    });

    test('90 günlük streak → kuran_ay_3 kazanılır', () async {
      storage.lastRewardedKuranBadge = 30;
      final badges = await service.checkAndAward(_user(streak: 90));

      expect(badges.any((b) => b.id == 'kuran_ay_3'), isTrue);
      expect(storage.lastRewardedKuranBadge, 90);
    });

    test('180 günlük streak → kuran_ay_6 kazanılır', () async {
      storage.lastRewardedKuranBadge = 90;
      final badges = await service.checkAndAward(_user(streak: 180));

      expect(badges.any((b) => b.id == 'kuran_ay_6'), isTrue);
    });

    test('365 günlük streak → kuran_yil_1 kazanılır', () async {
      storage.lastRewardedKuranBadge = 180;
      final badges = await service.checkAndAward(_user(streak: 365));

      expect(badges.any((b) => b.id == 'kuran_yil_1'), isTrue);
    });

    test('hasBadge true ise saveBadge çağrılmaz', () async {
      storage.lastRewardedKuranBadge = 0;
      repo.earnedBadges.add('kuran_ay_1'); // Önceden kazanılmış

      final badges = await service.checkAndAward(_user(streak: 30));

      expect(badges.any((b) => b.id == 'kuran_ay_1'), isFalse);
    });
  });

  // ── Esmâ rozetleri ───────────────────────────────────────────────────────

  group('Esmâ rozetleri', () {
    test('30 günlük esma streak → esma_ay_1 kazanılır', () async {
      storage.esmaStreak = 30;
      storage.lastRewardedEsmaBadge = 0;
      final badges = await service.checkAndAward(_user());

      expect(badges.any((b) => b.id == 'esma_ay_1'), isTrue);
    });

    test('90 günlük esma streak → esma_ay_3 kazanılır', () async {
      storage.esmaStreak = 90;
      storage.lastRewardedEsmaBadge = 30;
      final badges = await service.checkAndAward(_user());

      expect(badges.any((b) => b.id == 'esma_ay_3'), isTrue);
    });

    test('esma milestone önceden işaretlenmişse rozet verilmez', () async {
      storage.esmaStreak = 30;
      storage.lastRewardedEsmaBadge = 30;
      final badges = await service.checkAndAward(_user());

      expect(badges.any((b) => b.id == 'esma_ay_1'), isFalse);
    });
  });

  // ── Hadis rozetleri ──────────────────────────────────────────────────────

  group('Hadis rozetleri', () {
    test('30 günlük hadis streak → hadis_ay_1 kazanılır', () async {
      storage.hadisStreak = 30;
      storage.lastRewardedHadisBadge = 0;
      final badges = await service.checkAndAward(_user());

      expect(badges.any((b) => b.id == 'hadis_ay_1'), isTrue);
    });

    test('180 günlük hadis streak → hadis_ay_6 kazanılır', () async {
      storage.hadisStreak = 180;
      storage.lastRewardedHadisBadge = 90;
      final badges = await service.checkAndAward(_user());

      expect(badges.any((b) => b.id == 'hadis_ay_6'), isTrue);
    });
  });

  // ── Kombine rozetleri ────────────────────────────────────────────────────

  group('Kombine rozetleri', () {
    test('üç kategori 30 gün → kombine_ay_1 kazanılır', () async {
      storage.esmaStreak = 30;
      storage.hadisStreak = 30;
      storage.lastRewardedKombineBadge = 0;
      final badges = await service.checkAndAward(_user(streak: 30));

      expect(badges.any((b) => b.id == 'kombine_ay_1'), isTrue);
    });

    test('kombine en düşük streak baz alınır: esma=30 hadis=90 kuran=30 → ay_1', () async {
      storage.esmaStreak = 30;
      storage.hadisStreak = 90;
      storage.lastRewardedKombineBadge = 0;
      final badges = await service.checkAndAward(_user(streak: 30));

      expect(badges.any((b) => b.id == 'kombine_ay_1'), isTrue);
      expect(badges.any((b) => b.id == 'kombine_ay_3'), isFalse);
    });

    test('kombine min streak < eşik → kombine rozeti verilmez', () async {
      storage.esmaStreak = 20;
      storage.hadisStreak = 30;
      storage.lastRewardedKombineBadge = 0;
      final badges = await service.checkAndAward(_user(streak: 30));

      expect(badges.any((b) => b.id.startsWith('kombine')), isFalse);
    });

    test('90 günlük kombine → kombine_ay_3 kazanılır', () async {
      storage.esmaStreak = 90;
      storage.hadisStreak = 90;
      storage.lastRewardedKombineBadge = 30;
      final badges = await service.checkAndAward(_user(streak: 90));

      expect(badges.any((b) => b.id == 'kombine_ay_3'), isTrue);
    });
  });

  // ── Teheccüd rozetleri ───────────────────────────────────────────────────

  group('Teheccüd rozetleri', () {
    test('3 gece teheccüd → tahajjud_3 kazanılır', () async {
      repo.tahajjudTotalNights = 3;
      storage.lastRewardedTahajjudBadge = 0;
      final badges = await service.checkAndAward(_user());

      expect(badges.any((b) => b.id == 'tahajjud_3'), isTrue);
    });

    test('10 gece teheccüd → tahajjud_10 kazanılır', () async {
      repo.tahajjudTotalNights = 10;
      storage.lastRewardedTahajjudBadge = 3;
      final badges = await service.checkAndAward(_user());

      expect(badges.any((b) => b.id == 'tahajjud_10'), isTrue);
    });

    test('99 gece teheccüd → tahajjud_99 kazanılır', () async {
      repo.tahajjudTotalNights = 99;
      storage.lastRewardedTahajjudBadge = 50;
      final badges = await service.checkAndAward(_user());

      expect(badges.any((b) => b.id == 'tahajjud_99'), isTrue);
    });

    test('2 gece teheccüd → hiç teheccüd rozeti verilmez', () async {
      repo.tahajjudTotalNights = 2;
      storage.lastRewardedTahajjudBadge = 0;
      final badges = await service.checkAndAward(_user());

      expect(badges.any((b) => b.id.startsWith('tahajjud')), isFalse);
    });
  });

  // ── Veteran rozeti ───────────────────────────────────────────────────────

  group('Veteran rozeti', () {
    test('1 yıldan eski hesap → veteran_1_yil kazanılır', () async {
      storage.veteranBadgeAwarded = false;
      final createdAt = DateTime.now().subtract(const Duration(days: 366));
      final badges = await service.checkAndAward(_user(createdAt: createdAt));

      expect(badges.any((b) => b.id == 'veteran_1_yil'), isTrue);
      expect(storage.veteranBadgeAwarded, isTrue);
    });

    test('364 günlük hesap → veteran rozeti verilmez', () async {
      storage.veteranBadgeAwarded = false;
      final createdAt = DateTime.now().subtract(const Duration(days: 364));
      final badges = await service.checkAndAward(_user(createdAt: createdAt));

      expect(badges.any((b) => b.id == 'veteran_1_yil'), isFalse);
    });

    test('veteran zaten verilmişse tekrar verilmez', () async {
      storage.veteranBadgeAwarded = true;
      final createdAt = DateTime.now().subtract(const Duration(days: 400));
      final badges = await service.checkAndAward(_user(createdAt: createdAt));

      expect(badges.any((b) => b.id == 'veteran_1_yil'), isFalse);
    });
  });

  // ── Aynı çağrıda birden fazla rozet ─────────────────────────────────────

  test('aynı çağrıda birden fazla kategori rozeti kazanılabilir', () async {
    storage.esmaStreak = 30;
    storage.hadisStreak = 30;
    storage.lastRewardedKuranBadge = 0;
    storage.lastRewardedEsmaBadge = 0;
    storage.lastRewardedHadisBadge = 0;
    storage.lastRewardedKombineBadge = 0;

    final badges = await service.checkAndAward(_user(streak: 30));

    expect(badges.length, greaterThanOrEqualTo(3));
    expect(badges.any((b) => b.id == 'kuran_ay_1'), isTrue);
    expect(badges.any((b) => b.id == 'esma_ay_1'), isTrue);
    expect(badges.any((b) => b.id == 'hadis_ay_1'), isTrue);
    expect(badges.any((b) => b.id == 'kombine_ay_1'), isTrue);
  });

  // ── checkTahajjudMonthlyCard ─────────────────────────────────────────────

  group('checkTahajjudMonthlyCard', () {
    test('ay içinde 4 gece → true döner', () async {
      final now = DateTime.now();
      final yearMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      repo.tahajjudNightsInMonth = 4;
      storage.lastTahajjudMonthlyCard = null;

      final result = await service.checkTahajjudMonthlyCard();

      expect(result, isTrue);
      expect(storage.lastTahajjudMonthlyCard, yearMonth);
    });

    test('4 geceden az → false döner', () async {
      repo.tahajjudNightsInMonth = 3;
      storage.lastTahajjudMonthlyCard = null;

      expect(await service.checkTahajjudMonthlyCard(), isFalse);
    });

    test('bu ay zaten kart gönderildiyse false döner', () async {
      final now = DateTime.now();
      final yearMonth =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      repo.tahajjudNightsInMonth = 10;
      storage.lastTahajjudMonthlyCard = yearMonth;

      expect(await service.checkTahajjudMonthlyCard(), isFalse);
    });
  });
}
