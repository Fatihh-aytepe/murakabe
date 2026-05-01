import '../../data/local/local_storage.dart';
import '../../data/repositories/reward_repository.dart';

class RewardInfo {
  final String type;
  final String title;
  final String message;
  final String emoji;
  final int milestone;

  const RewardInfo({
    required this.type,
    required this.title,
    required this.message,
    required this.emoji,
    required this.milestone,
  });
}

class RewardService {
  static final RewardService _instance = RewardService._internal();
  factory RewardService() => _instance;
  RewardService._internal();

  final _storage = LocalStorage();
  final _rewardRepo = RewardRepository();

  static const List<int> _milestones = [3, 7, 10, 30, 40];

  // Ilk acilis odulu verilmeli mi?
  bool get shouldShowWelcome => _storage.isFirstOpen;
  Future<void> markWelcomeDone() => _storage.setFirstOpenDone();

  // Streak odulu verilmeli mi?
  Future<RewardInfo?> checkStreakReward(int currentStreak) async {
    final lastRewarded = _storage.lastRewardedStreak;

    for (final m in _milestones.reversed) {
      if (currentStreak >= m && lastRewarded < m) {
        await _storage.setLastRewardedStreak(m);
        final info = _buildStreakReward(m);
        await _rewardRepo.saveReward(
          type: info.type,
          title: info.title,
          message: info.message,
        );
        return info;
      }
    }
    return null;
  }

  // Teheccud odulu verilmeli mi? (alarm kurulmus + sabah acilmis)
  Future<bool> checkTahajjudReward() async {
    if (!_storage.tahajjudEnabled) return false;
    final alarmDateStr = _storage.tahajjudAlarmDate;
    if (alarmDateStr == null) return false;

    final today = DateTime.now().toIso8601String().substring(0, 10);
    final alreadyDone = await _rewardRepo.hasRewardForDate('tahajjud', today);
    if (alreadyDone) return false;

    final yesterday = DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    if (alarmDateStr != today && alarmDateStr != yesterday) return false;

    // Sabah 02:00 - 08:00 araliginda mi?
    final hour = DateTime.now().hour;
    if (hour < 2 || hour > 8) return false;

    await _rewardRepo.saveReward(
      type: 'tahajjud',
      title: "Teheccud Odulu",
      message: "Bu gece milyonlar uykudayken sen Rabbinle bulustun."
          " Bu sadakat, kalbinde hic sonmeyecek bir kandil yakti. Mubarek olsun.",
    );
    return true;
  }

  // Etkilesim takibi
  Future<void> trackEsmaOpen() => _storage.incrementEsmaCount();
  Future<void> trackAyetOpen() => _storage.incrementAyetCount();
  Future<void> trackHadisOpen() => _storage.incrementHadisCount();

  RewardInfo _buildStreakReward(int milestone) {
    final dominant = _dominantContent();
    if (dominant == 'esma') {
      return RewardInfo(
        type: 'streak_esma',
        title: '$milestone Gunluk Esma Yolculugu',
        emoji: '✨',
        milestone: milestone,
        message: _esmaMessages[milestone] ??
            "Esmaul Husna'yi zikreden kalpte Allah'in nuru parlar."
                " $milestone gunluk bu adanmislik, manevi yolculugunda degerli bir merhale.",
      );
    } else if (dominant == 'ayet') {
      return RewardInfo(
        type: 'streak_ayet',
        title: '$milestone Gunluk Ayet Tefekkuru',
        emoji: '📖',
        milestone: milestone,
        message: _ayetMessages[milestone] ??
            "Kuran-i Kerim'i $milestone gundur okuyup tefekkur ettin."
                " Allah kelamiyla bu bagin kalici ve bereketli olmasi dileriz.",
      );
    } else {
      return RewardInfo(
        type: 'streak_hadis',
        title: '$milestone Gunluk Sunnet Takipcisi',
        emoji: '🌙',
        milestone: milestone,
        message: _hadisMessages[milestone] ??
            "Hz. Peygamber'in sunnetini $milestone gundur takip ettin."
                " Bu baglilik, sana sefaate vesile olsun.",
      );
    }
  }

  String _dominantContent() {
    final e = _storage.esmaOpenCount;
    final a = _storage.ayetOpenCount;
    final h = _storage.hadisOpenCount;
    if (e >= a && e >= h) return 'esma';
    if (a >= e && a >= h) return 'ayet';
    return 'hadis';
  }

  static const Map<int, String> _esmaMessages = {
    3: "Uc gun boyunca Allah'in isimlerini zikredin. Melekler sizi hayirla andi."
        " Bu devami olan bir guzelligin baslangici.",
    7: "Yedi gun, bir hafta boyunca Esmaul Husna ile yoldas oldun."
        " Allah'in 99 ismini tanima O'nu daha derinden bilmek demektir.",
    10: "On gun! Hz. Peygamber soyle buyurur: 'Amellerin Allah'a en sevimlisi"
        " az da olsa devamlı olanidır.' Sen bu devami yakaladın.",
    30: "Otuz gun, bir ay! Bir ay boyunca her gun Allah'in isimlerini zikrettin."
        " Bu ibadete devam et, bu yolda ilerle.",
    40: "Kirk gun! Sufiler kirk gunu Hz. Isa'nin halvete cekildiği sure olarak bilir."
        " Sen kirk gun boyunca ruhunu Esmaul Husna ile besledin.",
  };

  static const Map<int, String> _ayetMessages = {
    3: "Uc gun boyunca Allah'in kelamini okudun ve tefekkur ettin."
        " 'Kuran okunan eve melek iner' buyurulmustur.",
    7: "Bir hafta! Haftalik bir Kuran hatmi suresince her gun ayet okudun."
        " Kalbinde Kuran'in nuru parıldiyor.",
    10: "On gun! Kuran-i Kerim'i on gun boyunca gundemine aldin."
        " Bu aliskanlik, omrunun bereketini artirir.",
    30: "Otuz gun, tam bir Ramazan suresi! Bir ay boyunca her gun Allah'in"
        " ayetleriyle bulustun. Bu sadakat nadir bir guzellik.",
    40: "Kirk gun! Kuran ile kirk gunluk yolculugun tamamlandi."
        " Sen artik Kuran'a gonul baglamis birisin.",
  };

  static const Map<int, String> _hadisMessages = {
    3: "Uc gun Peygamber Efendimiz'in sozlerini okudun."
        " 'Benim sunnetimi seven beni sever' buyurulan bu yola girdin.",
    7: "Yedi gun boyunca hadis-i serifler esliginde yurudun."
        " Hz. Muhammed'in nurlu sozleri kalbinde mesale yakti.",
    10: "On gun! Peygamber Efendimiz'e olan sevin bu surekilikle kendini"
        " gosteriyor. Allah bu muhabbeti artirsin.",
    30: "Otuz gun sunnet yolunda! Bir ay boyunca Hz. Peygamber'in izinde yurudun."
        " Bu sadakatin karsiligini bulacaksin.",
    40: "Kirk gun! 'Bir kimse kirk gun ihlaslı Allah icin calisirsa...' hadisinin"
        " sirrina ermek uzeresin.",
  };
}
