import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/role_service.dart';
import '../../data/local/local_storage.dart';
import '../../data/remote/firebase_service.dart';
import '../auth/login_screen.dart';
import 'user_detail_screen.dart';

class OwnerPanelScreen extends StatefulWidget {
  const OwnerPanelScreen({super.key});

  @override
  State<OwnerPanelScreen> createState() => _OwnerPanelScreenState();
}

class _OwnerPanelScreenState extends State<OwnerPanelScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  Stream<QuerySnapshot>? _usersStream;
  Stream<QuerySnapshot>? _requestsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initStreams();
  }

  Future<void> _initStreams() async {
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
    if (!mounted) return;
    setState(() {
      _usersStream = FirebaseFirestore.instance.collection('users').snapshots();
      _requestsStream = RoleService().getPendingAdminRequests();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            // Tab bar
            Container(
              color: const Color(0xFF0F1624),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.gold,
                indicatorWeight: 2,
                labelColor: AppColors.gold,
                unselectedLabelColor: Colors.white38,
                labelStyle: GoogleFonts.notoSans(
                    fontWeight: FontWeight.bold, fontSize: 13),
                tabs: [
                  const Tab(text: 'Kullanıcılar'),
                  StreamBuilder<QuerySnapshot>(
                    stream: _requestsStream,
                    builder: (_, snap) {
                      final count = snap.data?.docs.length ?? 0;
                      return Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Başvurular'),
                            if (count > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Kullanıcılar sekmesi
                  Column(
                    children: [
                      _buildSearchBar(),
                      _buildStatChips(),
                      Expanded(child: _buildUserList()),
                    ],
                  ),
                  // Admin başvuruları sekmesi
                  _buildAdminRequests(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        border:
            Border(bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: const Icon(Icons.admin_panel_settings,
                color: AppColors.gold, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sahip Paneli',
                style: GoogleFonts.playfairDisplay(
                    color: AppColors.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              Text('Tüm Kullanıcılar ve Başvurular',
                  style: GoogleFonts.notoSans(
                      color: Colors.white38, fontSize: 12)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: () async {
              await FirebaseService().signOut();
              await LocalStorage().setAdmin(false);
              if (!mounted) return;
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      color: const Color(0xFF0F1624),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Kullanıcı ara...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.gold),
          ),
        ),
      ),
    );
  }

  Widget _buildStatChips() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      color: const Color(0xFF0F1624),
      child: StreamBuilder<QuerySnapshot>(
        stream: _usersStream,
        builder: (_, snap) {
          final count = snap.data?.docs.length ?? 0;
          return Row(
            children: [
              _buildChip('Toplam: $count', AppColors.gold),
            ],
          );
        },
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildAdminRequests() {
    if (_requestsStream == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _requestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.gold));
        }
        if (snapshot.hasError) {
          debugPrint('[AdminRequests] Hata: ${snapshot.error}');
          return Center(
            child: Text(
              'Yüklenemedi:\n${snapshot.error}',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(color: Colors.red, fontSize: 13),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox_outlined,
                    size: 60, color: Colors.white12),
                const SizedBox(height: 12),
                Text('Bekleyen başvuru yok',
                    style: GoogleFonts.notoSans(
                        color: Colors.white38, fontSize: 14)),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = data['uid'] ?? docs[i].id;
            final name = data['name'] ?? 'İsimsiz';
            final reason = data['reason'] ?? '';
            final appliedAt = data['appliedAt'];
            String dateStr = '';
            if (appliedAt is Timestamp) {
              final dt = appliedAt.toDate();
              dateStr =
                  '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2035),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                              colors: [AppColors.gold, AppColors.turquoise]),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: GoogleFonts.notoSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            if (dateStr.isNotEmpty)
                              Text('Başvuru: $dateStr',
                                  style: GoogleFonts.notoSans(
                                      color: Colors.white38, fontSize: 11)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withValues(alpha: 0.4)),
                        ),
                        child: Text('Bekliyor',
                            style: GoogleFonts.notoSans(
                                color: Colors.orange,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.format_quote,
                              color: AppColors.gold, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(reason,
                                style: GoogleFonts.notoSans(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    height: 1.5)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close,
                              color: Colors.red, size: 16),
                          label: Text('Reddet',
                              style: GoogleFonts.notoSans(
                                  color: Colors.red, fontSize: 13)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _confirmAction(
                            uid: uid,
                            name: name,
                            approve: false,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check,
                              color: Colors.white, size: 16),
                          label: Text('Onayla',
                              style: GoogleFonts.notoSans(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _confirmAction(
                            uid: uid,
                            name: name,
                            approve: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmAction(
      {required String uid,
      required String name,
      required bool approve}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          approve ? 'Başvuruyu Onayla' : 'Başvuruyu Reddet',
          style: GoogleFonts.playfairDisplay(
              color: AppColors.gold, fontWeight: FontWeight.bold),
        ),
        content: Text(
          approve
              ? '$name kişisine admin yetkisi verilecek. Emin misiniz?'
              : '$name kişisinin başvurusu reddedilecek.',
          style: GoogleFonts.notoSans(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Vazgeç',
                style: GoogleFonts.notoSans(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.green.shade700 : Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(approve ? 'Onayla' : 'Reddet',
                style: GoogleFonts.notoSans(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (approve) {
        await RoleService().approveAdmin(uid);
      } else {
        await RoleService().rejectAdmin(uid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(approve
                ? '$name artık admin oldu.'
                : '$name başvurusu reddedildi.'),
            backgroundColor:
                approve ? Colors.green.shade700 : Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Hata: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _usersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.gold));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
              child: Text('Henüz kullanıcı yok',
                  style: GoogleFonts.notoSans(color: Colors.white38)));
        }

        var docs = snapshot.data!.docs;
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['nameSurname'] ?? '').toString().toLowerCase();
            final email = (data['email'] ?? '').toString().toLowerCase();
            final phone = (data['phone'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery) ||
                email.contains(_searchQuery) ||
                phone.contains(_searchQuery);
          }).toList();
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _buildUserCard(docs[i].id, data);
          },
        );
      },
    );
  }

  Widget _buildUserCard(String uid, Map<String, dynamic> data) {
    final name = data['nameSurname'] ?? 'İsimsiz';
    final email = data['email'] ?? '';
    final phone = data['phone'] ?? '';
    final quranDays = data['quranReadDays'] ?? 0;
    final missed = (data['missedQuranDays'] as List?)?.length ?? 0;
    final createdAt = data['createdAt'] != null
        ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => UserDetailScreen(
            uid: uid,
            name: name.toString(),
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: missed > 0
                ? Colors.red.withValues(alpha: 0.3)
                : AppColors.gold.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [AppColors.gold, AppColors.turquoise]),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(email,
                      style: GoogleFonts.notoSans(
                          color: Colors.white54, fontSize: 12)),
                  Text(phone,
                      style: GoogleFonts.notoSans(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.menu_book,
                        color: AppColors.turquoise, size: 14),
                    const SizedBox(width: 4),
                    Text('$quranDays gün',
                        style: const TextStyle(
                            color: AppColors.turquoise, fontSize: 12)),
                  ],
                ),
                if (missed > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.warning_amber,
                          color: Colors.red, size: 12),
                      const SizedBox(width: 4),
                      Text('$missed eksik',
                          style:
                              const TextStyle(color: Colors.red, fontSize: 11)),
                    ],
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${createdAt.day.toString().padLeft(2, '0')}.${createdAt.month.toString().padLeft(2, '0')}.${createdAt.year}',
                  style: const TextStyle(color: Colors.white24, fontSize: 10),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
          ],
        ),
      ),
    );
  }

}
