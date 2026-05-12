import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/role_service.dart';
import '../../../data/local/local_storage.dart';
import 'community_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _roleService = RoleService();
  late TabController _tabController;
  String? _communityId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCommunity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCommunity() async {
    _roleService.getAdminCommunities().listen((snap) {
      if (snap.docs.isNotEmpty && mounted) {
        setState(() {
          _communityId = snap.docs.first.id;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  // ── Dialoglar ─────────────────────────────────────────────────────────────

  void _showCreateCommunityDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        title: Text('Topluluk Kur',
            style: GoogleFonts.playfairDisplay(
                color: AppColors.gold, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dialogField(nameCtrl, 'Topluluk Adı', Icons.group),
            const SizedBox(height: 12),
            _dialogField(descCtrl, 'Açıklama', Icons.description, maxLines: 3),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal',
                style: GoogleFonts.notoSans(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              try {
                final id = await _roleService.createCommunity(
                  name: nameCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                );
                setState(() => _communityId = id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Topluluk oluşturuldu'),
                    backgroundColor: Color(0xFF2E7D32),
                  ));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              }
            },
            child: Text('Oluştur',
                style: GoogleFonts.notoSans(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showAssignTaskDialog() {
    if (_communityId == null) return;
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    DateTime? deadline;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF1A2035),
          title: Text('Görev Ata',
              style: GoogleFonts.playfairDisplay(
                  color: AppColors.gold, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(titleCtrl, 'Görev Başlığı', Icons.task_alt),
              const SizedBox(height: 12),
              _dialogField(descCtrl, 'Açıklama', Icons.description,
                  maxLines: 3),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setDlg(() => deadline = picked);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: AppColors.gold, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        deadline != null
                            ? '${deadline!.day}.${deadline!.month}.${deadline!.year}'
                            : 'Son Tarih Seç',
                        style: GoogleFonts.notoSans(
                          color:
                              deadline != null ? Colors.white : Colors.white38,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('İptal',
                  style: GoogleFonts.notoSans(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || deadline == null) return;
                Navigator.pop(ctx);
                await _roleService.assignTask(
                  communityId: _communityId!,
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim(),
                  deadline: deadline!,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Görev atandı')));
                }
              },
              child:
                  Text('Ata', style: GoogleFonts.notoSans(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnnouncementDialog({bool isWarning = false}) {
    if (_communityId == null) return;
    final msgCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        title: Text(
          isWarning ? '⚠️ Uyarı Gönder' : '📢 Duyuru Gönder',
          style: GoogleFonts.playfairDisplay(
              color: isWarning ? Colors.orange : AppColors.gold,
              fontWeight: FontWeight.bold),
        ),
        content: _dialogField(msgCtrl, 'Mesajınızı yazın...', Icons.message,
            maxLines: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal',
                style: GoogleFonts.notoSans(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isWarning ? Colors.orange : AppColors.gold,
            ),
            onPressed: () async {
              if (msgCtrl.text.trim().isEmpty) return;
              Navigator.pop(context);
              await _roleService.sendAnnouncement(
                communityId: _communityId!,
                message: msgCtrl.text.trim(),
                isWarning: isWarning,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        isWarning ? 'Uyarı gönderildi' : 'Duyuru gönderildi')));
              }
            },
            child: Text('Gönder',
                style: GoogleFonts.notoSans(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: Icon(icon, color: AppColors.gold, size: 18),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.white24),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.gold),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            // Başlık
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Paneli',
                          style: GoogleFonts.playfairDisplay(
                            color: AppColors.gold,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Topluluk yönetimi',
                          style: GoogleFonts.notoSans(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  // Kanala git butonu
                  if (_communityId != null)
                    IconButton(
                      icon: const Icon(Icons.forum_outlined,
                          color: AppColors.turquoise),
                      tooltip: 'Topluluk Kanalı',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CommunityScreen(communityId: _communityId!),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: AppColors.gold,
              unselectedLabelColor: Colors.white38,
              indicatorColor: AppColors.gold,
              labelStyle: GoogleFonts.notoSans(
                  fontWeight: FontWeight.bold, fontSize: 12),
              tabs: const [
                Tab(text: 'Yönetim'),
                Tab(text: 'Üyeler'),
                Tab(text: 'Görevler'),
              ],
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold))
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildManagementTab(),
                        _buildMembersTab(),
                        _buildTasksTab(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Yönetim sekmesi ───────────────────────────────────────────────────────

  Widget _buildManagementTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_communityId == null)
            _buildActionCard(
              icon: Icons.group_add,
              title: 'Topluluk Kur',
              subtitle: 'Üyeleri davet et, görev at',
              color: AppColors.turquoise,
              onTap: _showCreateCommunityDialog,
            )
          else ...[
            // Topluluk bilgi kartı
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .doc(_communityId)
                  .snapshots(),
              builder: (_, snap) {
                final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                final name = data['name'] as String? ?? 'Topluluk';
                final memberCount = data['memberCount'] as int? ?? 0;
                final inviteCode = data['inviteCode'] as String? ?? '';
                return Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.group, color: AppColors.gold),
                          const SizedBox(width: 8),
                          Text(name,
                              style: GoogleFonts.playfairDisplay(
                                  color: AppColors.gold,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('$memberCount üye',
                              style: GoogleFonts.notoSans(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: inviteCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Davet kodu kopyalandı')),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.copy,
                                  color: AppColors.turquoise, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Davet Kodu: $inviteCode',
                                style: GoogleFonts.notoSans(
                                  color: AppColors.turquoiseLight,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            _buildActionCard(
              icon: Icons.task_alt,
              title: 'Görev Ata',
              subtitle: 'Üyelere görev ver, son tarih belirle',
              color: AppColors.gold,
              onTap: _showAssignTaskDialog,
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              icon: Icons.campaign,
              title: 'Duyuru Gönder',
              subtitle: 'Tüm üyelere mesaj at',
              color: AppColors.turquoise,
              onTap: () => _showAnnouncementDialog(),
            ),
            const SizedBox(height: 12),
            _buildActionCard(
              icon: Icons.warning_amber,
              title: 'Uyarı Gönder',
              subtitle: 'Üyelere uyarı mesajı gönder',
              color: Colors.orange,
              onTap: () => _showAnnouncementDialog(isWarning: true),
            ),
          ],
        ],
      ),
    );
  }

  // ── Üyeler sekmesi ────────────────────────────────────────────────────────

  Widget _buildMembersTab() {
    if (_communityId == null) {
      return Center(
        child: Text('Önce topluluk oluşturun',
            style: GoogleFonts.notoSans(color: Colors.white38)),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(_communityId)
          .collection('members')
          .snapshots(),
      builder: (_, membersSnap) {
        final members = membersSnap.data?.docs ?? [];
        if (members.isEmpty) {
          return Center(
            child: Text('Henüz üye yok',
                style: GoogleFonts.notoSans(color: Colors.white38)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (_, i) {
            final memberData = members[i].data() as Map<String, dynamic>;
            final uid = memberData['uid'] as String? ?? '';
            final role = memberData['role'] as String? ?? 'member';

            return FutureBuilder<DocumentSnapshot>(
              future:
                  FirebaseFirestore.instance.collection('users').doc(uid).get(),
              builder: (_, userSnap) {
                final userData =
                    userSnap.data?.data() as Map<String, dynamic>? ?? {};
                final name = userData['nameSurname'] as String? ?? 'Kullanıcı';
                final quranDays = userData['quranReadDays'] as int? ?? 0;
                final streak = userData['streakDays'] as int? ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2035),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: role == 'admin'
                          ? AppColors.gold.withOpacity(0.4)
                          : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: role == 'admin'
                                ? [AppColors.gold, const Color(0xFFB8860B)]
                                : [
                                    AppColors.turquoise,
                                    const Color(0xFF207080)
                                  ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(name,
                                    style: GoogleFonts.notoSans(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                                if (role == 'admin') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.gold.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text('Admin',
                                        style: GoogleFonts.notoSans(
                                            color: AppColors.gold,
                                            fontSize: 10)),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Text('📖',
                                    style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 3),
                                Text('$quranDays gün',
                                    style: GoogleFonts.notoSans(
                                        color: Colors.white54, fontSize: 11)),
                                const SizedBox(width: 10),
                                const Text('🔥',
                                    style: TextStyle(fontSize: 11)),
                                const SizedBox(width: 3),
                                Text('$streak seri',
                                    style: GoogleFonts.notoSans(
                                        color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Görevler sekmesi (tamamlama yüzdesi) ──────────────────────────────────

  Widget _buildTasksTab() {
    if (_communityId == null) {
      return Center(
        child: Text('Önce topluluk oluşturun',
            style: GoogleFonts.notoSans(color: Colors.white38)),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(_communityId)
          .collection('tasks')
          .orderBy('deadline')
          .snapshots(),
      builder: (_, taskSnap) {
        final tasks = taskSnap.data?.docs ?? [];
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.task_alt, color: Colors.white24, size: 48),
                const SizedBox(height: 12),
                Text('Henüz görev atanmadı',
                    style: GoogleFonts.notoSans(color: Colors.white38)),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _showAssignTaskDialog,
                  child: Text('Görev Ata',
                      style: GoogleFonts.notoSans(color: Colors.black)),
                ),
              ],
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('communities')
              .doc(_communityId)
              .collection('members')
              .snapshots(),
          builder: (_, memberSnap) {
            final totalMembers =
                (memberSnap.data?.docs.length ?? 1).clamp(1, 9999);

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: tasks.length,
              itemBuilder: (_, i) {
                final data = tasks[i].data() as Map<String, dynamic>;
                final taskId = tasks[i].id;
                final title = data['title'] as String? ?? '';
                final desc = data['description'] as String? ?? '';
                final deadline = (data['deadline'] as Timestamp?)?.toDate();
                final completions = Map<String, dynamic>.from(
                    data['completions'] as Map? ?? {});
                final completedCount = completions.length;
                final percent = completedCount / totalMembers;
                final isOverdue =
                    deadline != null && deadline.isBefore(DateTime.now());

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A2035),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isOverdue
                          ? Colors.red.withOpacity(0.3)
                          : AppColors.gold.withOpacity(0.15),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: GoogleFonts.notoSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                          // Görevi sil
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 18),
                            onPressed: () async {
                              await FirebaseFirestore.instance
                                  .collection('communities')
                                  .doc(_communityId)
                                  .collection('tasks')
                                  .doc(taskId)
                                  .delete();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      if (desc.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(desc,
                            style: GoogleFonts.notoSans(
                                color: Colors.white54, fontSize: 12)),
                      ],
                      if (deadline != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                size: 12,
                                color: isOverdue ? Colors.red : Colors.white38),
                            const SizedBox(width: 4),
                            Text(
                              'Son: ${deadline.day}.${deadline.month}.${deadline.year}',
                              style: GoogleFonts.notoSans(
                                color: isOverdue ? Colors.red : Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Tamamlama yüzdesi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$completedCount / $totalMembers tamamladı',
                            style: GoogleFonts.notoSans(
                                color: Colors.white70, fontSize: 12),
                          ),
                          Text(
                            '%${(percent * 100).toStringAsFixed(0)}',
                            style: GoogleFonts.notoSans(
                              color: percent >= 0.8
                                  ? const Color(0xFF4CAF50)
                                  : percent >= 0.5
                                      ? AppColors.gold
                                      : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: percent.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation(
                            percent >= 0.8
                                ? const Color(0xFF4CAF50)
                                : percent >= 0.5
                                    ? AppColors.gold
                                    : Colors.red,
                          ),
                        ),
                      ),

                      // Tamamlayan üyeler
                      if (completions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text('Tamamlayanlar:',
                            style: GoogleFonts.notoSans(
                                color: Colors.white38, fontSize: 11)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: completions.keys.map((uid) {
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(uid)
                                  .get(),
                              builder: (_, snap) {
                                final name = (snap.data?.data() as Map<String,
                                        dynamic>?)?['nameSurname'] as String? ??
                                    '...';
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2E7D32)
                                        .withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFF4CAF50)
                                            .withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    '✓ $name',
                                    style: GoogleFonts.notoSans(
                                        color: const Color(0xFF4CAF50),
                                        fontSize: 11),
                                  ),
                                );
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2035),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(subtitle,
                      style: GoogleFonts.notoSans(
                          color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}
