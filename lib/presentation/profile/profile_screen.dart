import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/alarm_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/theme_service.dart';
import '../../data/local/local_storage.dart';
import '../../data/models/esma_model.dart';
import '../../data/models/hadis_model.dart';
import '../../data/models/ayet_model.dart';
import '../../data/models/user_model.dart';
import '../../data/models/reward_model.dart';
import '../../data/models/custom_task_model.dart';
import '../../data/repositories/content_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../data/repositories/custom_task_repository.dart';
import '../rewards/tebrik_karti_screen.dart';
import '../esma/esma_detail_screen.dart';
import '../ayet/ayet_detail_screen.dart';
import '../hadis/hadis_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final VoidCallback? onTasksChanged;
  const ProfileScreen({super.key, this.onTasksChanged});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _userRepo = UserRepository();
  final _contentRepo = ContentRepository();
  final _alarmService = AlarmService();
  final _rewardRepo = RewardRepository();
  final _taskRepo = CustomTaskRepository();
  final _imagePicker = ImagePicker();

  UserModel? _user;
  List<EsmaModel> _savedEsmas = [];
  List<HadisModel> _savedHadises = [];
  List<AyetModel> _savedAyets = [];
  List<RewardModel> _rewards = [];
  List<CustomTaskModel> _customTasks = [];
  bool _tahajjudEnabled = false;
  List<TimeOfDay> _tahajjudTimes = [const TimeOfDay(hour: 2, minute: 0)];
  String? _profilePhotoPath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _loadData();
  }

  // HomeScreen GlobalKey üzerinden çağrılır
  void reload() => _loadData();

  Future<void> _loadData() async {
    final user = await _userRepo.getCurrentUser();
    final esmas = await _contentRepo.getSavedEsmas();
    final hadises = await _contentRepo.getSavedHadises();
    final ayets = await _contentRepo.getSavedAyets();
    final rewards = await _rewardRepo.getAllRewards();
    final tasks = await _taskRepo.getAllTasks();
    if (mounted) {
      setState(() {
        _user = user;
        _savedEsmas = esmas;
        _savedHadises = hadises;
        _savedAyets = ayets;
        _rewards = rewards;
        _customTasks = tasks;
        _tahajjudEnabled = user?.tahajjudAlarmEnabled ?? false;
        _profilePhotoPath = LocalStorage().profilePhotoPath;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final tabBg = isDark ? const Color(0xFF0A0E1A) : bgColor;

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(child: _buildProfileHeader()),
          SliverToBoxAdapter(child: _buildStatsRow(isDark)),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppColors.gold,
                unselectedLabelColor:
                    isDark ? Colors.white38 : AppColors.textLight,
                indicatorColor: AppColors.gold,
                indicatorWeight: 2,
                isScrollable: true,
                labelStyle: GoogleFonts.notoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
                tabs: const [
                  Tab(text: 'Esmalar'),
                  Tab(text: 'Ayetler'),
                  Tab(text: 'Hadisler'),
                  Tab(text: 'Görevler'),
                  Tab(text: 'Teheccüd'),
                  Tab(text: 'Heybem'),
                ],
              ),
              tabBg,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildEsmaList(),
            _buildAyetList(),
            _buildHadisList(),
            _buildCustomTasksSection(),
            _buildTahajjudSection(),
            _buildHeybemList(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final missed = _user?.missedQuranDays ?? [];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _showPhotoOptions,
            child: Stack(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.gold, AppColors.turquoise],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: _profilePhotoPath != null &&
                          _profilePhotoPath!.isNotEmpty
                      ? ClipOval(
                          child: Image.file(
                            File(_profilePhotoPath!),
                            fit: BoxFit.cover,
                            width: 80,
                            height: 80,
                          ),
                        )
                      : Center(
                          child: Text(
                            _user?.nameSurname.isNotEmpty == true
                                ? _user!.nameSurname[0].toUpperCase()
                                : '?',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 32,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _user?.nameSurname ?? 'Kullanıcı',
            style: GoogleFonts.playfairDisplay(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _user?.email ?? '',
            style: GoogleFonts.notoSans(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          // Tema toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.light_mode, color: Colors.white38, size: 16),
              const SizedBox(width: 8),
              Consumer<ThemeService>(
                builder: (_, theme, __) => Switch(
                  value: theme.isDark,
                  onChanged: (_) => theme.toggleTheme(),
                  activeColor: AppColors.gold,
                  activeTrackColor: AppColors.gold.withValues(alpha: 0.3),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.dark_mode, color: Colors.white38, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          if (missed.isEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.green.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.green, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'Tüm günler tamamlandı',
                    style:
                        GoogleFonts.notoSans(color: Colors.green, fontSize: 13),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.red, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${missed.length} gün eksik Kuran okuması',
                        style: GoogleFonts.notoSans(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: missed
                        .take(7)
                        .map(
                          (d) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              d,
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 11),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1A2035) : Colors.white;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildStatItem('${_user?.quranReadDays ?? 0}', 'Kuran\nGünü',
                Icons.menu_book, AppColors.turquoise, isDark),
            _buildStatDivider(),
            _buildStatItem('${_savedEsmas.length}', 'Kaydedilen\nEsma',
                Icons.auto_awesome, AppColors.gold, isDark),
            _buildStatDivider(),
            _buildStatItem('${_savedAyets.length}', 'Kaydedilen\nAyet',
                Icons.menu_book_outlined, const Color(0xFF40B4C8), isDark),
            _buildStatDivider(),
            _buildStatItem('${_savedHadises.length}', 'Kaydedilen\nHadis',
                Icons.format_quote, const Color(0xFF6B4226), isDark),
            _buildStatDivider(),
            _buildStatItem('${_rewards.length}', 'Heybem',
                Icons.favorite_outline, Colors.purple, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String value, String label, IconData icon, Color color, bool isDark) {
    final textColor = isDark ? Colors.white70 : AppColors.textSecondary;
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(fontSize: 10, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() => Container(
        height: 40,
        width: 1,
        color: AppColors.textLight.withValues(alpha: 0.3),
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );

  // ── Kaydedilen listeler ──────────────────────────────────────────────────

  Widget _buildEsmaList() {
    if (_savedEsmas.isEmpty) return _buildEmptyState('Henüz esma kaydedilmedi');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedEsmas.length,
      itemBuilder: (_, i) {
        final esma = _savedEsmas[i];
        return _buildSavedCard(
          title: esma.arabic,
          subtitle: esma.meaning,
          tag: esma.turkish,
          color: AppColors.gold,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => EsmaDetailScreen(esma: esma)),
          ),
        );
      },
    );
  }

  Widget _buildAyetList() {
    if (_savedAyets.isEmpty) return _buildEmptyState('Henüz ayet kaydedilmedi');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedAyets.length,
      itemBuilder: (_, i) {
        final ayet = _savedAyets[i];
        return _buildSavedCard(
          title: ayet.arabic,
          subtitle: ayet.turkish,
          tag: '${ayet.surah} - ${ayet.ayahNumber}. Ayet',
          color: AppColors.turquoise,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AyetDetailScreen(ayet: ayet)),
          ),
        );
      },
    );
  }

  Widget _buildHadisList() {
    if (_savedHadises.isEmpty)
      return _buildEmptyState('Henüz hadis kaydedilmedi');
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedHadises.length,
      itemBuilder: (_, i) {
        final hadis = _savedHadises[i];
        return _buildSavedCard(
          title: hadis.source,
          subtitle: hadis.text,
          tag: 'Hadis',
          color: const Color(0xFF6B4226),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => HadisDetailScreen(hadis: hadis)),
          ),
        );
      },
    );
  }

  Widget _buildSavedCard({
    required String title,
    required String subtitle,
    required String tag,
    required Color color,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A2035) : Colors.white;
    final subColor = isDark ? Colors.white54 : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                        color: color,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const Spacer(),
                if (onTap != null)
                  Icon(Icons.arrow_forward_ios, color: color, size: 14),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.amiri(
                  fontSize: 18, color: color, fontWeight: FontWeight.bold),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSans(
                  fontSize: 12, color: subColor, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Özel Görevler ────────────────────────────────────────────────────────

  Widget _buildCustomTasksSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'Günlük Görevlerim',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showAddTaskDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add, color: AppColors.gold, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Görev Ekle',
                        style: GoogleFonts.notoSans(
                            color: AppColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _customTasks.isEmpty
              ? _buildEmptyState(
                  'Henüz görev yok\n"Görev Ekle" ile yeni bir günlük görev ekle')
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _customTasks.length,
                  itemBuilder: (_, i) => _buildTaskTile(_customTasks[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildTaskTile(CustomTaskModel task) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A2035) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Text(task.emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: GoogleFonts.notoSans(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    decoration: task.isActive
                        ? null
                        : TextDecoration.lineThrough,
                  ),
                ),
                if (task.notificationTime.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.alarm_outlined,
                          size: 12, color: AppColors.turquoise),
                      const SizedBox(width: 4),
                      Text(
                        task.notificationTime,
                        style: GoogleFonts.notoSans(
                            fontSize: 11, color: AppColors.turquoise),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Switch(
            value: task.isActive,
            onChanged: (v) async {
              await _taskRepo.updateTask(task.copyWith(isActive: v));
              await _loadData();
              widget.onTasksChanged?.call();
            },
            activeColor: AppColors.gold,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _confirmDeleteTask(task),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTaskDialog({CustomTaskModel? existing}) async {
    final titleCtrl =
        TextEditingController(text: existing?.title ?? '');
    final descCtrl =
        TextEditingController(text: existing?.description ?? '');
    String emoji = existing?.emoji ?? '📝';
    String notifTime = existing?.notificationTime ?? '';

    final emojis = [
      '📖', '🤲', '🕌', '⭐', '💪', '🏃', '📝', '🎯', '🌙', '☀️',
      '🌿', '❤️', '✨', '🔥', '📿', '🕋'
    ];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark =
              Theme.of(context).brightness == Brightness.dark;
          final bgColor =
              isDark ? const Color(0xFF1A2035) : Colors.white;
          final textColor =
              isDark ? Colors.white : AppColors.textPrimary;

          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      existing != null ? 'Görevi Düzenle' : 'Yeni Görev',
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Emoji seçici
                    Text('İkon Seç',
                        style: GoogleFonts.notoSans(
                            color: textColor,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: emojis
                          .map(
                            (e) => GestureDetector(
                              onTap: () =>
                                  setModalState(() => emoji = e),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: emoji == e
                                      ? AppColors.gold
                                          .withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(8),
                                  border: Border.all(
                                    color: emoji == e
                                        ? AppColors.gold
                                        : Colors.grey
                                            .withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Center(
                                    child: Text(e,
                                        style: const TextStyle(
                                            fontSize: 20))),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleCtrl,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Görev Adı *',
                        labelStyle:
                            TextStyle(color: textColor.withValues(alpha: 0.7)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: AppColors.gold),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        labelText: 'Açıklama (isteğe bağlı)',
                        labelStyle:
                            TextStyle(color: textColor.withValues(alpha: 0.7)),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide:
                              const BorderSide(color: AppColors.gold),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Bildirim zamanı
                    GestureDetector(
                      onTap: () async {
                        final parts = notifTime.split(':');
                        final init = parts.length == 2
                            ? TimeOfDay(
                                hour: int.tryParse(parts[0]) ?? 9,
                                minute: int.tryParse(parts[1]) ?? 0)
                            : const TimeOfDay(hour: 9, minute: 0);
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: init,
                          builder: (c, child) => Theme(
                            data: ThemeData.dark().copyWith(
                              colorScheme: const ColorScheme.dark(
                                  primary: AppColors.gold),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) {
                          setModalState(() {
                            notifTime =
                                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: notifTime.isNotEmpty
                                  ? AppColors.gold
                                  : Colors.grey.withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.alarm_outlined,
                                color: notifTime.isNotEmpty
                                    ? AppColors.gold
                                    : textColor.withValues(alpha: 0.5)),
                            const SizedBox(width: 10),
                            Text(
                              notifTime.isNotEmpty
                                  ? 'Bildirim: $notifTime'
                                  : 'Günlük bildirim zamanı seç',
                              style: GoogleFonts.notoSans(
                                color: notifTime.isNotEmpty
                                    ? AppColors.gold
                                    : textColor.withValues(alpha: 0.5),
                              ),
                            ),
                            const Spacer(),
                            if (notifTime.isNotEmpty)
                              GestureDetector(
                                onTap: () =>
                                    setModalState(() => notifTime = ''),
                                child: Icon(Icons.close,
                                    size: 16,
                                    color: textColor.withValues(alpha: 0.5)),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final t = titleCtrl.text.trim();
                          if (t.isEmpty) return;
                          Navigator.pop(ctx);
                          final taskId = existing?.id ?? const Uuid().v4();
                          if (existing != null) {
                            await _taskRepo.updateTask(
                              existing.copyWith(
                                title: t,
                                description: descCtrl.text.trim(),
                                emoji: emoji,
                                notificationTime: notifTime,
                              ),
                            );
                          } else {
                            await _taskRepo.addTask(
                              CustomTaskModel(
                                id: taskId,
                                title: t,
                                description: descCtrl.text.trim(),
                                emoji: emoji,
                                notificationTime: notifTime,
                                createdAt: DateTime.now(),
                              ),
                            );
                          }
                          // Bildirim zamanlaması
                          final notifId =
                              (taskId.hashCode.abs() % 10000) + 5000;
                          if (notifTime.isNotEmpty) {
                            final parts = notifTime.split(':');
                            if (parts.length == 2) {
                              final h = int.tryParse(parts[0]) ?? 9;
                              final m = int.tryParse(parts[1]) ?? 0;
                              await NotificationService()
                                  .scheduleTaskNotification(
                                notifId,
                                '$emoji $t',
                                descCtrl.text.trim().isNotEmpty
                                    ? descCtrl.text.trim()
                                    : '$t göreviniz var!',
                                h,
                                m,
                              );
                            }
                          } else {
                            await NotificationService()
                                .cancelTaskNotification(notifId);
                          }
                          await _loadData();
                          widget.onTasksChanged?.call();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          existing != null ? 'Güncelle' : 'Görev Ekle',
                          style: GoogleFonts.notoSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmDeleteTask(CustomTaskModel task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Görevi Sil'),
        content:
            Text('"${task.title}" görevini silmek istiyor musunuz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _taskRepo.deleteTask(task.id);
      await _loadData();
      widget.onTasksChanged?.call();
    }
  }

  // ── Heybem ───────────────────────────────────────────────────────────────

  Widget _buildHeybemList() {
    if (_rewards.isEmpty) {
      return _buildEmptyState(
          'Henüz heybenizde bir şey yok\nTeheccüd ve Kuran ödülleriniz burada görünür');
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _rewards.length,
      itemBuilder: (_, i) {
        final reward = _rewards[i];
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TebrikKartiScreen(
                type: reward.type,
                title: reward.title,
                message: reward.message,
                autoSave: false,
              ),
            ),
          ),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
              ),
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      reward.type == 'tahajjud' ? '🌙' : '📖',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward.title,
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.gold,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reward.message.length > 60
                            ? '${reward.message.substring(0, 60)}...'
                            : reward.message,
                        style: GoogleFonts.notoSans(
                            color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatRewardDate(reward.earnedAt),
                        style: GoogleFonts.notoSans(
                            color: AppColors.turquoiseLight, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: AppColors.gold, size: 18),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatRewardDate(DateTime dt) {
    const months = [
      '', 'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
      'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  // ── Teheccüd ─────────────────────────────────────────────────────────────

  Widget _buildTahajjudSection() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
              ),
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.nightlight_round,
                      color: AppColors.gold, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Teheccüd Alarmı',
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Gece namazı için hatırlatıcı',
                        style: GoogleFonts.notoSans(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _tahajjudEnabled,
                  onChanged: _toggleTahajjud,
                  activeColor: AppColors.gold,
                ),
              ],
            ),
          ),
          if (_tahajjudEnabled) ...[
            const SizedBox(height: 16),
            ..._tahajjudTimes.asMap().entries
                .map((e) => _buildAlarmTile(e.value, e.key)),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _addAlarm,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, color: AppColors.gold),
                    const SizedBox(width: 8),
                    Text('Alarm Ekle',
                        style: GoogleFonts.notoSans(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.turquoise.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.turquoise.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: AppColors.turquoise, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Her Perşembe gecesi saat 02:00\'de otomatik teheccüd daveti bildirimi gönderilir.',
                      style: GoogleFonts.notoSans(
                        color: AppColors.turquoiseDark,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!_tahajjudEnabled) ...[
            const SizedBox(height: 24),
            _buildEmptyState(
                'Teheccüd alarmını açarak\ngece namazını kaçırma'),
          ],
        ],
      ),
    );
  }

  Widget _buildAlarmTile(TimeOfDay time, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A2035) : Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.08),
              blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.alarm, color: AppColors.gold, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.playfairDisplay(
                fontSize: 22,
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.textLight, size: 20),
            onPressed: () => _editAlarm(index),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _removeAlarm(index),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined,
              size: 60,
              color: AppColors.textLight.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
                color: AppColors.textLight, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTahajjud(bool value) async {
    setState(() => _tahajjudEnabled = value);
    final user = await _userRepo.getCurrentUser();
    if (user != null) {
      await _userRepo.updateUser(user.copyWith(tahajjudAlarmEnabled: value));
    }
    if (value) {
      for (final t in _tahajjudTimes) {
        final now = DateTime.now();
        final alarmDt =
            DateTime(now.year, now.month, now.day, t.hour, t.minute);
        await _alarmService.setTahajjudAlarm(alarmDt);
      }
      await NotificationService().scheduleThursdayTahajjud();
    } else {
      await _alarmService.cancelAllAlarms();
    }
  }

  Future<void> _addAlarm() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 2, minute: 0),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme:
                const ColorScheme.dark(primary: AppColors.gold)),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _tahajjudTimes.add(picked));
      final now = DateTime.now();
      final alarmDt = DateTime(
          now.year, now.month, now.day, picked.hour, picked.minute);
      await _alarmService.setTahajjudAlarm(alarmDt);
    }
  }

  Future<void> _editAlarm(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _tahajjudTimes[index],
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme:
                const ColorScheme.dark(primary: AppColors.gold)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _tahajjudTimes[index] = picked);
  }

  void _removeAlarm(int index) {
    setState(() => _tahajjudTimes.removeAt(index));
  }

  Future<void> _showPhotoOptions() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A2035),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Profil Fotoğrafı',
              style: GoogleFonts.playfairDisplay(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading:
                  const Icon(Icons.camera_alt, color: AppColors.gold),
              title: Text('Kamera',
                  style: GoogleFonts.notoSans(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: AppColors.turquoise),
              title: Text('Galeri',
                  style: GoogleFonts.notoSans(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_profilePhotoPath != null && _profilePhotoPath!.isNotEmpty)
              ListTile(
                leading:
                    const Icon(Icons.delete_outline, color: Colors.red),
                title: Text('Fotoğrafı Kaldır',
                    style: GoogleFonts.notoSans(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  await LocalStorage().setProfilePhotoPath('');
                  if (mounted) setState(() => _profilePhotoPath = null);
                },
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked != null) {
        await LocalStorage().setProfilePhotoPath(picked.path);
        if (mounted) setState(() => _profilePhotoPath = picked.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fotoğraf seçilemedi')));
      }
    }
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color bgColor;
  const _TabBarDelegate(this.tabBar, this.bgColor);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      Container(color: bgColor, child: tabBar);

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant _TabBarDelegate old) =>
      old.bgColor != bgColor;
}
