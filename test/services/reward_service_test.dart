import 'package:flutter_test/flutter_test.dart';
import 'package:murakabe/core/services/reward_service.dart';
import '../fakes.dart';

String _today() => DateTime.now().toIso8601String().substring(0, 10);
String _yesterday() => DateTime.now()
    .subtract(const Duration(days: 1))
    .toIso8601String()
    .substring(0, 10);

void main() {
  late FakeLocalStorage storage;
  late FakeRewardRepository rewardRepo;
  late RewardService service;

  setUp(() {
    storage = FakeLocalStorage();
    rewardRepo = FakeRewardRepository();
    service = RewardService.withDeps(storage: storage, rewardRepo: rewardRepo);
  });

  // ── checkKuranStreakReward ────────────────────────────────────────────────

  group('checkKuranStreakReward', () {
    test('milestone eşiği altında null döner', () async {
      storage.lastRewardedStreak = 0;
      final result = await service.checkKuranStreakReward(2);
      expect(result, isNull);
      expect(rewardRepo.savedRewards, isEmpty);
    });

    test('ilk milestone (3 gün) ödül döner', () async {
      storage.lastRewardedStreak = 0;
      final result = await service.checkKuranStreakReward(3);

      expect(result, isNotNull);
      expect(result!.milestone, 3);
      expect(result.type, 'streak_kuran');
      expect(result.emoji, '📖');
      expect(storage.lastRewardedStreak, 3);
    });

    test('zaten verilmiş milestone için null döner', () async {
      storage.lastRewardedStreak = 3;
      final result = await service.checkKuranStreakReward(3);
      expect(result, isNull);
    });

    test('30 günlük streakta en yüksek kazanılmamış milestone döner', () async {
      storage.lastRewardedStreak = 7;
      final result = await service.checkKuranStreakReward(30);

      expect(result, isNotNull);
      expect(result!.milestone, 30);
      expect(storage.lastRewardedStreak, 30);
    });

    test('7 günlük streak, 3 önceden verilmişse 7 ödülü döner', () async {
      storage.lastRewardedStreak = 3;
      final result = await service.checkKuranStreakReward(7);

      expect(result, isNotNull);
      expect(result!.milestone, 7);
    });

    test('365 günlük streak yıllık ödül döner', () async {
      storage.lastRewardedStreak = 360;
      final result = await service.checkKuranStreakReward(365);

      expect(result, isNotNull);
      expect(result!.milestone, 365);
      expect(result.title, contains('Yıllık'));
    });

    test('milestone sonrası saveReward çağrılır', () async {
      storage.lastRewardedStreak = 0;
      await service.checkKuranStreakReward(3);

      expect(rewardRepo.savedRewards, hasLength(1));
      expect(rewardRepo.savedRewards.first['type'], 'streak_kuran');
    });

    test('milestone yoksa saveReward çağrılmaz', () async {
      storage.lastRewardedStreak = 0;
      await service.checkKuranStreakReward(1);

      expect(rewardRepo.savedRewards, isEmpty);
    });
  });

  // ── trackEsmaRead ────────────────────────────────────────────────────────

  group('trackEsmaRead', () {
    test('ilk okuma: streak 1 olur', () async {
      storage.lastEsmaDate = null;
      storage.esmaStreak = 0;
      await service.trackEsmaRead();
      expect(storage.esmaStreak, 1);
    });

    test('aynı gün ikinci okuma: streak değişmez', () async {
      storage.lastEsmaDate = _today();
      storage.esmaStreak = 5;
      await service.trackEsmaRead();
      expect(storage.esmaStreak, 5);
    });

    test('dünden gelen okuma: streak +1 olur', () async {
      storage.lastEsmaDate = _yesterday();
      storage.esmaStreak = 4;
      await service.trackEsmaRead();
      expect(storage.esmaStreak, 5);
    });

    test('seri kopmuşsa streak 1 olur', () async {
      storage.lastEsmaDate = '2020-01-01';
      storage.esmaStreak = 30;
      await service.trackEsmaRead();
      expect(storage.esmaStreak, 1);
    });

    test('lastEsmaDate güncellenir', () async {
      storage.lastEsmaDate = _yesterday();
      storage.esmaStreak = 1;
      await service.trackEsmaRead();
      expect(storage.lastEsmaDate, _today());
    });

    test('milestone yakalanırsa ödül döner', () async {
      storage.lastEsmaDate = _yesterday();
      storage.esmaStreak = 2;
      storage.lastRewardedEsmaStreak = 0;

      final result = await service.trackEsmaRead();

      expect(result, isNotNull);
      expect(result!.milestone, 3);
      expect(result.type, 'streak_esma');
      expect(result.emoji, '✨');
    });

    test('milestone yok ise null döner', () async {
      storage.lastEsmaDate = _yesterday();
      storage.esmaStreak = 1;
      storage.lastRewardedEsmaStreak = 0;

      final result = await service.trackEsmaRead();

      expect(result, isNull);
    });

    test('30 günlük esma milestone doğru milestone kaydeder', () async {
      storage.lastEsmaDate = _yesterday();
      storage.esmaStreak = 29;
      storage.lastRewardedEsmaStreak = 15;

      final result = await service.trackEsmaRead();

      expect(result, isNotNull);
      expect(result!.milestone, 30);
      expect(storage.lastRewardedEsmaStreak, 30);
    });
  });

  // ── trackHadisRead ───────────────────────────────────────────────────────

  group('trackHadisRead', () {
    test('ilk okuma: streak 1 olur', () async {
      storage.lastHadisDate = null;
      storage.hadisStreak = 0;
      await service.trackHadisRead();
      expect(storage.hadisStreak, 1);
    });

    test('dünden gelen okuma: streak +1 olur', () async {
      storage.lastHadisDate = _yesterday();
      storage.hadisStreak = 6;
      storage.lastRewardedHadisStreak = 3;

      final result = await service.trackHadisRead();

      expect(storage.hadisStreak, 7);
      expect(result, isNotNull);
      expect(result!.milestone, 7);
      expect(result.type, 'streak_hadis');
      expect(result.emoji, '📜');
    });

    test('seri kopmuşsa streak 1 olur', () async {
      storage.lastHadisDate = '2020-01-01';
      storage.hadisStreak = 15;
      await service.trackHadisRead();
      expect(storage.hadisStreak, 1);
    });

    test('aynı gün: streak değişmez', () async {
      storage.lastHadisDate = _today();
      storage.hadisStreak = 10;
      await service.trackHadisRead();
      expect(storage.hadisStreak, 10);
    });
  });

  // ── checkEsmaStreakReward / checkHadisStreakReward ────────────────────────

  group('checkEsmaStreakReward', () {
    test('mevcut streak milestone üzerindeyse ödül döner', () async {
      storage.esmaStreak = 15;
      storage.lastRewardedEsmaStreak = 7;

      final result = await service.checkEsmaStreakReward();

      expect(result, isNotNull);
      expect(result!.type, 'streak_esma');
      expect(result.milestone, 15);
    });

    test('tüm milestonelar verilmişse null döner', () async {
      storage.esmaStreak = 15;
      storage.lastRewardedEsmaStreak = 15;

      final result = await service.checkEsmaStreakReward();

      expect(result, isNull);
    });
  });

  group('checkHadisStreakReward', () {
    test('mevcut streak milestone üzerindeyse ödül döner', () async {
      storage.hadisStreak = 30;
      storage.lastRewardedHadisStreak = 15;

      final result = await service.checkHadisStreakReward();

      expect(result, isNotNull);
      expect(result!.type, 'streak_hadis');
      expect(result.milestone, 30);
    });
  });

  // ── checkTahajjudReward ──────────────────────────────────────────────────

  group('checkTahajjudReward', () {
    test('teheccüd kapalıysa false döner', () async {
      storage.tahajjudEnabled = false;
      expect(await service.checkTahajjudReward(), isFalse);
    });

    test('alarm tarihi null ise false döner', () async {
      storage.tahajjudEnabled = true;
      storage.tahajjudAlarmDate = null;
      expect(await service.checkTahajjudReward(), isFalse);
    });

    test('bugün zaten ödüllendirildiyse false döner', () async {
      storage.tahajjudEnabled = true;
      storage.tahajjudAlarmDate = _today();
      rewardRepo.stubRewardForDate('tahajjud', _today(), value: true);
      expect(await service.checkTahajjudReward(), isFalse);
    });

    test('çok eski tarihli alarm false döner', () async {
      storage.tahajjudEnabled = true;
      storage.tahajjudAlarmDate = '2020-01-01';
      expect(await service.checkTahajjudReward(), isFalse);
    });
  });
}
