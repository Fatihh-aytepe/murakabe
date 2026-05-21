import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/role_service.dart';
import '../admin/user_detail_screen.dart';

class CommunityOwnerPanelScreen extends StatefulWidget {
  const CommunityOwnerPanelScreen({super.key});

  @override
  State<CommunityOwnerPanelScreen> createState() => _CommunityOwnerPanelScreenState();
}

enum _OwnerState { checking, isOwner, notOwner, notConfigured }

class _CommunityOwnerPanelScreenState extends State<CommunityOwnerPanelScreen> {
  final _roleService = RoleService();
  _OwnerState _state = _OwnerState.checking;
  bool _setting = false;

  @override
  void initState() {
    super.initState();
    _checkOwner();
  }

  Future<void> _checkOwner() async {
    final isOwner = await _roleService.isCurrentUserOwner();
    if (!mounted) return;
    if (isOwner) {
      setState(() => _state = _OwnerState.isOwner);
      return;
    }
    final configured = await _roleService.isOwnerConfigured();
    if (mounted) {
      setState(() => _state =
          configured ? _OwnerState.notOwner : _OwnerState.notConfigured);
    }
  }

  Future<void> _setupOwner() async {
    setState(() => _setting = true);
    try {
      await _roleService.setupOwner();
      if (mounted) {
        setState(() {
          _state = _OwnerState.isOwner;
          _setting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sahip rolü başarıyla oluşturuldu'),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _setting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

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
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sahip Paneli',
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.gold,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Admin başvuruları ve sistem yönetimi',
                        style: GoogleFonts.notoSans(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // İçerik
            Expanded(
              child: switch (_state) {
                _OwnerState.checking => const Center(
                    child: CircularProgressIndicator(color: AppColors.gold)),
                _OwnerState.notConfigured => _buildSetupView(),
                _OwnerState.notOwner => _buildNotOwnerView(),
                _OwnerState.isOwner => DefaultTabController(
                    length: 2,
                    child: Column(
                      children: [
                        const TabBar(
                          labelColor: AppColors.gold,
                          unselectedLabelColor: Colors.white38,
                          indicatorColor: AppColors.gold,
                          tabs: [
                            Tab(text: 'Admin Başvuruları'),
                            Tab(text: 'Tüm Kullanıcılar'),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              const _AdminRequestsTab(),
                              const _AllUsersTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotOwnerView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.orange.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.admin_panel_settings,
                  color: Colors.orange, size: 56),
            ),
            const SizedBox(height: 24),
            Text(
              'Sahip Kaydı Gerekli',
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Bu cihazda sahip hesabıyla giriş yaptıysanız\naşağıdaki butona basarak sahipliği talep edebilirsiniz.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                  color: Colors.white54, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _setting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.verified_user, color: Colors.white),
                label: Text(
                  _setting ? 'Kuruluyor...' : 'Sahip Olarak Kur',
                  style: GoogleFonts.notoSans(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _setting ? null : _confirmAndSetupOwner,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndSetupOwner() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        title: Text(
          'Sahipliği Üstlen',
          style: GoogleFonts.playfairDisplay(color: Colors.white),
        ),
        content: Text(
          'Mevcut sahip kaydı silinecek ve bu hesap sahip olarak atanacak. Devam etmek istiyor musunuz?',
          style: GoogleFonts.notoSans(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal',
                style: GoogleFonts.notoSans(color: Colors.white54)),
          ),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Devam Et',
                style: GoogleFonts.notoSans(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) _setupOwner();
  }

  Widget _buildSetupView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.1),
              ),
              child: const Icon(Icons.admin_panel_settings,
                  color: AppColors.gold, size: 56),
            ),
            const SizedBox(height: 24),
            Text(
              'İlk Kurulum',
              style: GoogleFonts.playfairDisplay(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sahip rolü henüz oluşturulmamış.\nBu butona basarak kendinizi sahip olarak tanımlayın.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                  color: Colors.white54, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _setting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.verified_user, color: Colors.white),
                label: Text(
                  _setting ? 'Kuruluyor...' : 'Sahip Olarak Kur',
                  style: GoogleFonts.notoSans(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _setting ? null : _setupOwner,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Admin Başvuruları ──────────────────────────────────────────────────────────

class _AdminRequestsTab extends StatefulWidget {
  const _AdminRequestsTab();

  @override
  State<_AdminRequestsTab> createState() => _AdminRequestsTabState();
}

class _AdminRequestsTabState extends State<_AdminRequestsTab> {
  final _roleService = RoleService();
  Stream<QuerySnapshot>? _stream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  Future<void> _initStream() async {
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
    if (!mounted) return;
    setState(() => _stream = _roleService.getPendingAdminRequests());
  }

  @override
  Widget build(BuildContext context) {
    if (_stream == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.gold));
        }

        if (snapshot.hasError) {
          debugPrint('[AdminRequests] Hata: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Veri yüklenemedi:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.notoSans(color: Colors.red, fontSize: 13),
              ),
            ),
          );
        }

        final docs = List.of(snapshot.data?.docs ?? [])
          ..sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['appliedAt'];
            final bTs = (b.data() as Map<String, dynamic>)['appliedAt'];
            if (aTs == null && bTs == null) return 0;
            if (aTs == null) return 1;
            if (bTs == null) return -1;
            return (bTs as Timestamp).compareTo(aTs as Timestamp);
          });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox_outlined,
                    color: Colors.white24, size: 56),
                const SizedBox(height: 12),
                Text(
                  'Bekleyen başvuru yok',
                  style:
                      GoogleFonts.notoSans(color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = data['uid'] as String? ?? '';
            final name = data['name'] as String? ?? 'İsimsiz';
            final reason = data['reason'] as String? ?? '';
            final appliedAt = (data['appliedAt'] as Timestamp?)?.toDate();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2035),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withValues(alpha: 0.15),
                        ),
                        child: const Icon(Icons.person,
                            color: AppColors.gold, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.playfairDisplay(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (appliedAt != null)
                              Text(
                                '${appliedAt.day}.${appliedAt.month}.${appliedAt.year}',
                                style: GoogleFonts.notoSans(
                                    color: Colors.white38, fontSize: 11),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        reason,
                        style: GoogleFonts.notoSans(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close,
                              color: Colors.red, size: 16),
                          label: Text('Reddet',
                              style: GoogleFonts.notoSans(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            await _roleService.rejectAdmin(uid);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Başvuru reddedildi')),
                              );
                            }
                          },
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
                                  fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () async {
                            await _roleService.approveAdmin(uid);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Admin yetkisi verildi'),
                                  backgroundColor: Color(0xFF2E7D32),
                                ),
                              );
                            }
                          },
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
}

// ── Tüm Kullanıcılar ──────────────────────────────────────────────────────────

class _AllUsersTab extends StatefulWidget {
  const _AllUsersTab();

  @override
  State<_AllUsersTab> createState() => _AllUsersTabState();
}

class _AllUsersTabState extends State<_AllUsersTab> {
  Stream<QuerySnapshot>? _stream;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  Future<void> _initStream() async {
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
    if (!mounted) return;
    setState(() =>
        _stream = FirebaseFirestore.instance.collection('users').snapshots());
  }

  @override
  Widget build(BuildContext context) {
    if (_stream == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.gold));
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Kullanıcılar yüklenemedi:\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSans(color: Colors.red, fontSize: 13),
              ),
            ),
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline,
                    color: Colors.white24, size: 56),
                const SizedBox(height: 12),
                Text(
                  'Henüz kayıtlı kullanıcı yok',
                  style: GoogleFonts.notoSans(
                      color: Colors.white38, fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final name = data['nameSurname'] as String? ?? 'İsimsiz';
            final email = data['email'] as String? ?? '';
            final streak = data['streakDays'] as int? ?? 0;
            final quranDays = data['quranReadDays'] as int? ?? 0;

            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UserDetailScreen(
                    uid: docs[i].id,
                    name: name,
                  ),
                ),
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2035),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gold.withValues(alpha: 0.15),
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: GoogleFonts.playfairDisplay(
                              color: AppColors.gold,
                              fontWeight: FontWeight.bold),
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
                                  fontWeight: FontWeight.w600)),
                          Text(email,
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
                            const Text('🔥', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 2),
                            Text('$streak',
                                style: GoogleFonts.notoSans(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ],
                        ),
                        Row(
                          children: [
                            const Text('📖', style: TextStyle(fontSize: 11)),
                            const SizedBox(width: 2),
                            Text('$quranDays gün',
                                style: GoogleFonts.notoSans(
                                    color: AppColors.turquoise, fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right,
                        color: Colors.white24, size: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
