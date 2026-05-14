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
  RewardService._internal()
      : _storage = LocalStorage(),
        _rewardRepo = RewardRepository();

  // Test için constructor injection
  RewardService.withDeps({
    required LocalStorage storage,
    required RewardRepository rewardRepo,
  })  : _storage = storage,
        _rewardRepo = rewardRepo;

  final LocalStorage _storage;
  final RewardRepository _rewardRepo;

  // 3, 7, 15, 30 gün → ardından 45'ten itibaren 15'er günlük artışlarla 360'a → 365
  static const List<int> _readingMilestones = [
    3, 7, 15, 30, 45, 60, 75, 90, 105, 120, 135, 150,
    165, 180, 195, 210, 225, 240, 255, 270, 285, 300,
    315, 330, 345, 360, 365,
  ];

  bool get shouldShowWelcome => _storage.isFirstOpen;
  Future<void> markWelcomeDone() => _storage.setFirstOpenDone();

  String _today() => DateTime.now().toIso8601String().substring(0, 10);

  String _yesterday() => DateTime.now()
      .subtract(const Duration(days: 1))
      .toIso8601String()
      .substring(0, 10);

  // ── Kur'ân serisi (mevcut streakDays kullanılır) ─────────────────────────

  Future<RewardInfo?> checkKuranStreakReward(int currentStreak) async {
    final lastRewarded = _storage.lastRewardedStreak;
    for (final m in _readingMilestones.reversed) {
      if (currentStreak >= m && lastRewarded < m) {
        await _storage.setLastRewardedStreak(m);
        final info = _buildKuranReward(m);
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

  // ── Esmâ serisi ──────────────────────────────────────────────────────────

  /// Esmâ-ül Hüsnâ ekranı açıldığında çağrılır.
  /// Bugün ilk açılışsa seriyi ilerletir; milestone yakalandıysa ödül döner.
  Future<RewardInfo?> trackEsmaRead() async {
    final today = _today();
    final lastDate = _storage.lastEsmaDate;

    int streak;
    if (lastDate == today) {
      streak = _storage.esmaStreak; // Bugün zaten sayıldı
    } else if (lastDate == _yesterday()) {
      streak = _storage.esmaStreak + 1;
    } else {
      streak = 1;
    }
    await _storage.setEsmaStreak(streak);
    await _storage.setLastEsmaDate(today);
    await _storage.incrementEsmaCount();

    return _checkCategoryMilestone(
      streak: streak,
      lastRewarded: _storage.lastRewardedEsmaStreak,
      setLastRewarded: _storage.setLastRewardedEsmaStreak,
      buildReward: _buildEsmaReward,
    );
  }

  Future<RewardInfo?> checkEsmaStreakReward() async {
    return _checkCategoryMilestone(
      streak: _storage.esmaStreak,
      lastRewarded: _storage.lastRewardedEsmaStreak,
      setLastRewarded: _storage.setLastRewardedEsmaStreak,
      buildReward: _buildEsmaReward,
    );
  }

  // ── Hadis serisi ─────────────────────────────────────────────────────────

  Future<RewardInfo?> trackHadisRead() async {
    final today = _today();
    final lastDate = _storage.lastHadisDate;

    int streak;
    if (lastDate == today) {
      streak = _storage.hadisStreak;
    } else if (lastDate == _yesterday()) {
      streak = _storage.hadisStreak + 1;
    } else {
      streak = 1;
    }
    await _storage.setHadisStreak(streak);
    await _storage.setLastHadisDate(today);
    await _storage.incrementHadisCount();

    return _checkCategoryMilestone(
      streak: streak,
      lastRewarded: _storage.lastRewardedHadisStreak,
      setLastRewarded: _storage.setLastRewardedHadisStreak,
      buildReward: _buildHadisReward,
    );
  }

  Future<RewardInfo?> checkHadisStreakReward() async {
    return _checkCategoryMilestone(
      streak: _storage.hadisStreak,
      lastRewarded: _storage.lastRewardedHadisStreak,
      setLastRewarded: _storage.setLastRewardedHadisStreak,
      buildReward: _buildHadisReward,
    );
  }

  // Ayet açılışı — sadece sayaç artırılır (Kur'ân serisi markQuranRead ile izlenir)
  Future<void> trackAyetOpen() => _storage.incrementAyetCount();

  // ── Teheccüd ödülü ───────────────────────────────────────────────────────

  Future<bool> checkTahajjudReward() async {
    if (!_storage.tahajjudEnabled) return false;
    final alarmDateStr = _storage.tahajjudAlarmDate;
    if (alarmDateStr == null) return false;

    final today = _today();
    final alreadyDone = await _rewardRepo.hasRewardForDate('tahajjud', today);
    if (alreadyDone) return false;

    final yesterday = _yesterday();
    if (alarmDateStr != today && alarmDateStr != yesterday) return false;

    final hour = DateTime.now().hour;
    if (hour < 2 || hour > 8) return false;

    await _rewardRepo.saveReward(
      type: 'tahajjud',
      title: 'Teheccüd Ödülü',
      message: 'Bu gece milyonlar uykudayken sen Rabbinle buluştun.'
          ' Bu sadakat, kalbinde hiç sönmeyecek bir kandil yaktı. Mübarek olsun.',
    );
    return true;
  }

  // ── Yardımcılar ──────────────────────────────────────────────────────────

  Future<RewardInfo?> _checkCategoryMilestone({
    required int streak,
    required int lastRewarded,
    required Future<void> Function(int) setLastRewarded,
    required RewardInfo Function(int) buildReward,
  }) async {
    for (final m in _readingMilestones.reversed) {
      if (streak >= m && lastRewarded < m) {
        await setLastRewarded(m);
        final info = buildReward(m);
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

  // ── Kur'ân ödül metinleri ────────────────────────────────────────────────

  RewardInfo _buildKuranReward(int m) {
    return RewardInfo(
      type: 'streak_kuran',
      emoji: '📖',
      milestone: m,
      title: '${_gunLabel(m)} Kur\'ân Serisi',
      message: _kuranMesaj(m),
    );
  }

  String _kuranMesaj(int m) {
    switch (m) {
      case 3:
        return "Üç gündür Allah'ın kelâmıyla yüz yüzesin. Melekler seni hayırla andı."
            " Bu devam eden bir güzelliğin başlangıcı.";
      case 7:
        return "Yedi gün, bir haftalık hatim süresince her gün Kur'ân okudun."
            " Kalbinde Kur'ân'ın nuru parıldıyor.";
      case 15:
        return "On beş günlük Kur'ân yolculuğu! Her iki haftada bir hatim"
            " derecesine erişiyorsun. Bu alışkanlık kalıcı olsun.";
      case 30:
        return "Otuz gün, tam bir Ramazan süresi! Bir ay boyunca her gün"
            " Allah'ın ayetleriyle buluştun. Bu sadakat nadir bir güzellik.";
      case 90:
        return "Üç ay! Kur'ân-ı Kerîm'i doksan gündür hayatının merkezine koydun."
            " Bu istikrar, seni Allah'ın sevgili kulları arasına katar.";
      case 180:
        return "Altı ay boyunca kesintisiz Kur'ân okudun. Bu adanmışlık,"
            " kıyamet günü Kur'ân'ın şefaatine nail olmak için güçlü bir vesiledir.";
      case 365:
        return "Tam bir yıl! Her gün Kur'ân'la başlayan sabahların birikimi"
            " bu. Allah bu ibadeti kabul eylesin, seni Kur'ân ehli kılsın.";
      default:
        final ay = m ~/ 30;
        if (ay >= 2) return "$ay aylık Kur'ân serisi tamamlandı. Mâşallah, ne güzel bir devam!";
        return "$m günlük Kur'ân serisi tamamlandı. Kalbinde Allah'ın kelâmı filizleniyor.";
    }
  }

  // ── Esmâ ödül metinleri ──────────────────────────────────────────────────

  RewardInfo _buildEsmaReward(int m) {
    return RewardInfo(
      type: 'streak_esma',
      emoji: '✨',
      milestone: m,
      title: '${_gunLabel(m)} Esmâ Serisi',
      message: _esmaMesaj(m),
    );
  }

  String _esmaMesaj(int m) {
    switch (m) {
      case 3:
        return "Üç gün boyunca Allah'ın isimlerini zikrettin. Melekler seni hayırla andı."
            " Bu devam eden bir güzelliğin başlangıcı.";
      case 7:
        return "Yedi gün, bir hafta boyunca Esmâ-ül Hüsnâ ile yoldaş oldun."
            " Allah'ın 99 ismini tanımak, O'nu daha derinden bilmek demektir.";
      case 15:
        return "On beş günlük Esmâ yolculuğu! Allah'ın isimlerini zikretmek,"
            " kalbe huzur, hayata bereket katar.";
      case 30:
        return "Otuz gün, bir ay boyunca her gün Allah'ın isimlerini zikrettin."
            " Bu ibadete devam et; bu yolda ilerlemek seni O'na yaklaştırır.";
      case 90:
        return "Üç ay! Esmâ-ül Hüsnâ'yı doksan gündür zikreden kalpte"
            " Allah'ın nuru yerleşir. Bu derinliği kaybetme.";
      case 180:
        return "Altı ay boyunca Esmâ-ül Hüsnâ ile başlayan günlerin birikimi bu."
            " Allah'ın isimlerini bilen, O'nun sıfatlarını taşır.";
      case 365:
        return "Bir yıl boyunca her gün Esmâ-ül Hüsnâ okudun. Bu ilâhî isimlerin"
            " mânâsı artık kalbine işlemiştir. Allah kabul eylesin.";
      default:
        final ay = m ~/ 30;
        if (ay >= 2) return "$ay aylık Esmâ serisi tamamlandı. Allah'ın isimlerini zikretmeye devam et!";
        return "$m günlük Esmâ serisi tamamlandı. Zikirle dolan bir kalp, huzurla dolar.";
    }
  }

  // ── Hadis ödül metinleri ─────────────────────────────────────────────────

  RewardInfo _buildHadisReward(int m) {
    return RewardInfo(
      type: 'streak_hadis',
      emoji: '📜',
      milestone: m,
      title: '${_gunLabel(m)} Hadis Serisi',
      message: _hadisMesaj(m),
    );
  }

  String _hadisMesaj(int m) {
    switch (m) {
      case 3:
        return "Üç gün Peygamber Efendimiz'in sözlerini okudun."
            " 'Benim sünnetimi seven beni sever' buyurulan bu yola girdin.";
      case 7:
        return "Yedi gün boyunca hadis-i şerifler eşliğinde yürüdün."
            " Hz. Muhammed'in nurlu sözleri kalbinde meşale yaktı.";
      case 15:
        return "On beş günlük sünnet yolculuğu! Peygamber Efendimiz'in hadisleri,"
            " hayatın her alanına ışık tutar.";
      case 30:
        return "Otuz gün sünnet yolunda! Bir ay boyunca Hz. Peygamber'in izinde"
            " yürüdün. Bu sadakatin karşılığını bulacaksın.";
      case 90:
        return "Üç ay hadis okudun. Hz. Peygamber'e olan muhabbetini bu süreklilikle"
            " ispatlıyorsun. Allah bu muhabbeti artırsın.";
      case 180:
        return "Altı ay boyunca her gün sünnet yolunda yürüdün. Bu adanmışlık,"
            " kıyamette şefaate vesile olsun.";
      case 365:
        return "Bir yıl boyunca her gün hadis okudun. Peygamber Efendimiz'in"
            " sözleri artık hayatının ayrılmaz bir parçası oldu. Mâşallah!";
      default:
        final ay = m ~/ 30;
        if (ay >= 2) return "$ay aylık Hadis serisi tamamlandı. Sünnet yolunda devam et!";
        return "$m günlük Hadis serisi tamamlandı. Hz. Peygamber'in izinde yürümeye devam et.";
    }
  }

  // ── Yardımcı ─────────────────────────────────────────────────────────────

  static String _gunLabel(int m) {
    if (m == 365) return '1 Yıllık';
    final ay = m ~/ 30;
    final gun = m % 30;
    if (ay > 0 && gun == 0) return '$ay Aylık';
    if (ay > 0) return '$ay Ay $gun Günlük';
    return '$m Günlük';
  }
}
