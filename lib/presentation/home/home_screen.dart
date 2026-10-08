import 'dart:async' show Timer, unawaited;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../auth/login_screen.dart' show EmailVerificationScreen;
import '../auth/consent_screen.dart';
import '../../core/services/consent_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/reward_service.dart';
import '../../data/models/esma_model.dart';
import '../../data/models/hadis_model.dart';
import '../../data/models/ayet_model.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/custom_task_repository.dart';
import '../../data/models/custom_task_model.dart';
import '../../data/models/user_model.dart';
import '../esma/esma_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../notes/notes_screen.dart';
import '../reminders/reminders_screen.dart';
import '../community/community_join_screen.dart';
import 'widgets/content_card.dart';
import 'widgets/islamic_header.dart';
import 'widgets/quran_tracker_card.dart';
import 'widgets/community_task_list.dart';
import 'widgets/custom_task_card.dart';
import '../ayet/ayet_detail_screen.dart';
import '../hadis/hadis_detail_screen.dart';
import '../rewards/murakabe_hosgeldin_screen.dart';
import '../rewards/tahajjud_odul_screen.dart';
import '../rewards/tebrik_karti_screen.dart';
import '../rewards/reward_flow.dart';
import '../../core/services/badge_service.dart';
import '../../core/services/firestore_notification_service.dart';
import '../../core/services/role_service.dart';
import '../../core/services/widget_bridge_service.dart';
import '../quran/quran_screen.dart';
// TELİF: İzin alınana kadar kapalı. Açmak için bu iki import'u ve aşağıdaki
// iki menü öğesindeki _goToPage satırlarını geri açın, pubspec.yaml'daki
// PDF asset satırlarını da yorumdan çıkarın.
// import '../tefsir/tefhimul_kuran_screen.dart';
// import '../riyazussalihin/riyazus_salihin_screen.dart';
import '../../data/repositories/zikir_repository.dart';
import 'widgets/zikir_home_card.dart';
import '../zikir/zikir_sayac_screen.dart';
import 'widgets/tasbih_icon.dart';
import '../../data/local/local_storage.dart';
import '../community/community_screen.dart';
import 'widgets/community_activity_preview.dart';
import '../../core/constants/nav_shortcuts.dart';
import '../kible/kible_bulucu_screen.dart';
import '../settings/settings_screen.dart';
import '../onboarding/permission_onboarding_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _contentRepo = ContentRepository();
  final _userRepo = UserRepository();
  final _taskRepo = CustomTaskRepository();

  final _profileKey = GlobalKey<ProfileScreenState>();
  final _notesKey = GlobalKey<NotesScreenState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  EsmaModel? _todayEsma;
  HadisModel? _todayHadis;
  AyetModel? _todayAyet;
  ActiveZikir? _todayZikir;
  int _zikirCount = 0;
  UserModel? _currentUser;
  bool _quranReadToday = false;
  bool _isLoading = true;
  int _selectedIndex = 0;
  List<CustomTaskModel> _activeTasks = [];
  bool _notificationsScheduled = false;
  Map<String, String> _communityIdNameMap = {};
  bool _tasksSectionHidden = false;
  bool _communitySectionHidden = false;

  // Ekrandaki içeriğin ait olduğu gün ("yyyy-MM-dd"). Uygulama açık ya da
  // arka planda beklerken gün değişirse içerik/namaz vakitleri yenilenir —
  // önceden ancak uygulama tamamen kapatılıp açılınca değişiyordu.
  static String _todayKey() => DateTime.now().toIso8601String().substring(0, 10);
  String _loadedDay = _todayKey();
  Timer? _midnightTimer;

  void _scheduleMidnightRefresh() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1, 0, 0, 5);
    _midnightTimer = Timer(nextDay.difference(now), () {
      _checkDayChange();
      _scheduleMidnightRefresh();
    });
  }

  void _checkDayChange() {
    if (!mounted) return;
    final today = _todayKey();
    if (today == _loadedDay) return;
    setState(() {
      _loadedDay = today;
      // Yeni günde bildirimler yeniden planlansın — 30 günlük pencere de
      // böylece bir gün ileri kayar.
      _notificationsScheduled = false;
    });
    _loadContent();
  }

  // E-postası doğrulanmamış bir hesap ana sayfaya HANGİ yoldan gelirse
  // gelsin (splash, giriş, hesap değiştirme, profil kurulumu, eski bir
  // akış…) doğrulama ekranına geri gönderilir. Splash zaten kontrol
  // ediyor; bu, tek bir eksik yolun doğrulamayı atlatmasını engelleyen
  // ikinci kilit. Sahip hesabı (AppStrings.isOwnerEmail) bu kontrolden muaf — splash ve
  // girişteki istisnayla aynı.
  bool _redirectingToVerification = false;

  // Onay kapısı: güncel koşulları/açık rızayı onaylamamış kullanıcı (eski
  // kullanıcılar dahil) ConsentScreen'e yönlendirilir ve onaylamadan geri
  // dönemez. İzin tanıtımı ve ödül akışları bu kontrol bitene kadar bekler.
  Future<bool> _consentOk = Future.value(true);

  Future<bool> _enforceConsent() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return true;
    final ok = await ConsentService.hasAccepted(uid);
    if (ok || !mounted) return ok;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ConsentScreen()),
        (_) => false,
      );
    });
    return false;
  }

  bool _mustVerifyEmail() {
    final user = FirebaseAuth.instance.currentUser;
    return user != null &&
        !AppStrings.isOwnerEmail(user.email) &&
        !user.emailVerified;
  }

  @override
  void initState() {
    super.initState();
    if (_mustVerifyEmail()) {
      _redirectingToVerification = true;
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (_) => EmailVerificationScreen(email: email)),
          (_) => false,
        );
      });
      return; // içerik/bildirim/dinleyici hiçbiri başlatılmaz
    }
    _consentOk = _enforceConsent();
    WidgetsBinding.instance.addObserver(this);
    _scheduleMidnightRefresh();
    _tasksSectionHidden = LocalStorage().tasksSectionHidden;
    _communitySectionHidden = LocalStorage().communitySectionHidden;
    FirestoreNotificationService().start();
    // E-posta değişikliği doğrulanmışsa (bkz. UserRepository.
    // syncEmailFromAuth) SQLite/Firestore/savedAccounts'u senkronize et —
    // best-effort, açılışı asla bloklamaz.
    unawaited(_userRepo.syncEmailFromAuth());
    // Önceki bir restore'da eksik kalan not/görev/ödül gibi alt
    // koleksiyonlar varsa tekrar dene — bkz. UserRepository.
    // retryPendingSubcollectionRestore.
    unawaited(_userRepo.retryPendingSubcollectionRestore());
    _loadContent().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        if (!await _consentOk || !mounted) return;
        await _maybeShowPermissionOnboarding();
        if (!mounted) return;
        _checkRewards();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    // ÖNCEDEN burada stop() çağrılmıyordu: HomeScreen dispose olduğunda
    // (ör. çıkış yapma → LoginScreen'e pushAndRemoveUntil) Firestore
    // dinleyicileri (bildirim + sohbet) arka planda çalışmaya devam
    // ediyordu — gereksiz Firestore okuması ve potansiyel olarak yanlış
    // hesap için bildirim tetiklenmesi riski.
    FirestoreNotificationService().stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Zikir widget'ından yapılan +1 native tarafta SharedPreferences
    // dosyasına doğrudan yazılıyor; Flutter'ın bellekteki önbelleği bunu
    // uygulama öne dönene kadar görmüyor — bu yüzden burada zorla reload.
    if (state == AppLifecycleState.resumed) {
      // Arka planda beklerken gün değiştiyse içeriği yenile; Timer arka
      // planda donmuş olabilir, yeniden kur.
      _checkDayChange();
      _scheduleMidnightRefresh();
      LocalStorage().reload().then((_) => _refreshZikirCount());
      // Kullanıcı ayarlar dışına çıkıp e-posta doğrulama linkine tıkladıktan
      // sonra uygulamaya geri dönebilir — bkz. initState'teki açıklama.
      unawaited(_userRepo.syncEmailFromAuth());
    }
  }

  /// Kayıt/giriş sonrası HomeScreen'e ilk kez gelindiğinde (ve sadece o
  /// zaman) bildirim + konum izin tanıtım ekranını gösterir. Tüm giriş
  /// yolları (yeni kayıt, mevcut hesapla giriş, profil kurulumunu atla)
  /// buradan geçtiği için izin akışı tek bir yerden yönetiliyor.
  Future<void> _maybeShowPermissionOnboarding() async {
    if (LocalStorage().permissionOnboardingDone) return;
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PermissionOnboardingScreen(
        onDone: () => Navigator.of(context).pop(),
      ),
      fullscreenDialog: true,
    ));
  }

  Future<void> _checkRewards() async {
    if (!mounted) return;
    // Navigator'ı async gap'lerden önce yakala — context geçerliliği için kritik.
    final nav = Navigator.of(context);
    final rewardService = RewardService();
    final badgeService = BadgeService();

    if (rewardService.shouldShowWelcome) {
      if (!mounted) return;
      await nav.push(MaterialPageRoute(
        builder: (_) => MurakabeHosgeldinScreen(
          onDone: () => nav.pop(),
        ),
      ));
      return;
    }

    if (_currentUser != null) {
      // Kur'ân serisi
      final kuranReward =
          await rewardService.checkKuranStreakReward(_currentUser!.streakDays);
      if (!mounted) return;
      if (kuranReward != null) {
        await nav.push(MaterialPageRoute(
          builder: (_) => TebrikKartiScreen(
            type: kuranReward.type,
            title: kuranReward.title,
            message: kuranReward.message,
            autoSave: false,
          ),
        ));
      }

      // Esmâ serisi
      if (!mounted) return;
      final esmaReward = await rewardService.checkEsmaStreakReward();
      if (!mounted) return;
      if (esmaReward != null) {
        await nav.push(MaterialPageRoute(
          builder: (_) => TebrikKartiScreen(
            type: esmaReward.type,
            title: esmaReward.title,
            message: esmaReward.message,
            autoSave: false,
          ),
        ));
      }

      // Hadis serisi
      if (!mounted) return;
      final hadisReward = await rewardService.checkHadisStreakReward();
      if (!mounted) return;
      if (hadisReward != null) {
        await nav.push(MaterialPageRoute(
          builder: (_) => TebrikKartiScreen(
            type: hadisReward.type,
            title: hadisReward.title,
            message: hadisReward.message,
            autoSave: false,
          ),
        ));
      }
    }

    // Teheccüd gece ödülü — önceden burada kullanıcıya HİÇ sorulmadan,
    // yalnızca "alarm açıktı + saat 02:00-08:00 arası" koşuluyla ödül
    // veriliyordu. Artık önce kısa bir onay soruluyor; ödül yalnızca
    // "Evet, kıldım" cevabıyla veriliyor (bkz. RewardService.
    // shouldPromptTahajjud / confirmTahajjudPrayed).
    if (!mounted) return;
    final shouldPrompt = await rewardService.shouldPromptTahajjud();
    if (!mounted) return;
    if (shouldPrompt) {
      final prayed = await _askTahajjudConfirmation();
      if (!mounted) return;
      final showTahajjud = await rewardService.confirmTahajjudPrayed(prayed);
      if (!mounted) return;
      if (showTahajjud) {
        await nav.push(MaterialPageRoute(
          builder: (_) => const TahajjudOdulScreen(),
        ));
      }
    }

    // Teheccüd aylık kart (ayda 4 gece)
    if (!mounted) return;
    final showMonthlyCard = await badgeService.checkTahajjudMonthlyCard();
    if (!mounted) return;
    if (showMonthlyCard) {
      await nav.push(MaterialPageRoute(
        builder: (_) => const TebrikKartiScreen(
          type: 'tahajjud_aylik',
          title: 'Aylık Teheccüd Sadığı',
          message: 'Bu ay 4 gece teheccüd namazı kıldın. Gecenin bu'
              ' sessizliğinde Rabbine koşman, kalbine nur katar. Mâşallah!',
          autoSave: true,
        ),
      ));
    }

    // Rozet kontrolü
    if (!mounted || _currentUser == null) return;
    final earnedBadges = await badgeService.checkAndAward(_currentUser!);
    for (final badge in earnedBadges) {
      if (!mounted) return;
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
  }

  /// "Teheccüde kalktın mı?" onayını sorar. Yalnızca "Evet, kıldım"
  /// seçilirse `true` döner — ödül buna bağlı olarak verilir (bkz.
  /// _checkRewards, RewardService.confirmTahajjudPrayed).
  Future<bool> _askTahajjudConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A3B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Teheccüde Kalktın mı?',
          style: GoogleFonts.playfairDisplay(
              color: AppColors.gold, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Alarmın bu gece/dün gece için kuruluydu. Teheccüd namazını'
          ' kıldıysan aşağıdan onaylayabilirsin.',
          style: GoogleFonts.notoSans(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hayır, kılmadım',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Evet, kıldım'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  // ÖNEMLİ: Her veri kaynağı kendi try/catch'i içinde çağrılıyor.
  // Eskiden tüm await'ler tek bir try bloğundaydı — herhangi biri
  // (görevler, topluluk, zikir vb.) hata fırlattığında setState hiç
  // çalışmıyordu ve esma/ayet/hadis çekilmiş olsa bile ekrana hiçbir şey
  // yansımıyordu. Artık bir kaynağın başarısız olması diğerlerini etkilemiyor.
  Future<void> _loadContent() async {
    EsmaModel? esma;
    HadisModel? hadis;
    AyetModel? ayet;
    bool quranRead = false;
    ActiveZikir? zikir;
    int zikirCount = 0;
    UserModel? user;
    List<CustomTaskModel> tasks = [];
    Map<String, String> communityIdNameMap = {};

    try {
      esma = await _contentRepo.getTodayEsma();
    } catch (e) {
      debugPrint('❌ getTodayEsma hata: $e');
    }
    try {
      hadis = await _contentRepo.getTodayHadis();
    } catch (e) {
      debugPrint('❌ getTodayHadis hata: $e');
    }
    try {
      ayet = await _contentRepo.getTodayAyet();
    } catch (e) {
      debugPrint('❌ getTodayAyet hata: $e');
    }
    try {
      quranRead = await _userRepo.isQuranReadToday();
    } catch (e) {
      debugPrint('❌ isQuranReadToday hata: $e');
    }
    try {
      final zikirRepo = ZikirRepository();
      zikir = await zikirRepo.getActiveZikir();
      zikirCount = zikirRepo.currentCount;
    } catch (e) {
      debugPrint('❌ getActiveZikir hata: $e');
    }
    try {
      user = await _userRepo.getCurrentUser();
    } catch (e) {
      debugPrint('❌ getCurrentUser hata: $e');
    }
    try {
      tasks = await _taskRepo.getActiveTasks();
    } catch (e) {
      debugPrint('❌ getActiveTasks hata: $e');
    }
    try {
      // Çevrimdışıyken Firestore ~10 sn bekleyebiliyor ve bu bitmeden ana
      // sayfa içeriği HİÇ gösterilmiyordu. En fazla 4 sn beklenir; sorgu
      // daha geç tamamlanırsa (yavaş internet) sonuç YİNE DE uygulanır —
      // topluluk bölümü ve sohbet bildirimi dinleyicileri kaybolmasın.
      final communityFuture = RoleService().getUserCommunityIdNameMap();
      var timedOut = false;
      communityIdNameMap = await communityFuture.timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          timedOut = true;
          return <String, String>{};
        },
      );
      if (timedOut) {
        unawaited(communityFuture.then((map) {
          if (!mounted || map.isEmpty) return;
          setState(() => _communityIdNameMap = map);
          try {
            FirestoreNotificationService().startChatListeners(map);
          } catch (_) {}
        }).catchError((_) {}));
      }
    } catch (e) {
      debugPrint('❌ getUserCommunityIdNameMap hata: $e');
    }

    if (mounted) {
      setState(() {
        _todayEsma = esma;
        _todayHadis = hadis;
        _todayAyet = ayet;
        _quranReadToday = quranRead;
        _todayZikir = zikir;
        _zikirCount = zikirCount;
        _currentUser = user;
        _activeTasks = tasks;
        _communityIdNameMap = communityIdNameMap;
        _isLoading = false;
      });
      // Sohbet mesaj dinleyicilerini güncelle
      try {
        FirestoreNotificationService().startChatListeners(_communityIdNameMap);
      } catch (e) {
        debugPrint('❌ startChatListeners hata: $e');
      }

      if (!_notificationsScheduled &&
          esma != null &&
          hadis != null &&
          ayet != null) {
        _notificationsScheduled = true;
        _scheduleAllNotifications(esma, hadis, ayet);
      }

      // Ana ekran widget'larını (namaz vakti/zikir/günlük içerik) tazele.
      // Konum gerektirdiği için biraz sürebilir — home screen'i beklemesin.
      WidgetBridgeService().refreshAll();
    }
  }

  Future<void> _scheduleAllNotifications(
    EsmaModel? esma,
    HadisModel? hadis,
    AyetModel? ayet,
  ) async {
    if (esma == null || hadis == null || ayet == null) return;

    // Her adım ayrı try/catch içinde: önceden ilk adım hata verirse
    // (ör. release derlemedeki Gson/R8 sorunu) geri kalan HİÇBİR bildirim
    // planlanmıyordu ve hata sessizce kayboluyordu.
    final steps = <String, Future<void> Function()>{
      'günlük içerik': () => NotificationService().scheduleDailyNotifications(),
      'perşembe teheccüd': () => NotificationService().scheduleThursdayTahajjud(),
      'cuma özeti': () => NotificationService().scheduleWeeklyFridaySummary(),
      'Kur\'an saatlik': () => NotificationService()
          .scheduleHourlyQuranReminders(_quranReadToday),
      'görevler': () => _taskRepo.syncNotifications(),
    };
    for (final entry in steps.entries) {
      try {
        await entry.value();
      } catch (e) {
        debugPrint('❌ Bildirim planlama (${entry.key}) hata: $e');
        unawaited(LocalStorage().setNotifLastError(
            '${DateTime.now().toIso8601String().substring(0, 16)} | '
            '${entry.key}: $e'));
      }
    }
  }

  Future<void> _refreshZikirCount() async {
    await LocalStorage().reload();
    final repo = ZikirRepository();
    final zikir = await repo.getActiveZikir();
    final count = repo.currentCount;
    if (mounted) {
      setState(() {
        _todayZikir = zikir;
        _zikirCount = count;
      });
    }
  }

  void _toggleTasksSection() {
    setState(() => _tasksSectionHidden = !_tasksSectionHidden);
    LocalStorage().setTasksSectionHidden(_tasksSectionHidden);
  }

  void _toggleCommunitySection() {
    setState(() => _communitySectionHidden = !_communitySectionHidden);
    LocalStorage().setCommunitySectionHidden(_communitySectionHidden);
  }

  Future<void> _refreshContent() async {
    setState(() => _isLoading = true);
    await _loadContent();
  }

  void _onTabChanged(int i) {
    setState(() => _selectedIndex = i);
    if (i == 1) _notesKey.currentState?.reload();
    if (i == 2) FirestoreNotificationService().clearCommunityBadge();
    if (i == 3) _profileKey.currentState?.reload();
  }

  void _goToTab(int i) {
    _scaffoldKey.currentState?.closeDrawer();
    setState(() => _selectedIndex = i);
  }

  void _goToPage(Widget page) {
    _scaffoldKey.currentState?.closeDrawer();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _showComingSoon(String name) {
    _scaffoldKey.currentState?.closeDrawer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name yakında geliyor!'),
        backgroundColor: const Color(0xFF1B3A4B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_redirectingToVerification) {
      return const Scaffold(backgroundColor: Color(0xFF0D1B2A));
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _selectedIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() => _selectedIndex = 0);
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        // Soldan açılan drawer — sağa kaydırınca açılır
        drawer: _buildDrawer(isDark),
        body: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomePage(),
            NotesScreen(
              key: _notesKey,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            CommunityJoinScreen(
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            ProfileScreen(
              key: _profileKey,
              onTasksChanged: _refreshContent,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(isDark),
      ),
    );
  }

  // ── DRAWER ───────────────────────────────────────────────────────────────

  Widget _buildDrawer(bool isDark) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.78,
      backgroundColor:
          isDark ? const Color(0xFF0A0E1A) : const Color(0xFF0D1B2A),
      child: SafeArea(
        child: Column(
          children: [
            _buildDrawerHeader(),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _buildDrawerSection('Sayfalar'),
                  _buildDrawerItem(
                    icon: Icons.home_outlined,
                    label: 'Ana Sayfa',
                    isActive: _selectedIndex == 0,
                    onTap: () => _goToTab(0),
                  ),
                  _buildDrawerItem(
                    icon: Icons.note_outlined,
                    label: 'Notlarım',
                    isActive: _selectedIndex == 1,
                    onTap: () => _goToTab(1),
                  ),
                  _buildDrawerItem(
                    icon: Icons.alarm_outlined,
                    label: 'Hatırlatıcı',
                    onTap: () => _goToPage(const RemindersScreen()),
                  ),
                  _buildDrawerItem(
                    icon: Icons.group_outlined,
                    label: 'Topluluk',
                    isActive: _selectedIndex == 2,
                    onTap: () => _goToTab(2),
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_outline,
                    label: 'Profil',
                    isActive: _selectedIndex == 3,
                    onTap: () => _goToTab(3),
                  ),
                  _buildDrawerItem(
                    iconWidget: const TasbihIcon(
                      color: Colors.white54,
                      size: 20,
                    ),
                    label: 'Zikir',
                    onTap: () => _goToPage(const ZikirSayacScreen()),
                  ),
                  _buildDrawerItem(
                    icon: Icons.explore_outlined,
                    label: 'Kıble Bulucu',
                    onTap: () => _goToPage(const KibleBulucuScreen()),
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 4),
                  _buildDrawerSection('Okumalar'),
                  _buildDrawerItem(
                    icon: Icons.menu_book_outlined,
                    label: 'Kuran-ı Kerim',
                    onTap: () => _goToPage(const QuranScreen()),
                  ),
                  _buildDrawerItem(
                    icon: Icons.auto_stories_outlined,
                    label: 'Tefhimul Kuran',
                    badge: 'Yakında',
                    // onTap: () => _goToPage(const TefhimulKuranScreen()),
                    onTap: () => _showComingSoon('Tefhimul Kuran'),
                  ),
                  _buildDrawerItem(
                      icon: Icons.auto_stories_outlined,
                      label: 'Riyazüs Salihin',
                      badge: 'Yakında',
                      // onTap: () => _goToPage(const RiyazusSalihinScreen())),
                      onTap: () => _showComingSoon('Riyazüs Salihin')),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 4),
                  _buildDrawerSection('Keşfet'),
                  _buildDrawerItem(
                    icon: Icons.lightbulb_outline,
                    label: 'Biliyor musun?',
                    badge: 'Yakında',
                    onTap: () => _showComingSoon('Biliyor musun?'),
                  ),
                  _buildDrawerItem(
                    icon: Icons.quiz_outlined,
                    label: 'Quiz',
                    badge: 'Yakında',
                    onTap: () => _showComingSoon('Quiz'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                style: GoogleFonts.amiri(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 1.5),
                ),
                child: ClipOval(
                  child:
                      Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Murakabe',
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.gold,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_currentUser != null)
                    Text(
                      _currentUser!.nameSurname,
                      style: GoogleFonts.notoSans(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
          if (_currentUser != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                _buildDrawerStat('🔥', '${_currentUser!.streakDays}', 'Seri'),
                const SizedBox(width: 20),
                _buildDrawerStat(
                    '📖', '${_currentUser!.quranReadDays}', 'Kuran'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawerStat(String emoji, String value, String label) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          value,
          style: GoogleFonts.playfairDisplay(
            color: AppColors.gold,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.notoSans(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildDrawerSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 10, 0, 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.notoSans(
          color: Colors.white24,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    IconData? icon,
    Widget? iconWidget,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    String? badge,
  }) {
    assert(icon != null || iconWidget != null,
        'icon veya iconWidget\'tan biri verilmeli');
    final iconColor = isActive ? AppColors.gold : Colors.white54;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.gold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppColors.gold.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            iconWidget ?? Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.notoSans(
                  color: isActive ? AppColors.gold : Colors.white70,
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.turquoise.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.turquoise.withValues(alpha: 0.4)),
                ),
                child: Text(
                  badge,
                  style: GoogleFonts.notoSans(
                    color: AppColors.turquoiseLight,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── ANA SAYFA ─────────────────────────────────────────────────────────────

  Widget _buildHomePage() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.gold),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshContent,
      color: AppColors.gold,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: IslamicHeader(
              // Gün değişince başlık (namaz vakitleri) sıfırdan yüklensin.
              key: ValueKey('islamic_header_$_loadedDay'),
              user: _currentUser,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (_todayEsma != null)
                  ContentCard(
                    type: 'esma',
                    contentId: _todayEsma!.id,
                    title: _todayEsma!.arabic,
                    subtitle: _todayEsma!.meaning,
                    tag: 'Günün Esması',
                    color: AppColors.gold,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EsmaDetailScreen(esma: _todayEsma!),
                      ),
                    ).then((_) => _profileKey.currentState?.reload()),
                    onRemind: () {},
                  ),
                const SizedBox(height: 16),
                if (_todayAyet != null)
                  ContentCard(
                    type: 'ayet',
                    contentId: _todayAyet!.id,
                    title: _todayAyet!.arabic,
                    subtitle: _todayAyet!.turkish,
                    tag:
                        '${_todayAyet!.surah} - ${_todayAyet!.ayahNumber}. Ayet',
                    color: AppColors.turquoise,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AyetDetailScreen(ayet: _todayAyet!),
                      ),
                    ).then((_) => _profileKey.currentState?.reload()),
                    onRemind: () {},
                  ),
                const SizedBox(height: 16),
                if (_todayHadis != null)
                  ContentCard(
                    type: 'hadis',
                    contentId: _todayHadis!.id,
                    title: _todayHadis!.arabic.isNotEmpty
                        ? _todayHadis!.arabic
                        : 'Hadis',
                    subtitle: _todayHadis!.text,
                    tag: _todayHadis!.source,
                    color: const Color(0xFF6B4226),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HadisDetailScreen(hadis: _todayHadis!),
                      ),
                    ).then((_) => _profileKey.currentState?.reload()),
                    onRemind: () {},
                  ),
                const SizedBox(height: 16),
                if (_todayZikir != null)
                  ZikirHomeCard(
                    active: _todayZikir!,
                    count: _zikirCount,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ZikirSayacScreen(),
                      ),
                    ).then((_) => _refreshZikirCount()),
                  ),
                if (_todayZikir != null) const SizedBox(height: 16),
                const SizedBox(height: 16),
                QuranTrackerCard(
                  isRead: _quranReadToday,
                  onRead: () async {
                    // Önce kart ANINDA yeşile döner, kayıt arkadan yapılır.
                    if (_quranReadToday) return;
                    final nav = Navigator.of(context);
                    setState(() => _quranReadToday = true);
                    final today =
                        DateTime.now().toIso8601String().substring(0, 10);
                    try {
                      await _userRepo.markQuranRead(today);
                    } catch (_) {
                      // Kayıt başarısız: kartı geri al, kullanıcı tekrar denesin.
                      if (mounted) setState(() => _quranReadToday = false);
                      return;
                    }
                    try {
                      await NotificationService().cancelKuranNotification();
                    } catch (_) {}
                    try {
                      final updatedUser = await _userRepo.getCurrentUser();
                      if (mounted) setState(() => _currentUser = updatedUser);
                    } catch (_) {}
                    // Kur'ân serisi tebriği + rozet kontrolü anında.
                    unawaited(RewardFlow.afterRead(nav, 'kuran'));
                  },
                ),
                if (_activeTasks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader(
                    icon: Icons.checklist_outlined,
                    label: 'GÖREVLERİM',
                    color: AppColors.gold,
                    isHidden: _tasksSectionHidden,
                    onToggle: _toggleTasksSection,
                  ),
                  if (!_tasksSectionHidden)
                    ..._activeTasks.map((task) => Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: CustomTaskCard(
                            task: task,
                            onCompleted: () async {
                              try {
                                await _taskRepo.markTaskCompleted(task.id);
                                final tasks = await _taskRepo.getActiveTasks();
                                if (mounted) {
                                  setState(() => _activeTasks = tasks);
                                }
                              } catch (_) {}
                            },
                          ),
                        )),
                ],
                if (_communityIdNameMap.isNotEmpty)
                  _buildCommunityTasksSection(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String label,
    required Color color,
    required bool isHidden,
    required VoidCallback onToggle,
  }) {
    return GestureDetector(
      onTap: onToggle,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 2),
        child: Row(
          children: [
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.notoSans(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const Spacer(),
            Text(
              isHidden ? 'göster' : 'gizle',
              style: GoogleFonts.notoSans(color: Colors.white24, fontSize: 10),
            ),
            const SizedBox(width: 2),
            Icon(
              isHidden ? Icons.chevron_right : Icons.expand_more,
              color: Colors.white24,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  // ── TOPLULUK GÖREVLERİ ────────────────────────────────────────────────────
  Widget _buildCommunityTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _buildSectionHeader(
          icon: Icons.group_outlined,
          label: 'TOPLULUK',
          color: AppColors.turquoise,
          isHidden: _communitySectionHidden,
          onToggle: _toggleCommunitySection,
        ),
        if (!_communitySectionHidden)
          ..._communityIdNameMap.entries.expand((e) => [
                CommunityActivityPreview(
                  communityId: e.key,
                  communityName: e.value,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CommunityScreen(communityId: e.key),
                    ),
                  ),
                ),
                CommunityTaskList(communityId: e.key, communityName: e.value),
              ]),
      ],
    );
  }
  // ── ALT NAV ───────────────────────────────────────────────────────────────

  Widget _buildBottomNav(bool isDark) {
    final shortcutIds = LocalStorage().navShortcutIds;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2035) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _displayIndexFor(shortcutIds),
        onTap: (tappedIndex) => _onBottomNavTap(tappedIndex, shortcutIds),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: isDark ? Colors.white38 : AppColors.textLight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Ana Sayfa',
          ),
          for (final id in shortcutIds) _buildNavItem(id),
        ],
      ),
    );
  }

  // Görsel slot pozisyonunu, sabit _selectedIndex değerine çevirir.
  int _displayIndexFor(List<String> shortcutIds) {
    if (_selectedIndex == 0) return 0;
    final pos = shortcutIds
        .indexWhere((id) => kTabShortcutFixedIndex[id] == _selectedIndex);
    return pos == -1 ? 0 : pos + 1;
  }

  void _onBottomNavTap(int tappedIndex, List<String> shortcutIds) {
    if (tappedIndex == 0) {
      _onTabChanged(0);
      return;
    }
    final id = shortcutIds[tappedIndex - 1];
    final def = findNavShortcut(id);
    if (def == null) return;

    if (def.type == NavShortcutType.tab) {
      final fixedIndex = kTabShortcutFixedIndex[id];
      if (fixedIndex != null) _onTabChanged(fixedIndex);
    } else {
      _openPushShortcut(id);
    }
  }

  void _openPushShortcut(String id) {
    Widget? screen;
    switch (id) {
      case 'kible':
        screen = const KibleBulucuScreen();
        break;
      case 'kuran':
        screen = const QuranScreen();
        break;
      case 'zikir':
        screen = const ZikirSayacScreen();
        break;
      case 'ayarlar':
        screen = const SettingsScreen();
        break;
    }
    if (screen == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen!))
        .then((_) => setState(() {})); // dönünce kısayollar tazelensin
  }

  BottomNavigationBarItem _buildNavItem(String id) {
    final def = findNavShortcut(id);

    // Topluluk rozeti (okunmamış mesaj göstergesi) hangi slotta olursa olsun korunur.
    if (id == 'community') {
      return BottomNavigationBarItem(
        icon: ValueListenableBuilder<bool>(
          valueListenable:
              FirestoreNotificationService().communityBadgeNotifier,
          builder: (_, hasBadge, __) => Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(def?.icon ?? Icons.group_outlined),
              if (hasBadge)
                Positioned(
                  top: -1,
                  right: -3,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF5350),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        label: def?.label ?? 'Topluluk',
      );
    }

    return BottomNavigationBarItem(
      icon: Icon(def?.icon ?? Icons.circle_outlined),
      label: def?.label ?? '',
    );
  }
}
