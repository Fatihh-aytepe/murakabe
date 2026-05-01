import 'package:flutter/material.dart';
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
import '../esma/esma_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../notes/notes_screen.dart';
import '../reminders/reminders_screen.dart';
import 'widgets/content_card.dart';
import 'widgets/islamic_header.dart';
import 'widgets/quran_tracker_card.dart';
import 'widgets/prayer_times_widget.dart';
import 'widgets/custom_task_card.dart';
import '../../data/models/user_model.dart';
import 'widgets/streak_card.dart';
import '../ayet/ayet_detail_screen.dart';
import '../hadis/hadis_detail_screen.dart';
import '../rewards/murakabe_hosgeldin_screen.dart';
import '../rewards/tahajjud_odul_screen.dart';
import '../rewards/tebrik_karti_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _contentRepo = ContentRepository();
  final _userRepo = UserRepository();
  final _taskRepo = CustomTaskRepository();

  // GlobalKey'ler ile alt ekranları dışarıdan yenileyebiliyoruz
  final _profileKey = GlobalKey<ProfileScreenState>();
  final _notesKey = GlobalKey<NotesScreenState>();

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
    final rewardService = RewardService();

    if (rewardService.shouldShowWelcome) {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MurakabeHosgeldinScreen(
          onDone: () => Navigator.of(context).pop(),
        ),
      ));
      return;
    }

    if (_currentUser != null) {
      final streakReward =
          await rewardService.checkStreakReward(_currentUser!.streakDays);
      if (streakReward != null && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TebrikKartiScreen(
            type: streakReward.type,
            title: streakReward.title,
            message: streakReward.message,
            autoSave: false,
          ),
        ));
      }
    }

    final showTahajjud = await rewardService.checkTahajjudReward();
    if (showTahajjud && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => const TahajjudOdulScreen(),
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

        // Bildirimleri yalnızca bir kez zamanla (uygulama açıldığında)
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

    // Aktif görevlerin bildirimlerini zamanla
    final tasks = await _taskRepo.getActiveTasks();
    for (final task in tasks) {
      if (task.notificationTime.isNotEmpty) {
        final parts = task.notificationTime.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]) ?? 9;
          final minute = int.tryParse(parts[1]) ?? 0;
          final id = (task.id.hashCode.abs() % 10000) + 5000;
          await NotificationService().scheduleTaskNotification(
            id,
            '${task.emoji} ${task.title}',
            task.description.isNotEmpty
                ? task.description
                : '${task.title} göreviniz var!',
            hour,
            minute,
          );
        }
      }
    }
  }

  Future<void> _refreshContent() async {
    setState(() => _isLoading = true);
    await _loadContent();
  }

  void _onTabChanged(int i) {
    setState(() => _selectedIndex = i);
    // Sekme değişince ilgili ekranı yenile
    if (i == 1) _notesKey.currentState?.reload();
    if (i == 3) _profileKey.currentState?.reload();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildHomePage(),
          NotesScreen(key: _notesKey),
          const RemindersScreen(),
          ProfileScreen(
            key: _profileKey,
            onTasksChanged: _refreshContent,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

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
          SliverToBoxAdapter(child: const IslamicHeader()),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const PrayerTimesWidget(),
                const SizedBox(height: 16),
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
                        builder: (_) =>
                            HadisDetailScreen(hadis: _todayHadis!),
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

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2035) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.15),
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
            icon: Icon(Icons.alarm_outlined),
            label: 'Hatırlatıcı',
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
