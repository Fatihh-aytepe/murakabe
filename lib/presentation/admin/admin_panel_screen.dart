import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/app_colors.dart';
import '../../data/local/local_storage.dart';
import '../auth/login_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            _buildStatChips(),
            Expanded(child: _buildUserList()),
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
                'Admin Paneli',
                style: GoogleFonts.playfairDisplay(
                    color: AppColors.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              Text('Murakabe Yönetim',
                  style: GoogleFonts.notoSans(
                      color: Colors.white38, fontSize: 12)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white54),
            onPressed: () async {
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
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
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

  Widget _buildUserList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
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
            return _buildUserCard(data);
          },
        );
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> data) {
    final name = data['nameSurname'] ?? 'İsimsiz';
    final email = data['email'] ?? '';
    final phone = data['phone'] ?? '';
    final quranDays = data['quranReadDays'] ?? 0;
    final missed = (data['missedQuranDays'] as List?)?.length ?? 0;
    final createdAt = data['createdAt'] != null
        ? DateTime.tryParse(data['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();

    return GestureDetector(
      onTap: () => _showUserDetail(data),
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

  void _showUserDetail(Map<String, dynamic> data) {
    final missedRaw = data['missedQuranDays'];
    final missed = missedRaw is List ? List<String>.from(missedRaw) : <String>[];
    final tahajjudEnabled = data['tahajjudAlarmEnabled'] ?? false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1A2035),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                          colors: [AppColors.gold, AppColors.turquoise]),
                    ),
                    child: Center(
                      child: Text(
                        () {
                          final n = (data['nameSurname'] ?? '').toString();
                          return n.isNotEmpty ? n[0].toUpperCase() : '?';
                        }(),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(data['nameSurname'] ?? 'İsimsiz',
                          style: GoogleFonts.playfairDisplay(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      Text(data['email'] ?? '',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13)),
                      Text(data['phone'] ?? '',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Colors.white12),
              const SizedBox(height: 16),
              _detailRow('Kuran Okuma Günü',
                  '${data['quranReadDays'] ?? 0} gün', AppColors.turquoise),
              _detailRow(
                  'Teheccüd Alarmı',
                  tahajjudEnabled ? 'Aktif ✓' : 'Kapalı',
                  tahajjudEnabled ? Colors.green : Colors.white38),
              const SizedBox(height: 16),
              if (missed.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 18),
                      SizedBox(width: 8),
                      Text('Tüm günler tamamlandı',
                          style: TextStyle(color: Colors.green, fontSize: 13)),
                    ],
                  ),
                )
              else ...[
                Text('Eksik Günler (${missed.length})',
                    style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: missed
                      .map((d) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(d,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12)),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
