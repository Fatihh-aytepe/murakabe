import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
  final _roleService = RoleService();
  final _storage = LocalStorage();

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
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;

    final user =
        await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    final name = user.data()?['nameSurname'] as String? ?? 'Kullanıcı';

    _msgCtrl.clear();
    await _roleService.sendMessage(
      communityId: widget.communityId,
      text: text,
      senderName: name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            // Başlık
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('communities')
                  .doc(widget.communityId)
                  .snapshots(),
              builder: (_, snap) {
                final name = (snap.data?.data()
                        as Map<String, dynamic>?)?['name'] as String? ??
                    'Topluluk';
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
                      const Icon(Icons.group, color: AppColors.gold, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        name,
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Tab bar
            TabBar(
              controller: _tabController,
              labelColor: AppColors.gold,
              unselectedLabelColor: Colors.white38,
              indicatorColor: AppColors.gold,
              labelStyle: GoogleFonts.notoSans(fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Kanal'),
                Tab(text: 'Duyurular'),
                Tab(text: 'Görevler'),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
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

  // ── Mesaj kanalı ──────────────────────────────────────────────────────────

  Widget _buildMessageChannel() {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('communities')
                .doc(widget.communityId)
                .collection('messages')
                .orderBy('sentAt', descending: false)
                .snapshots(),
            builder: (_, snap) {
              final docs = snap.data?.docs ?? [];
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_scrollCtrl.hasClients) {
                  _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                }
              });

              return ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final isMe = data['senderUid'] == _uid;
                  return _buildMessageBubble(data, isMe);
                },
              );
            },
          ),
        ),

        // Mesaj yazma alanı
        Container(
          padding: EdgeInsets.fromLTRB(
              12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
          color: const Color(0xFF1A2035),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _msgCtrl,
                  style: const TextStyle(color: Colors.white),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: InputDecoration(
                    hintText: 'Mesaj yaz...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    enabledBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: Colors.white24),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: const BorderSide(color: AppColors.gold),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold,
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> data, bool isMe) {
    final text = data['text'] as String? ?? '';
    final name = data['senderName'] as String? ?? '';
    final ts = (data['sentAt'] as Timestamp?)?.toDate();
    final timeStr = ts != null
        ? '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
        : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color:
              isMe ? AppColors.gold.withOpacity(0.2) : const Color(0xFF1A2035),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe ? AppColors.gold.withOpacity(0.4) : Colors.white12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                name,
                style: GoogleFonts.notoSans(
                    color: AppColors.turquoiseLight,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            Text(
              text,
              style: GoogleFonts.notoSans(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                timeStr,
                style:
                    GoogleFonts.notoSans(color: Colors.white38, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Duyurular ─────────────────────────────────────────────────────────────

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
          return Center(
            child: Text('Henüz duyuru yok',
                style: GoogleFonts.notoSans(color: Colors.white38)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final isWarning = data['isWarning'] as bool? ?? false;
            final msg = data['message'] as String? ?? '';
            final ts = (data['sentAt'] as Timestamp?)?.toDate();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isWarning
                    ? Colors.orange.withOpacity(0.1)
                    : AppColors.gold.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isWarning
                      ? Colors.orange.withOpacity(0.4)
                      : AppColors.gold.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isWarning ? Icons.warning_amber : Icons.campaign,
                    color: isWarning ? Colors.orange : AppColors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg,
                          style: GoogleFonts.notoSans(
                              color: Colors.white, fontSize: 14),
                        ),
                        if (ts != null)
                          Text(
                            '${ts.day}.${ts.month}.${ts.year}',
                            style: GoogleFonts.notoSans(
                                color: Colors.white38, fontSize: 11),
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
  }

  // ── Görevler ──────────────────────────────────────────────────────────────

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
          return Center(
            child: Text('Henüz görev atanmadı',
                style: GoogleFonts.notoSans(color: Colors.white38)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final taskId = docs[i].id;
            final title = data['title'] as String? ?? '';
            final desc = data['description'] as String? ?? '';
            final deadline = (data['deadline'] as Timestamp?)?.toDate();
            final completions =
                Map<String, dynamic>.from(data['completions'] as Map? ?? {});
            final isCompleted = completions.containsKey(_uid);
            final isOverdue =
                deadline != null && deadline.isBefore(DateTime.now());

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2035),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCompleted
                      ? const Color(0xFF2E7D32).withOpacity(0.5)
                      : isOverdue
                          ? Colors.red.withOpacity(0.4)
                          : Colors.white12,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.notoSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            decoration:
                                isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                      if (!isCompleted)
                        GestureDetector(
                          onTap: () async {
                            await FirebaseFirestore.instance
                                .collection('communities')
                                .doc(widget.communityId)
                                .collection('tasks')
                                .doc(taskId)
                                .update({
                              'completions.$_uid': FieldValue.serverTimestamp(),
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E7D32).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      const Color(0xFF2E7D32).withOpacity(0.5)),
                            ),
                            child: Text(
                              'Tamamladım',
                              style: GoogleFonts.notoSans(
                                color: const Color(0xFF4CAF50),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.check_circle,
                            color: Color(0xFF4CAF50), size: 20),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(desc,
                        style: GoogleFonts.notoSans(
                            color: Colors.white54, fontSize: 12)),
                  ],
                  if (deadline != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: isOverdue ? Colors.red : Colors.white38,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Son: ${deadline.day}.${deadline.month}.${deadline.year}',
                          style: GoogleFonts.notoSans(
                            color: isOverdue ? Colors.red : Colors.white38,
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${completions.length} tamamladı',
                          style: GoogleFonts.notoSans(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}
