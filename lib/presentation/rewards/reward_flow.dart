import 'package:flutter/material.dart';
import '../../core/services/badge_service.dart';
import '../../core/services/reward_service.dart';
import '../../data/repositories/user_repository.dart';
import 'tebrik_karti_screen.dart';

/// "Okudum" gibi bir okuma eyleminden HEMEN SONRA seri ilerletme, tebrik
/// kartı ve rozet kontrolünü tek yerden yapar.
///
/// NEDEN: Esmâ/Hadis serisini ilerleten RewardService.trackEsmaRead /
/// trackHadisRead yazılmıştı ama hiçbir yerden çağrılmıyordu — seriler hep
/// 0 kalıyor, Esmâ/Hadis/Kombine rozetleri ve tebrik kartları HİÇ
/// kazanılamıyordu. Ayrıca rozet kontrolü yalnızca uygulama açılışında
/// yapıldığından kazanılan rozet ancak bir sonraki açılışta görünüyordu.
/// Açılıştaki kontrol (HomeScreen._checkRewards) olduğu gibi duruyor;
/// "son ödüllendirilen" işaretleri sayesinde aynı ödül iki kez gösterilmez.
class RewardFlow {
  RewardFlow._();

  /// [type]: 'esma' | 'hadis' | 'ayet' | 'kuran'
  /// Aynı gün aynı içerik için TEKRAR çağrılmamalı (çağıran taraf
  /// "bugün zaten okundu mu" kontrolünü yapar) — sayaçlar her çağrıda artar.
  static Future<void> afterRead(NavigatorState nav, String type) async {
    try {
      final rewardService = RewardService();
      RewardInfo? reward;
      switch (type) {
        case 'esma':
          reward = await rewardService.trackEsmaRead();
          break;
        case 'hadis':
          reward = await rewardService.trackHadisRead();
          break;
        case 'ayet':
          // Âyet okuması seriye değil, yalnızca toplam sayaca işlenir
          // (Kur'ân serisi "Bugün Kur'an okudun mu" kartıyla izleniyor).
          await rewardService.trackAyetOpen();
          break;
        case 'kuran':
          final user = await UserRepository().getCurrentUser();
          if (user != null) {
            reward = await rewardService.checkKuranStreakReward(user.streakDays);
          }
          break;
      }

      final info = reward;
      if (info != null && nav.mounted) {
        await nav.push(MaterialPageRoute(
          builder: (_) => TebrikKartiScreen(
            type: info.type,
            title: info.title,
            message: info.message,
            autoSave: false,
          ),
        ));
      }

      final user = await UserRepository().getCurrentUser();
      if (user == null) return;
      final earnedBadges = await BadgeService().checkAndAward(user);
      for (final badge in earnedBadges) {
        if (!nav.mounted) return;
        // Metin HomeScreen._checkRewards ile birebir aynı.
        await nav.push(MaterialPageRoute(
          builder: (_) => TebrikKartiScreen(
            type: 'rozet_${badge.id}',
            title: '🏅 Yeni Rozet: ${badge.name}',
            message: '${badge.description}\n\n${badge.tierLabel} seviyesinde bir'
                ' rozet kazandın! Profilindeki Heybem bölümünden rozetlerini görebilirsin.',
            autoSave: false,
          ),
        ));
      }
    } catch (e) {
      debugPrint('[RewardFlow] $type hata: $e');
    }
  }
}
