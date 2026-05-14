import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
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
import 'widgets/custom_task_card.dart';
import 'widgets/streak_card.dart';
import '../ayet/ayet_detail_screen.dart';
import '../hadis/hadis_detail_screen.dart';
import '../rewards/murakabe_hosgeldin_screen.dart';
import '../rewards/tahajjud_odul_screen.dart';
import '../rewards/tebrik_karti_screen.dart';
import '../../core/services/badge_service.dart';
import '../quran/quran_screen.dart';
import '../tefsir/tefhimul_kuran_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _contentRepo = ContentRepository();
  final _userRepo = UserRepository();
  final _taskRepo = CustomTaskRepository();

  final _profileKey = GlobalKey<ProfileScreenState>();
  final _notesKey = GlobalKey<NotesScreenState>();
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  EsmaModel? _todayEsma;
  HadisModel? _todayHadis;
  AyetModel? _todayAyet;
  UserModel? _currentUser;
  bool _quranReadToday = false;
  bool _isLoading = true;
  int _selectedIndex = 0;
  List<CustomTaskModel> _activeTasks = [];
  bool _notificationsScheduled = false;

  @override
  void initState() {
    super.initState();
    _loadContent().then((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _checkRewards();
      });
    });
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
      final kuranReward = await rewardService
          .checkKuranStreakReward(_currentUser!.streakDays);
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

    // Teheccüd gece ödülü
    if (!mounted) return;
    final showTahajjud = await rewardService.checkTahajjudReward();
    if (!mounted) return;
    if (showTahajjud) {
      await nav.push(MaterialPageRoute(
        builder: (_) => const TahajjudOdulScreen(),
      ));
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

  Future<void> _loadContent() async {
    try {
      final esma = await _contentRepo.getTodayEsma();
      final hadis = await _contentRepo.getTodayHadis();
      final ayet = await _contentRepo.getTodayAyet();
      final quranRead = await _userRepo.isQuranReadToday();
      final user = await _userRepo.getCurrentUser();
      final tasks = await _taskRepo.getActiveTasks();

      if (mounted) {
        setState(() {
          _todayEsma = esma;
          _todayHadis = hadis;
          _todayAyet = ayet;
          _quranReadToday = quranRead;
          _currentUser = user;
          _activeTasks = tasks;
          _isLoading = false;
        });

        if (!_notificationsScheduled) {
          _notificationsScheduled = true;
          _scheduleAllNotifications(esma, hadis, ayet);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleAllNotifications(
    EsmaModel esma,
    HadisModel hadis,
    AyetModel ayet,
  ) async {
    await NotificationService().scheduleDailyNotifications(
      esmaArabic: esma.arabic,
      esmaMeaning: esma.meaning,
      hadisText: hadis.text,
      hadisSource: hadis.source,
      ayetTurkish: ayet.turkish,
      surahName: ayet.surah,
    );
    await NotificationService().scheduleThursdayTahajjud();
    await NotificationService().scheduleWeeklyFridaySummary();
    await NotificationService().scheduleHourlyQuranReminders(_quranReadToday);
    await _taskRepo.syncNotifications();
  }

  Future<void> _refreshContent() async {
    setState(() => _isLoading = true);
    await _loadContent();
  }

  void _onTabChanged(int i) {
    setState(() => _selectedIndex = i);
    if (i == 1) _notesKey.currentState?.reload();
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
            NotesScreen(key: _notesKey),
            const CommunityJoinScreen(),
            ProfileScreen(
              key: _profileKey,
              onTasksChanged: _refreshContent,
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
                    onTap: () => _goToPage(const TefhimulKuranScreen()),
                  ),
                  _buildDrawerItem(
                    icon: Icons.auto_stories_outlined,
                    label: 'Feyzül Furkan',
                    badge: 'Yakında',
                    onTap: () => _showComingSoon('Feyzül Furkan'),
                  ),
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
                  color: AppColors.gold.withValues(alpha:0.4),
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
          bottom: BorderSide(color: AppColors.gold.withValues(alpha:0.2)),
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
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:
              isActive ? AppColors.gold.withValues(alpha:0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppColors.gold.withValues(alpha:0.4)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isActive ? AppColors.gold : Colors.white54, size: 20),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.turquoise.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.turquoise.withValues(alpha:0.4)),
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
                    onSave: () =>
                        _contentRepo.saveContent('esma', _todayEsma!.id),
                    onRemind: () {},
                  ),
                const SizedBox(height: 16),
                if (_todayAyet != null)
                  ContentCard(
                    type: 'ayet',
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
                    onSave: () =>
                        _contentRepo.saveContent('ayet', _todayAyet!.id),
                    onRemind: () {},
                  ),
                const SizedBox(height: 16),
                if (_todayHadis != null)
                  ContentCard(
                    type: 'hadis',
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
                    onSave: () =>
                        _contentRepo.saveContent('hadis', _todayHadis!.id),
                    onRemind: () {},
                  ),
                const SizedBox(height: 16),
                QuranTrackerCard(
                  isRead: _quranReadToday,
                  onRead: () async {
                    final today =
                        DateTime.now().toIso8601String().substring(0, 10);
                    await _userRepo.markQuranRead(today);
                    // Kuran okundu → saatlik hatırlatıcıları iptal et
                    await NotificationService().cancelHourlyQuranReminders();
                    final updatedUser = await _userRepo.getCurrentUser();
                    if (mounted) {
                      setState(() {
                        _quranReadToday = true;
                        _currentUser = updatedUser;
                      });
                    }
                  },
                ),
                ..._activeTasks.map((task) => Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: CustomTaskCard(
                        task: task,
                        onCompleted: () async {
                          await _taskRepo.markTaskCompleted(task.id);
                          final tasks = await _taskRepo.getActiveTasks();
                          if (mounted) setState(() => _activeTasks = tasks);
                        },
                      ),
                    )),
                const SizedBox(height: 16),
                if (_currentUser != null) StreakCard(user: _currentUser!),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── ALT NAV ───────────────────────────────────────────────────────────────

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2035) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha:0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabChanged,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.gold,
        unselectedItemColor: isDark ? Colors.white38 : AppColors.textLight,
        backgroundColor: Colors.transparent,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Ana Sayfa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.note_outlined),
            label: 'Notlarım',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            label: 'Topluluk',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
