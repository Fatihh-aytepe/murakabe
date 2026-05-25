import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/role_service.dart';
import '../../../data/local/local_storage.dart';
import '../../../data/remote/firebase_service.dart';
import '../admin/user_detail_screen.dart';
import '../auth/login_screen.dart';

// ════════════════════════════════════════════════════════════════════════════
// Ana widget — owner kontrolü yapar, duruma göre doğru view'i gösterir
// ════════════════════════════════════════════════════════════════════════════

class CommunityOwnerPanelScreen extends StatefulWidget {
  const CommunityOwnerPanelScreen({super.key});

  @override
  State<CommunityOwnerPanelScreen> createState() =>
      _CommunityOwnerPanelScreenState();
}

enum _OwnerState { checking, isOwner, notOwner, notConfigured }

class _CommunityOwnerPanelScreenState
    extends State<CommunityOwnerPanelScreen> {
  final _roleService = RoleService();
  _OwnerState _state = _OwnerState.checking;
  bool _setting = false;

  final _pageCtrl = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _checkOwner();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkOwner() async {
    try {
      await FirebaseAuth.instance.currentUser
          ?.getIdToken(true)
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
    if (!mounted) return;

    final isOwner = await _roleService.isCurrentUserOwner();
    if (!mounted) return;
    if (isOwner) {
      setState(() => _state = _OwnerState.isOwner);
      _runMigration();
      return;
    }
    final configured = await _roleService.isOwnerConfigured();
    if (mounted) {
      setState(() => _state =
          configured ? _OwnerState.notOwner : _OwnerState.notConfigured);
    }
  }

  Future<void> _runMigration() async {
    final result = await _roleService.migrateInviteCodes();
    if (!mounted) return;
    if (result.migrated == 0 && result.errors.isEmpty) return;
    final msg = result.errors.isEmpty
        ? '${result.migrated} topluluk migrate edildi'
        : '${result.migrated} migrate, ${result.errors.length} hata';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          result.errors.isEmpty ? const Color(0xFF2E7D32) : Colors.orange,
      behavior: SnackBarBehavior.floating,
    ));
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
            content: Text('Sahip rolü oluşturuldu'),
            backgroundColor: Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _setting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> _confirmAndSetupOwner() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Sahipliği Üstlen',
            style: GoogleFonts.playfairDisplay(color: Colors.white)),
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
    if (ok == true) _setupOwner();
  }

  void _goPage(int i) {
    setState(() => _page = i);
    _pageCtrl.animateToPage(i,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
            bottom:
                BorderSide(color: AppColors.gold.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios,
                color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.4)),
              color: AppColors.gold.withValues(alpha: 0.15),
            ),
            child: const Icon(Icons.shield_outlined,
                color: AppColors.gold, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sahip Paneli',
                    style: GoogleFonts.playfairDisplay(
                        color: AppColors.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text('Admin başvuruları ve sistem yönetimi',
                    style: GoogleFonts.notoSans(
                        color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded,
                color: Colors.white38, size: 20),
            tooltip: 'Çıkış',
            onPressed: _confirmSignOut,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        title: Text('Çıkış',
            style: GoogleFonts.playfairDisplay(color: Colors.white)),
        content: Text('Çıkış yapmak istiyor musunuz?',
            style: GoogleFonts.notoSans(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('İptal',
                  style: GoogleFonts.notoSans(color: Colors.white54))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Çıkış',
                  style: GoogleFonts.notoSans(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await FirebaseService().signOut();
    await LocalStorage().setAdmin(false);
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  Widget _buildBody() {
    return switch (_state) {
      _OwnerState.checking => const Center(
          child: CircularProgressIndicator(color: AppColors.gold)),
      _OwnerState.notConfigured => _buildSetupView(),
      _OwnerState.notOwner => _buildNotOwnerView(),
      _OwnerState.isOwner => _buildOwnerPanel(),
    };
  }

  Widget _buildOwnerPanel() {
    return Column(
      children: [
        _buildSegmentNav(),
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _page = i),
            physics: const ClampingScrollPhysics(),
            children: const [
              _RequestsPage(),
              _UsersPage(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegmentNav() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('adminRequests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (_, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1624),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              _seg(0, 'Başvurular', Icons.assignment_outlined,
                  badge: count > 0 ? '$count' : null),
              _seg(1, 'Kullanıcılar', Icons.people_outline),
            ],
          ),
        );
      },
    );
  }

  Widget _seg(int index, String label, IconData icon, {String? badge}) {
    final active = _page == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _goPage(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(colors: [
                    AppColors.gold.withValues(alpha: 0.22),
                    AppColors.turquoise.withValues(alpha: 0.12),
                  ])
                : null,
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(
                    color: AppColors.gold.withValues(alpha: 0.45))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: active ? AppColors.gold : Colors.white38),
              const SizedBox(width: 6),
              Text(label,
                  style: GoogleFonts.notoSans(
                      color: active ? AppColors.gold : Colors.white38,
                      fontWeight: active
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13)),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
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
                  color: Colors.orange.withValues(alpha: 0.1)),
              child: const Icon(Icons.admin_panel_settings,
                  color: Colors.orange, size: 56),
            ),
            const SizedBox(height: 24),
            Text('Sahip Kaydı Gerekli',
                style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
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
                        color: Colors.white, fontWeight: FontWeight.bold)),
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
                  color: AppColors.gold.withValues(alpha: 0.1)),
              child: const Icon(Icons.admin_panel_settings,
                  color: AppColors.gold, size: 56),
            ),
            const SizedBox(height: 24),
            Text('İlk Kurulum',
                style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
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
                        color: Colors.white, fontWeight: FontWeight.bold)),
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

// ════════════════════════════════════════════════════════════════════════════
// Sayfa 1 — Admin Başvuruları
// ════════════════════════════════════════════════════════════════════════════

class _RequestsPage extends StatefulWidget {
  const _RequestsPage();

  @override
  State<_RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<_RequestsPage> {
  final _roleService = RoleService();
  Stream<QuerySnapshot>? _stream;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Token yenile — izin hatalarını önler
    try {
      await FirebaseAuth.instance.currentUser
          ?.getIdToken(true)
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      // orderBy YOK → composite index gerekmez → "sürekli loading" sorunu çözüldü
      // Sıralama aşağıda client-side yapılır
      _stream = FirebaseFirestore.instance
          .collection('adminRequests')
          .where('status', isEqualTo: 'pending')
          .snapshots();
      _ready = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          debugPrint('[Başvurular] Hata: ${snap.error}');
          return _ErrorView(
            message:
                'Başvurular yüklenemedi.\n\nFirestore index eksik olabilir.\nHata: ${snap.error}',
            onRetry: _init,
          );
        }

        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.gold));
        }

        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const _EmptyView(
            icon: Icons.inbox_outlined,
            title: 'Bekleyen başvuru yok',
            subtitle:
                'Kullanıcılar admin yetkisi talep ettiğinde burada görünür',
          );
        }

        // Client-side sıralama (orderBy olmadığı için)
        final docs = [...snap.data!.docs]..sort((a, b) {
            final aT = (a.data()
                    as Map<String, dynamic>)['appliedAt'] as Timestamp?;
            final bT = (b.data()
                    as Map<String, dynamic>)['appliedAt'] as Timestamp?;
            if (aT == null && bT == null) return 0;
            if (aT == null) return 1;
            if (bT == null) return -1;
            return bT.compareTo(aT);
          });

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final uid = data['uid'] as String? ?? docs[i].id;
            final name = data['name'] as String? ?? 'İsimsiz';
            final reason = data['reason'] as String? ?? '';
            final appliedAt =
                (data['appliedAt'] as Timestamp?)?.toDate();
            return _RequestCard(
              uid: uid,
              name: name,
              reason: reason,
              appliedAt: appliedAt,
              roleService: _roleService,
            );
          },
        );
      },
    );
  }
}

// ── Başvuru kartı ─────────────────────────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final String uid;
  final String name;
  final String reason;
  final DateTime? appliedAt;
  final RoleService roleService;

  const _RequestCard({
    required this.uid,
    required this.name,
    required this.reason,
    required this.appliedAt,
    required this.roleService,
  });

  String get _dateStr => appliedAt != null
      ? '${appliedAt!.day}.${appliedAt!.month}.${appliedAt!.year}'
      : '—';

  Future<void> _handle(BuildContext ctx, bool approve) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          approve ? '✅ Admin Onayla' : '❌ Başvuruyu Reddet',
          style: GoogleFonts.playfairDisplay(
              color: Colors.white, fontSize: 18),
        ),
        content: Text(
          approve
              ? '"$name" adlı kullanıcıya admin yetkisi verilecek.'
              : '"$name" adlı kullanıcının başvurusu reddedilecek.',
          style:
              GoogleFonts.notoSans(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('İptal',
                  style: GoogleFonts.notoSans(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  approve ? const Color(0xFF2E7D32) : Colors.red.shade700,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
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
        await roleService.approveAdmin(uid);
      } else {
        await roleService.rejectAdmin(uid);
      }
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(approve
              ? '✅ $name artık admin'
              : '❌ Başvuru reddedildi'),
          backgroundColor:
              approve ? const Color(0xFF2E7D32) : Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(
              'Hata: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext ctx) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF141B2D),
        borderRadius: BorderRadius.circular(18),
        border:
            Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        colors: [AppColors.gold, AppColors.turquoise]),
                  ),
                  child: Center(
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 16,
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
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Row(children: [
                        const Icon(Icons.schedule_rounded,
                            color: Colors.white38, size: 11),
                        const SizedBox(width: 3),
                        Text(_dateStr,
                            style: GoogleFonts.notoSans(
                                color: Colors.white38, fontSize: 11)),
                      ]),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded,
                      color: Colors.white24, size: 16),
                  tooltip: 'UID kopyala',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: uid));
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(
                          content: Text('UID kopyalandı'),
                          duration: Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating),
                    );
                  },
                ),
              ],
            ),
          ),
          if (reason.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.07)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Başvuru Sebebi',
                        style: GoogleFonts.notoSans(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.7)),
                    const SizedBox(height: 4),
                    Text(reason,
                        style: GoogleFonts.notoSans(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.4)),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close_rounded,
                        size: 16, color: Colors.red),
                    label: Text('Reddet',
                        style: GoogleFonts.notoSans(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _handle(ctx, false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white),
                    label: Text('Onayla',
                        style: GoogleFonts.notoSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    onPressed: () => _handle(ctx, true),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// Sayfa 2 — Tüm Kullanıcılar
// ════════════════════════════════════════════════════════════════════════════

class _UsersPage extends StatefulWidget {
  const _UsersPage();

  @override
  State<_UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<_UsersPage> {
  Stream<QuerySnapshot>? _stream;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await FirebaseAuth.instance.currentUser
          ?.getIdToken(true)
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _stream =
          FirebaseFirestore.instance.collection('users').snapshots();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearch(),
        if (_stream != null)
          StreamBuilder<QuerySnapshot>(
            stream: _stream,
            builder: (_, snap) {
              final count = snap.data?.docs.length ?? 0;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Row(
                  children: [
                    _chip('👥 $count kullanıcı', AppColors.gold),
                  ],
                ),
              );
            },
          ),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: TextField(
        onChanged: (v) => setState(() => _q = v.toLowerCase()),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Ad, e-posta veya telefon ara...',
          hintStyle:
              const TextStyle(color: Colors.white30, fontSize: 13),
          prefixIcon:
              const Icon(Icons.search_rounded, color: Colors.white38),
          suffixIcon: _q.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded,
                      color: Colors.white38),
                  onPressed: () => setState(() => _q = ''))
              : null,
          filled: true,
          fillColor: const Color(0xFF1A2035),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide:
                  const BorderSide(color: AppColors.gold, width: 1.5)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(label,
            style: GoogleFonts.notoSans(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );

  Widget _buildList() {
    if (_stream == null) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting &&
            !snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.gold));
        }
        if (snap.hasError) {
          return _ErrorView(
              message: 'Kullanıcılar yüklenemedi:\n${snap.error}',
              onRetry: _init);
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const _EmptyView(
              icon: Icons.people_outline, title: 'Henüz kullanıcı yok');
        }

        var docs = snap.data!.docs;
        if (_q.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final n = (data['nameSurname'] ?? '').toString().toLowerCase();
            final e = (data['email'] ?? '').toString().toLowerCase();
            final p = (data['phone'] ?? '').toString().toLowerCase();
            return n.contains(_q) || e.contains(_q) || p.contains(_q);
          }).toList();
        }

        if (docs.isEmpty) {
          return _EmptyView(
              icon: Icons.search_off_rounded,
              title: 'Sonuç bulunamadı',
              subtitle: '"$_q" için eşleşme yok');
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _UserCard(uid: docs[i].id, data: data);
          },
        );
      },
    );
  }
}

// ── Kullanıcı kartı ───────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> data;
  const _UserCard({required this.uid, required this.data});

  @override
  Widget build(BuildContext ctx) {
    final name = data['nameSurname'] ?? 'İsimsiz';
    final email = data['email'] ?? '';
    final streak = data['streakDays'] as int? ?? 0;
    final quranDays = data['quranReadDays'] as int? ?? 0;
    final missed = (data['missedQuranDays'] as List?)?.length ?? 0;
    final createdAtRaw = data['createdAt'];
    final createdAt = createdAtRaw is Timestamp
        ? createdAtRaw.toDate()
        : DateTime.tryParse(createdAtRaw?.toString() ?? '') ??
            DateTime.now();
    final daysSince = DateTime.now().difference(createdAt).inDays;
    final hasMissed = missed > 3;

    return GestureDetector(
      onTap: () => Navigator.push(
          ctx,
          MaterialPageRoute(
              builder: (_) =>
                  UserDetailScreen(uid: uid, name: name.toString()))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141B2D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasMissed
                ? Colors.red.withValues(alpha: 0.35)
                : AppColors.gold.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: hasMissed
                      ? [Colors.red.shade700, Colors.orange.shade700]
                      : [AppColors.gold, AppColors.turquoise],
                ),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name.toString()[0].toUpperCase() : '?',
                  style: GoogleFonts.playfairDisplay(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.toString(),
                      style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  if (email.isNotEmpty)
                    Text(email.toString(),
                        style: GoogleFonts.notoSans(
                            color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _mini('🔥 $streak', Colors.orange),
                      const SizedBox(width: 6),
                      _mini('📖 $quranDays', AppColors.turquoise),
                      if (missed > 0) ...[
                        const SizedBox(width: 6),
                        _mini('⚠ $missed', Colors.red),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$daysSince gün',
                    style: GoogleFonts.notoSans(
                        color: Colors.white24, fontSize: 10)),
                const SizedBox(height: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: Colors.white24, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mini(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(label,
            style: GoogleFonts.notoSans(
                color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      );
}

// ════════════════════════════════════════════════════════════════════════════
// Paylaşılan yardımcı widgetlar
// ════════════════════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _ErrorView({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.1)),
              child: const Icon(Icons.error_outline_rounded,
                  color: Colors.red, size: 48),
            ),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSans(
                    color: Colors.red.shade300,
                    fontSize: 13,
                    height: 1.5)),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Tekrar Dene'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  const _EmptyView(
      {required this.icon, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
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
              child: Icon(icon, color: Colors.white24, size: 40),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: GoogleFonts.playfairDisplay(
                    color: Colors.white54,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                      color: Colors.white30,
                      fontSize: 12,
                      height: 1.5)),
            ],
          ],
        ),
      ),
    );
  }
}
