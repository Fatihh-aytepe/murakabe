import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/role_service.dart';
import '../../../data/local/local_storage.dart';

class CommunityScreen extends StatefulWidget {
  final String communityId;
  const CommunityScreen({super.key, required this.communityId});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focusNode = FocusNode();
  final _roleService = RoleService();
  final _storage = LocalStorage();
  bool _isSending = false;

  String? get _uid => _storage.userId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _uid == null || _isSending) return;

    setState(() => _isSending = true);
    _msgCtrl.clear();

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .get();
      final name =
          userDoc.data()?['nameSurname'] as String? ?? 'Kullanıcı';
      await _roleService.sendMessage(
        communityId: widget.communityId,
        text: text,
        senderName: name,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Yardımcılar ──────────────────────────────────────────────────────────

  static String _fmtTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  static String _monthTR(int m) => const [
        '',
        'Oca',
        'Şub',
        'Mar',
        'Nis',
        'May',
        'Haz',
        'Tem',
        'Ağu',
        'Eyl',
        'Eki',
        'Kas',
        'Ara'
      ][m];

  static String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Bugün';
    if (diff == 1) return 'Dün';
    return '${dt.day} ${_monthTR(dt.month)} ${dt.year}';
  }

  static String _relTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Az önce';
    if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
    if (diff.inHours < 24) return '${diff.inHours} sa';
    if (diff.inDays == 1) return 'Dün';
    return '${dt.day} ${_monthTR(dt.month)}';
  }

  static String _deadlineLabel(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    if (diff.isNegative) {
      final days = diff.inDays.abs();
      return days == 0 ? 'Bugün sona erdi' : '$days gün önce sona erdi';
    }
    if (diff.inDays == 0) return 'Bugün sona eriyor';
    if (diff.inDays == 1) return 'Yarın sona eriyor';
    return '${diff.inDays} gün kaldı';
  }

  // Aynı gönderici grubu başlangıcı mı?
  bool _isGroupStart(List<QueryDocumentSnapshot> docs, int i) {
    if (i == 0) return true;
    final curr = docs[i].data() as Map<String, dynamic>;
    final prev = docs[i - 1].data() as Map<String, dynamic>;
    if (curr['senderUid'] != prev['senderUid']) return true;
    final ct = (curr['sentAt'] as Timestamp?)?.toDate();
    final pt = (prev['sentAt'] as Timestamp?)?.toDate();
    if (ct == null || pt == null) return true;
    return ct.difference(pt).inMinutes > 4;
  }

  bool _showDateSep(List<QueryDocumentSnapshot> docs, int i) {
    if (i == 0) return true;
    final ct =
        (docs[i].data() as Map<String, dynamic>)['sentAt'] as Timestamp?;
    final pt = (docs[i - 1].data()
        as Map<String, dynamic>)['sentAt'] as Timestamp?;
    if (ct == null || pt == null) return false;
    final a = ct.toDate(), b = pt.toDate();
    return a.year != b.year || a.month != b.month || a.day != b.day;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07101C),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildMessageChannel(),
                  _buildAnnouncements(),
                  _buildTasks(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final name = data['name'] as String? ?? 'Topluluk';
        final desc = data['description'] as String? ?? '';
        final count = data['memberCount'] as int? ?? 0;

        return Container(
          padding: const EdgeInsets.fromLTRB(4, 6, 16, 10),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D1B2A), Color(0xFF162840)],
            ),
            border: Border(bottom: BorderSide(color: Colors.white10)),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios,
                    color: Colors.white70, size: 19),
                onPressed: () => Navigator.pop(context),
              ),
              // Avatar
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFC9A227), Color(0xFF8B6914)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'T',
                    style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: GoogleFonts.playfairDisplay(
                            color: AppColors.gold,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text('$count üye',
                            style: GoogleFonts.notoSans(
                                color: Colors.white54, fontSize: 12)),
                        if (desc.isNotEmpty) ...[
                          Text(' · ',
                              style: GoogleFonts.notoSans(
                                  color: Colors.white24, fontSize: 12)),
                          Expanded(
                            child: Text(desc,
                                style: GoogleFonts.notoSans(
                                    color: Colors.white38, fontSize: 11),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
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
  }

  Widget _buildTabBar() {
    return Container(
      color: const Color(0xFF0D1B2A),
      child: TabBar(
        controller: _tabController,
        labelColor: AppColors.gold,
        unselectedLabelColor: Colors.white38,
        indicatorColor: AppColors.gold,
        indicatorWeight: 2,
        labelStyle: GoogleFonts.notoSans(
            fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle:
            GoogleFonts.notoSans(fontSize: 12),
        tabs: const [
          Tab(icon: Icon(Icons.forum_outlined, size: 15), text: 'Kanal'),
          Tab(
              icon: Icon(Icons.campaign_outlined, size: 15),
              text: 'Duyurular'),
          Tab(
              icon: Icon(Icons.task_alt_outlined, size: 15),
              text: 'Görevler'),
        ],
      ),
    );
  }

  // ── KANAL (Mesajlaşma) ────────────────────────────────────────────────────

  Widget _buildMessageChannel() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('communities')
                .doc(widget.communityId)
                .collection('messages')
                .orderBy('sentAt')
                .snapshots(),
            builder: (_, snap) {
              final docs = snap.data?.docs ?? [];

              if (docs.isEmpty) {
                return _buildEmptyState(
                  icon: Icons.forum_outlined,
                  text: 'Henüz mesaj yok',
                  sub: 'Topluluğunuzla ilk mesajı siz başlatın.',
                );
              }

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.jumpTo(
                      _scrollCtrl.position.maxScrollExtent);
                }
              });

              return ListView.builder(
                controller: _scrollCtrl,
                padding:
                    const EdgeInsets.fromLTRB(12, 12, 12, 8),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data =
                      docs[i].data() as Map<String, dynamic>;
                  final isMe = data['senderUid'] == _uid;
                  final groupStart = _isGroupStart(docs, i);
                  final showDate = _showDateSep(docs, i);
                  final ts = (data['sentAt'] as Timestamp?)?.toDate();

                  return Column(
                    children: [
                      if (showDate) _buildDateSeparator(ts),
                      _buildBubble(data, isMe, groupStart, ts),
                    ],
                  );
                },
              );
            },
          ),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildDateSeparator(DateTime? dt) {
    if (dt == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider(color: Colors.white12, thickness: 0.5)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              _dayLabel(dt),
              style: GoogleFonts.notoSans(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider(color: Colors.white12, thickness: 0.5)),
        ],
      ),
    );
  }

  Widget _buildBubble(
    Map<String, dynamic> data,
    bool isMe,
    bool groupStart,
    DateTime? ts,
  ) {
    final text = data['text'] as String? ?? '';
    final name = data['senderName'] as String? ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final timeStr = ts != null ? _fmtTime(ts) : '';

    return Padding(
      padding: EdgeInsets.only(
        bottom: groupStart ? 2 : 1,
        top: groupStart ? 6 : 0,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar (sadece başka kişilerin grup başlangıcında)
          if (!isMe) ...[
            if (groupStart)
              Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 6, bottom: 2),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.turquoise, Color(0xFF155060)],
                  ),
                ),
                child: Center(
                  child: Text(initial,
                      style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ),
              )
            else
              const SizedBox(width: 38),
          ],

          // Balon
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.70,
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: isMe
                    ? const Color(0xFF1B3855)
                    : const Color(0xFF1A2237),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : (groupStart ? 4 : 18)),
                  bottomRight: Radius.circular(isMe ? (groupStart ? 4 : 18) : 18),
                ),
                border: Border.all(
                  color: isMe
                      ? AppColors.turquoise.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.07),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isMe && groupStart)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        name,
                        style: GoogleFonts.notoSans(
                          color: AppColors.turquoiseLight,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    text,
                    style: GoogleFonts.notoSans(
                      color: Colors.white.withValues(alpha: 0.93),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      timeStr,
                      style: GoogleFonts.notoSans(
                        color: Colors.white30,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              focusNode: _focusNode,
              style: GoogleFonts.notoSans(
                  color: Colors.white, fontSize: 14),
              maxLines: 4,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: 'Mesaj yaz...',
                hintStyle: GoogleFonts.notoSans(
                    color: Colors.white30, fontSize: 14),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                filled: true,
                fillColor: const Color(0xFF1A2237),
                enabledBorder: OutlineInputBorder(
                  borderSide:
                      const BorderSide(color: Colors.white12),
                  borderRadius: BorderRadius.circular(24),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(
                      color: AppColors.turquoise, width: 1.2),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: _isSending
                      ? [Colors.white24, Colors.white12]
                      : [AppColors.gold, const Color(0xFFB8860B)],
                ),
                boxShadow: _isSending
                    ? []
                    : [
                        BoxShadow(
                          color: AppColors.gold.withValues(alpha: 0.4),
                          blurRadius: 10,
                          spreadRadius: 1,
                        )
                      ],
              ),
              child: _isSending
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ── DUYURULAR ─────────────────────────────────────────────────────────────

  Widget _buildAnnouncements() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('announcements')
          .orderBy('sentAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.campaign_outlined,
            text: 'Duyuru yok',
            sub: 'Admin tarafından yapılan duyurular burada görünür.',
          );
        }

        // Uyarıları başa al
        final sorted = [...docs]..sort((a, b) {
            final aw = (a.data() as Map<String, dynamic>)['isWarning'] as bool? ?? false;
            final bw = (b.data() as Map<String, dynamic>)['isWarning'] as bool? ?? false;
            return (bw ? 1 : 0) - (aw ? 1 : 0);
          });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          itemCount: sorted.length,
          itemBuilder: (_, i) {
            final data = sorted[i].data() as Map<String, dynamic>;
            final isWarning = data['isWarning'] as bool? ?? false;
            final msg = data['message'] as String? ?? '';
            final ts =
                (data['sentAt'] as Timestamp?)?.toDate();

            final accent =
                isWarning ? const Color(0xFFFF6B35) : AppColors.gold;
            final bg = isWarning
                ? const Color(0xFF2A1A10)
                : const Color(0xFF1A1E0F);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: accent.withValues(alpha: 0.3), width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.06),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Renkli sol şerit
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(14),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isWarning
                                        ? Icons.warning_amber_rounded
                                        : Icons.campaign_rounded,
                                    color: accent,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isWarning ? 'Uyarı' : 'Duyuru',
                                  style: GoogleFonts.notoSans(
                                    color: accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const Spacer(),
                                if (ts != null)
                                  Text(
                                    _relTime(ts),
                                    style: GoogleFonts.notoSans(
                                        color: Colors.white38,
                                        fontSize: 11),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              msg,
                              style: GoogleFonts.notoSans(
                                color:
                                    Colors.white.withValues(alpha: 0.9),
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            if (ts != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                '${ts.day} ${_monthTR(ts.month)} ${ts.year}, ${_fmtTime(ts)}',
                                style: GoogleFonts.notoSans(
                                    color: Colors.white24, fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ── GÖREVLER ─────────────────────────────────────────────────────────────

  Widget _buildTasks() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .orderBy('deadline')
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyState(
            icon: Icons.task_alt_outlined,
            text: 'Görev yok',
            sub: 'Admin tarafından atanan görevler burada listelenir.',
          );
        }

        // Tamamlanmamışları başa al
        final sorted = [...docs]..sort((a, b) {
            final ad = (a.data() as Map<String, dynamic>)['completions'] as Map?;
            final bd = (b.data() as Map<String, dynamic>)['completions'] as Map?;
            final ac = ad?.containsKey(_uid) ?? false;
            final bc = bd?.containsKey(_uid) ?? false;
            return (ac ? 1 : 0) - (bc ? 1 : 0);
          });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: sorted.length,
          itemBuilder: (_, i) {
            final data = sorted[i].data() as Map<String, dynamic>;
            final taskId = sorted[i].id;
            final title = data['title'] as String? ?? '';
            final desc = data['description'] as String? ?? '';
            final deadline =
                (data['deadline'] as Timestamp?)?.toDate();
            final completions = Map<String, dynamic>.from(
                data['completions'] as Map? ?? {});
            final isCompleted = completions.containsKey(_uid);
            final isOverdue = deadline != null &&
                deadline.isBefore(DateTime.now()) &&
                !isCompleted;

            return _TaskCard(
              communityId: widget.communityId,
              taskId: taskId,
              title: title,
              desc: desc,
              deadline: deadline,
              completions: completions,
              isCompleted: isCompleted,
              isOverdue: isOverdue,
              uid: _uid,
            );
          },
        );
      },
    );
  }

  // ── Boş durum ─────────────────────────────────────────────────────────────

  Widget _buildEmptyState({
    required IconData icon,
    required String text,
    required String sub,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
                border: Border.all(color: Colors.white12),
              ),
              child: Icon(icon, color: Colors.white24, size: 42),
            ),
            const SizedBox(height: 20),
            Text(text,
                style: GoogleFonts.playfairDisplay(
                    color: Colors.white54,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(sub,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSans(
                    color: Colors.white30, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ── Görev kartı (kendi stateful widget'ı, animasyonlu tamamlama) ───────────

class _TaskCard extends StatefulWidget {
  final String communityId;
  final String taskId;
  final String title;
  final String desc;
  final DateTime? deadline;
  final Map<String, dynamic> completions;
  final bool isCompleted;
  final bool isOverdue;
  final String? uid;

  const _TaskCard({
    required this.communityId,
    required this.taskId,
    required this.title,
    required this.desc,
    required this.deadline,
    required this.completions,
    required this.isCompleted,
    required this.isOverdue,
    required this.uid,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  bool _completing = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (widget.uid == null || _completing) return;
    setState(() => _completing = true);
    HapticFeedback.lightImpact();
    await _animCtrl.forward();
    await _animCtrl.reverse();

    await FirebaseFirestore.instance
        .collection('communities')
        .doc(widget.communityId)
        .collection('tasks')
        .doc(widget.taskId)
        .update({'completions.${widget.uid}': FieldValue.serverTimestamp()});

    if (mounted) setState(() => _completing = false);
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.completions.length;
    // Üye sayısını bulmak için community doc'u izlemek yerine sınırlandırıyoruz
    // (gerçek üye sayısı admin_dashboard'da zaten var, burada tamamlayan sayısı yeterli)
    final deadline = widget.deadline;
    final isCompleted = widget.isCompleted;
    final isOverdue = widget.isOverdue;

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    if (isCompleted) {
      statusColor = const Color(0xFF4CAF50);
      statusLabel = 'Tamamlandı';
      statusIcon = Icons.check_circle_outline;
    } else if (isOverdue) {
      statusColor = const Color(0xFFEF5350);
      statusLabel = 'Gecikti';
      statusIcon = Icons.error_outline;
    } else {
      statusColor = AppColors.turquoise;
      statusLabel = 'Bekliyor';
      statusIcon = Icons.schedule_outlined;
    }

    return ScaleTransition(
      scale: _scaleAnim,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF121C2D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
                : isOverdue
                    ? const Color(0xFFEF5350).withValues(alpha: 0.3)
                    : Colors.white.withValues(alpha: 0.07),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık satırı + durum çipi
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.notoSans(
                        color: isCompleted
                            ? Colors.white38
                            : Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        decoration: isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: Colors.white38,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon,
                            color: statusColor, size: 12),
                        const SizedBox(width: 4),
                        Text(statusLabel,
                            style: GoogleFonts.notoSans(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),

              // Açıklama
              if (widget.desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.desc,
                  style: GoogleFonts.notoSans(
                    color: Colors.white54,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Deadline + tamamlayan sayısı
              Row(
                children: [
                  if (deadline != null) ...[
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: isOverdue
                          ? const Color(0xFFEF5350)
                          : Colors.white38,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _CommunityScreenState._deadlineLabel(deadline),
                      style: GoogleFonts.notoSans(
                        color: isOverdue
                            ? const Color(0xFFEF5350)
                            : Colors.white38,
                        fontSize: 12,
                        fontWeight: isOverdue ? FontWeight.bold : null,
                      ),
                    ),
                    const Spacer(),
                  ],
                  const Spacer(),
                  if (completed > 0) ...[
                    const Icon(Icons.check,
                        color: Color(0xFF4CAF50), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '$completed kişi tamamladı',
                      style: GoogleFonts.notoSans(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ],
              ),

              // Tamamla butonu
              if (!isCompleted) ...[
                const SizedBox(height: 12),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _completing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline,
                            size: 17, color: Colors.white),
                    label: Text(
                      _completing ? 'Kaydediliyor...' : 'Tamamladım',
                      style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOverdue
                          ? const Color(0xFF5C2020)
                          : const Color(0xFF1A3A2A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: isOverdue
                              ? const Color(0xFFEF5350)
                                  .withValues(alpha: 0.4)
                              : const Color(0xFF4CAF50)
                                  .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    onPressed: _completing ? null : _complete,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
