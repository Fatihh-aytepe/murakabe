// lib/presentation/admin/user_detail_screen.dart
//
// Sahip panelinden açılır. Seçilen kullanıcıya ait tüm Firestore verilerini
// (ana doküman + tüm subcollection'lar) çekip sekmeli olarak gösterir.

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';

class UserDetailScreen extends StatefulWidget {
  final String uid;
  final String name;

  const UserDetailScreen({
    super.key,
    required this.uid,
    required this.name,
  });

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic> _userData = {};
  StreamSubscription<DocumentSnapshot>? _userSub;

  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> _tasks = [];
  List<Map<String, dynamic>> _badges = [];
  List<Map<String, dynamic>> _rewards = [];
  List<Map<String, dynamic>> _quranTracking = [];
  List<Map<String, dynamic>> _tahajjudTracking = [];
  List<Map<String, dynamic>> _saved = [];

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _listenUser();
    _loadSubcollections();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // ── Veri yükleme ─────────────────────────────────────────────────────────

  void _listenUser() {
    _userSub = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .snapshots()
        .listen((doc) {
      if (mounted) setState(() => _userData = doc.data() ?? {});
    });
  }

  Future<void> _loadSubcollections() async {
    try {
      final uid = widget.uid;
      final results = await Future.wait([
        _getSub(uid, 'notes'),
        _getSub(uid, 'reminders'),
        _getSub(uid, 'tasks'),
        _getSub(uid, 'badges'),
        _getSub(uid, 'rewards'),
        _getSub(uid, 'quranTracking'),
        _getSub(uid, 'tahajjudTracking'),
        _getSub(uid, 'saved'),
      ]);

      if (mounted) {
        setState(() {
          _notes = results[0];
          _reminders = results[1];
          _tasks = results[2];
          _badges = results[3];
          _rewards = results[4];
          _quranTracking = results[5];
          _tahajjudTracking = results[6];
          _saved = results[7];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<List<Map<String, dynamic>>> _getSub(String uid, String col) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(col)
          .get();
      return snap.docs.map((d) {
        final data = Map<String, dynamic>.from(d.data());
        data['_id'] = d.id;
        data.forEach((k, v) {
          if (v is Timestamp) data[k] = _fmtTs(v);
        });
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Yardımcı formatlar ───────────────────────────────────────────────────

  String _fmtTs(Timestamp ts) {
    final d = ts.toDate();
    return '${d.day.toString().padLeft(2, '0')}.'
        '${d.month.toString().padLeft(2, '0')}.'
        '${d.year}  '
        '${d.hour.toString().padLeft(2, '0')}:'
        '${d.minute.toString().padLeft(2, '0')}';
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso);
      return '${d.day.toString().padLeft(2, '0')}.'
          '${d.month.toString().padLeft(2, '0')}.'
          '${d.year}';
    } catch (_) {
      return iso;
    }
  }

  int get _tahajjudCount =>
      _tahajjudTracking.where((e) => e['isPrayed'] == true).length;

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_loading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
              )
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Veri yüklenemedi:\n$_error',
                      textAlign: TextAlign.center,
                      style:
                          GoogleFonts.notoSans(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ),
              )
            else ...[
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGenel(),
                    _buildKuran(),
                    _buildRozetler(),
                    _buildNotlar(),
                    _buildHatirlaticlar(),
                    _buildGorevler(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final name = _userData['nameSurname'] as String? ?? widget.name;
    final email = _userData['email'] as String? ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.2)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.gold, AppColors.turquoise],
              ),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.gold,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    style: GoogleFonts.notoSans(
                        color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),
          _refreshButton(),
        ],
      ),
    );
  }

  // ── TabBar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    const tabs = [
      Tab(text: 'Genel'),
      Tab(text: 'Kuran'),
      Tab(text: 'Rozetler'),
      Tab(text: 'Notlar'),
      Tab(text: 'Hatırlatıcı'),
      Tab(text: 'Görevler'),
    ];
    return Container(
      color: const Color(0xFF0F1624),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicatorColor: AppColors.gold,
        indicatorWeight: 2,
        labelColor: AppColors.gold,
        unselectedLabelColor: Colors.white38,
        labelStyle:
            GoogleFonts.notoSans(fontWeight: FontWeight.bold, fontSize: 12),
        tabs: tabs,
      ),
    );
  }

  // ── SEKMELER ──────────────────────────────────────────────────────────────

  // 1. GENEL
  Widget _buildGenel() {
    final phone = _userData['phone'] as String? ?? '-';
    final createdAtRaw = _userData['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? _fmtDate(createdAtRaw.toDate().toIso8601String())
        : _fmtDate(createdAtRaw?.toString());
    final streak = _userData['streakDays'] as int? ?? 0;
    final quranDays = _userData['quranReadDays'] as int? ?? 0;
    final missedRaw = _userData['missedQuranDays'];
    final missed = missedRaw is List ? missedRaw.length : 0;
    final tahajjudEnabled = _userData['tahajjudAlarmEnabled'];
    final tahajjudAktif = tahajjudEnabled == true || tahajjudEnabled == 1;
    final bio = _userData['bio'] as String? ?? '';
    final gender = _userData['gender'] as String? ?? '';
    final emailVerified = _userData['isEmailVerified'];
    final verified = emailVerified == true || emailVerified == 1;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Kişisel Bilgiler'),
          _infoRow(Icons.phone_outlined, 'Telefon', phone),
          _infoRow(Icons.calendar_today_outlined, 'Kayıt Tarihi', createdAt),
          _infoRow(
            Icons.verified_outlined,
            'E-posta Doğrulama',
            verified ? 'Doğrulandı ✓' : 'Doğrulanmadı',
            valueColor: verified ? Colors.greenAccent : Colors.redAccent,
          ),
          if (gender.isNotEmpty)
            _infoRow(Icons.person_outline, 'Cinsiyet', gender),
          if (bio.isNotEmpty) _infoRow(Icons.info_outline, 'Biyografi', bio),
          const SizedBox(height: 20),
          _sectionTitle('İstatistikler'),
          Row(
            children: [
              Expanded(
                  child: _statCard('🔥', '$streak', 'Seri (gün)',
                      streak >= 7 ? Colors.orange : AppColors.gold)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statCard(
                      '📖', '$quranDays', 'Kuran Günü', AppColors.turquoise)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _statCard(
                      '❌', '$missed', 'Atladığı Gün', Colors.redAccent)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statCard('🌙', '$_tahajjudCount',
                      'Teheccüd Gecesi', Colors.deepPurpleAccent)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _statCard(
                      '📝', '${_notes.length}', 'Not', AppColors.gold)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statCard(
                      '🏅', '${_badges.length}', 'Rozet', Colors.amberAccent)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _statCard('⏰', '${_reminders.length}', 'Hatırlatıcı',
                      Colors.blueAccent)),
              const SizedBox(width: 10),
              Expanded(
                  child: _statCard(
                      '✅', '${_tasks.length}', 'Görev', Colors.greenAccent)),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow(
            Icons.alarm_outlined,
            'Teheccüd Alarmı',
            tahajjudAktif ? 'Aktif' : 'Pasif',
            valueColor: tahajjudAktif ? Colors.greenAccent : Colors.white38,
          ),
          const SizedBox(height: 8),
          _infoRow(
              Icons.star_outline, 'Kazanılan Ödül', '${_rewards.length}'),
          _infoRow(Icons.bookmark_outline, 'Kaydedilen İçerik',
              '${_saved.length}'),
        ],
      ),
    );
  }

  // 2. KURAN
  Widget _buildKuran() {
    final readDays =
        _quranTracking.where((e) => e['isRead'] == true).toList();
    readDays.sort((a, b) {
      final aId = a['_id'] as String? ?? '';
      final bId = b['_id'] as String? ?? '';
      return bId.compareTo(aId);
    });

    final tahajjudDays =
        _tahajjudTracking.where((e) => e['isPrayed'] == true).toList();
    tahajjudDays.sort((a, b) {
      final aId = a['_id'] as String? ?? '';
      final bId = b['_id'] as String? ?? '';
      return bId.compareTo(aId);
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Kuran Okuma Günleri (${readDays.length})'),
          if (readDays.isEmpty)
            _emptyMsg('Henüz kuran okuma kaydı yok.')
          else
            ...readDays.map((e) {
              final date = _fmtDate(e['_id'] as String?);
              final readAt = e['readAt'] as String?;
              return _listTile(
                icon: Icons.menu_book_outlined,
                color: AppColors.turquoise,
                title: date,
                sub: readAt != null ? 'Okundu: ${_fmtDate(readAt)}' : 'Okundu',
              );
            }),
          const SizedBox(height: 20),
          _sectionTitle('Teheccüd Geceleri ($_tahajjudCount)'),
          if (tahajjudDays.isEmpty)
            _emptyMsg('Teheccüd kaydı yok.')
          else
            ...tahajjudDays.map((e) {
              final date = _fmtDate(e['_id'] as String?);
              return _listTile(
                icon: Icons.nightlight_outlined,
                color: Colors.deepPurpleAccent,
                title: date,
                sub: 'Teheccüd kılındı',
              );
            }),
        ],
      ),
    );
  }

  // 3. ROZETLER
  Widget _buildRozetler() {
    if (_badges.isEmpty) {
      return _emptyState(Icons.military_tech_outlined, 'Henüz rozet yok.');
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _badges.length,
      itemBuilder: (_, i) {
        final b = _badges[i];
        final badgeId = b['badgeId'] as String? ?? b['_id'] as String? ?? '-';
        final earnedAt = b['earnedAt'] as String?;
        final emoji = b['emoji'] as String? ?? '🏅';
        final title = b['title'] as String? ?? badgeId;
        return _listTile(
          icon: null,
          emoji: emoji,
          color: Colors.amberAccent,
          title: title,
          sub: earnedAt != null ? 'Kazanıldı: ${_fmtDate(earnedAt)}' : '',
        );
      },
    );
  }

  // 4. NOTLAR
  Widget _buildNotlar() {
    if (_notes.isEmpty) {
      return _emptyState(Icons.note_outlined, 'Henüz not yok.');
    }
    final sorted = List.of(_notes)
      ..sort((a, b) {
        final aDate = a['updatedAt'] as String? ?? '';
        final bDate = b['updatedAt'] as String? ?? '';
        return bDate.compareTo(aDate);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final n = sorted[i];
        final title = n['title'] as String? ?? 'Başlıksız';
        final content = n['content'] as String? ?? '';
        final updatedAt = _fmtDate(n['updatedAt'] as String?);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2035),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      color: AppColors.gold, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.notoSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    updatedAt,
                    style: GoogleFonts.notoSans(
                        color: Colors.white38, fontSize: 10),
                  ),
                ],
              ),
              if (content.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  content,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.notoSans(
                      color: Colors.white60, fontSize: 12, height: 1.5),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // 5. HATIRLATICIAR
  Widget _buildHatirlaticlar() {
    if (_reminders.isEmpty) {
      return _emptyState(Icons.alarm_outlined, 'Hatırlatıcı yok.');
    }
    final sorted = List.of(_reminders)
      ..sort((a, b) {
        final aT = a['reminderTime'] as String? ?? '';
        final bT = b['reminderTime'] as String? ?? '';
        return bT.compareTo(aT);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final r = sorted[i];
        final title = r['title'] as String? ?? 'Başlıksız';
        final content = r['content'] as String? ?? '';
        final time = _fmtDate(r['reminderTime'] as String?);
        final isActive = r['isActive'] as bool? ?? false;
        return _listTile(
          icon: Icons.alarm_outlined,
          color: isActive ? Colors.blueAccent : Colors.white38,
          title: title,
          sub: content.isNotEmpty ? '$content  •  $time' : time,
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isActive ? Colors.blueAccent : Colors.grey)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isActive ? 'Aktif' : 'Pasif',
              style: GoogleFonts.notoSans(
                color: isActive ? Colors.blueAccent : Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }

  // 6. GÖREVLER
  Widget _buildGorevler() {
    if (_tasks.isEmpty) {
      return _emptyState(Icons.task_alt_outlined, 'Görev yok.');
    }
    final sorted = List.of(_tasks)
      ..sort((a, b) {
        final aDate = a['createdAt'] as String? ?? '';
        final bDate = b['createdAt'] as String? ?? '';
        return bDate.compareTo(aDate);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final t = sorted[i];
        final title = t['title'] as String? ?? 'Görev';
        final desc = t['description'] as String? ?? '';
        final isActive = t['isActive'] as bool? ?? true;
        final notifTime = t['notificationTime'] as String?;
        final sub = [
          if (desc.isNotEmpty) desc,
          if (notifTime != null) '⏰ ${_fmtDate(notifTime)}',
        ].join('  •  ');
        return _listTile(
          icon: isActive
              ? Icons.radio_button_unchecked
              : Icons.check_circle_outline,
          color: isActive ? AppColors.gold : Colors.greenAccent,
          title: title,
          sub: sub,
        );
      },
    );
  }

  // ── Ortak widget'lar ──────────────────────────────────────────────────────

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.notoSans(
          color: Colors.white38,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2035),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 16),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.notoSans(color: Colors.white54, fontSize: 12),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: GoogleFonts.notoSans(
                color: valueColor ?? Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String emoji, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.playfairDisplay(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _listTile({
    IconData? icon,
    String? emoji,
    required Color color,
    required String title,
    String sub = '',
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2035),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Center(
              child: emoji != null
                  ? Text(emoji, style: const TextStyle(fontSize: 16))
                  : Icon(icon, color: color, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.notoSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    style: GoogleFonts.notoSans(
                        color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _refreshButton() {
    return IconButton(
      icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
      tooltip: 'Yenile',
      onPressed: () {
        setState(() => _loading = true);
        _loadSubcollections();
      },
    );
  }

  Widget _emptyState(IconData icon, String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 52, color: Colors.white12),
          const SizedBox(height: 12),
          Text(msg,
              style:
                  GoogleFonts.notoSans(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _emptyMsg(String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(msg,
          style: GoogleFonts.notoSans(color: Colors.white38, fontSize: 12)),
    );
  }
}
