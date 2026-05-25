import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/role_service.dart';
import 'community_screen.dart';
import 'admin_dashboard_screen.dart';
import 'owner_panel_screen.dart' show CommunityOwnerPanelScreen;

class CommunityJoinScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const CommunityJoinScreen({super.key, this.onBack});

  @override
  State<CommunityJoinScreen> createState() => _CommunityJoinScreenState();
}

class _CommunityJoinScreenState extends State<CommunityJoinScreen> {
  final _roleService = RoleService();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  bool _isLoading = false;
  bool _showJoinForm = false;
  bool _showAdminApply = false;
  bool _showCreateForm = false;
  UserRole _userRole = UserRole.user;
  StreamSubscription<DocumentSnapshot>? _roleSub;
  final _communityNameCtrl = TextEditingController();
  final _communityDescCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkRole().then((_) {
      if (mounted) _listenRoleChanges();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _checkRole();
  }

  @override
  void dispose() {
    _roleSub?.cancel();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _reasonCtrl.dispose();
    _communityNameCtrl.dispose();
    _communityDescCtrl.dispose();
    super.dispose();
  }

  // Rol değişikliklerini gerçek zamanlı dinle (admin onaylandığında otomatik güncelle)
  void _listenRoleChanges() {
    if (_roleSub != null) return; // zaten dinleniyor
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    _roleSub = FirebaseFirestore.instance
        .collection('roles')
        .doc(uid)
        .snapshots()
        .listen((doc) async {
      if (!mounted) return;
      if (doc.exists && doc.data()?['role'] == 'admin') {
        final wasNotAdmin = _userRole != UserRole.admin;
        setState(() => _userRole = UserRole.admin);
        if (wasNotAdmin) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Admin yetkiniz onaylandı!',
                style: GoogleFonts.notoSans(color: Colors.white),
              ),
              backgroundColor: const Color(0xFF2E7D32),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    }, onError: (_) {});
  }

  Future<void> _checkRole() async {
    final role = await _roleService.getCurrentRole();
    if (mounted) setState(() => _userRole = role);
  }

  Future<void> _joinCommunity() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // inviteLookup'tan communityId bul (inviteCode artık communities belgesinde değil)
      final lookupDoc = await FirebaseFirestore.instance
          .collection('inviteLookup')
          .doc(code)
          .get();

      if (!lookupDoc.exists) {
        throw Exception('Geçersiz davet kodu');
      }

      final communityId = lookupDoc.data()?['communityId'] as String?;
      if (communityId == null) throw Exception('Geçersiz davet kodu');

      final communityDoc = await FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .get();

      if (!communityDoc.exists) throw Exception('Topluluk bulunamadı');

      final communityData = communityDoc.data()!;
      final communityName = communityData['name'] as String? ?? 'Topluluk';
      final communityDesc = communityData['description'] as String? ?? '';
      final memberCount = communityData['memberCount'] as int? ?? 0;

      if (!mounted) return;
      setState(() => _isLoading = false);

      // Önizleme modalı göster
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: const Color(0xFF1A2035),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Text('Topluluğa Katıl',
                  style: GoogleFonts.playfairDisplay(
                      color: AppColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(communityName,
                        style: GoogleFonts.playfairDisplay(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    if (communityDesc.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(communityDesc,
                          style: GoogleFonts.notoSans(
                              color: Colors.white54, fontSize: 13)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.group_outlined,
                            color: AppColors.turquoise, size: 16),
                        const SizedBox(width: 6),
                        Text('$memberCount üye',
                            style: GoogleFonts.notoSans(
                                color: AppColors.turquoise, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Bu topluluğa katılmak istiyor musunuz?',
                  style:
                      GoogleFonts.notoSans(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx, false),
                      child: Text('Vazgeç',
                          style:
                              GoogleFonts.notoSans(color: Colors.white54)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.turquoise,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text('Katıl',
                          style: GoogleFonts.notoSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

      if (confirmed != true) return;

      setState(() => _isLoading = true);
      await _roleService.joinCommunity(code);
      if (!mounted) return;
      _codeCtrl.clear();
      setState(() => _showJoinForm = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Topluluğa katıldınız!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createCommunity() async {
    final name = _communityNameCtrl.text.trim();
    final desc = _communityDescCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _roleService.createCommunity(name: name, description: desc);
      if (!mounted) return;
      _communityNameCtrl.clear();
      _communityDescCtrl.clear();
      setState(() => _showCreateForm = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Topluluk başarıyla oluşturuldu!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _applyForAdmin() async {
    final name = _nameCtrl.text.trim();
    final reason = _reasonCtrl.text.trim();
    if (name.isEmpty || reason.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _roleService.applyForAdmin(name: name, reason: reason);
      if (!mounted) return;
      setState(() => _showAdminApply = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Başvurunuz iletildi, onay bekleniyor'),
          backgroundColor: AppColors.turquoise,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Başlık
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
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
                      onPressed: () {
                        if (widget.onBack != null) {
                          widget.onBack!();
                        } else {
                          Navigator.maybePop(context);
                        }
                      },
                    ),
                    Expanded(
                      child: Text(
                        'Topluluk',
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.gold,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Owner panel hızlı erişimi
                    if (_userRole == UserRole.owner)
                      TextButton.icon(
                        icon: const Icon(Icons.shield_outlined,
                            color: AppColors.gold, size: 16),
                        label: Text(
                          'Sahip Paneli',
                          style: GoogleFonts.notoSans(
                              color: AppColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const CommunityOwnerPanelScreen()),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Üye olunan topluluklar listesi ──────────────────────
                  StreamBuilder<QuerySnapshot>(
                    stream: _roleService.getUserCommunities(),
                    builder: (_, snap) {
                      if (snap.hasError) return _buildEmptyState();
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return _buildEmptyState();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 4, bottom: 12),
                            child: Text(
                              'TOPLULUKLARIM',
                              style: GoogleFonts.notoSans(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.4,
                              ),
                            ),
                          ),
                          ...docs.map((memberDoc) {
                            final communityId =
                                memberDoc.reference.parent.parent?.id;
                            if (communityId == null) {
                              return const SizedBox.shrink();
                            }
                            final memberData =
                                memberDoc.data() as Map<String, dynamic>;
                            final isAdminOfThis =
                                memberData['role'] == 'admin';
                            return _CommunityCard(
                              communityId: communityId,
                              isAdminOfThis: isAdminOfThis,
                            );
                          }),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // ── Admin/Owner: Topluluk Oluştur ──────────────────────
                  if (_userRole == UserRole.admin || _userRole == UserRole.owner) ...[
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => setState(
                                () => _showCreateForm = !_showCreateForm),
                            child: Row(
                              children: [
                                const Icon(Icons.add_business_outlined,
                                    color: AppColors.gold, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Topluluk Oluştur',
                                  style: GoogleFonts.playfairDisplay(
                                    color: AppColors.gold,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  _showCreateForm
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: Colors.white38,
                                ),
                              ],
                            ),
                          ),
                          if (_showCreateForm) ...[
                            const SizedBox(height: 14),
                            _field(_communityNameCtrl, 'Topluluk Adı',
                                Icons.group_outlined),
                            const SizedBox(height: 10),
                            _field(
                              _communityDescCtrl,
                              'Açıklama (isteğe bağlı)',
                              Icons.description_outlined,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _createCommunity,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2),
                                      )
                                    : Text(
                                        'Oluştur',
                                        style: GoogleFonts.notoSans(
                                            color: Colors.black,
                                            fontWeight: FontWeight.bold),
                                      ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Herkes: Topluluğa Katıl (davet kodu) ───────────────
                  _buildCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () => setState(
                              () => _showJoinForm = !_showJoinForm),
                          child: Row(
                            children: [
                              const Icon(Icons.add_circle_outline,
                                  color: AppColors.turquoise, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Topluluğa Katıl',
                                style: GoogleFonts.playfairDisplay(
                                  color: AppColors.gold,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _showJoinForm
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: Colors.white38,
                              ),
                            ],
                          ),
                        ),
                        if (_showJoinForm) ...[
                          const SizedBox(height: 14),
                          TextField(
                            controller: _codeCtrl,
                            textCapitalization: TextCapitalization.characters,
                            style: GoogleFonts.notoSans(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Davet Kodu (8 hane)',
                              hintStyle: const TextStyle(
                                  color: Colors.white38, letterSpacing: 1),
                              enabledBorder: OutlineInputBorder(
                                borderSide: const BorderSide(
                                    color: Colors.white24),
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
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _joinCommunity,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.turquoise,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2),
                                    )
                                  : Text(
                                      'Katıl',
                                      style: GoogleFonts.notoSans(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Sadece normal kullanıcılar: Admin Başvurusu ─────────
                  if (_userRole == UserRole.user) ...[
                    const SizedBox(height: 12),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () => setState(
                                () => _showAdminApply = !_showAdminApply),
                            child: Row(
                              children: [
                                const Icon(Icons.admin_panel_settings,
                                    color: AppColors.gold, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Admin Başvurusu',
                                  style: GoogleFonts.playfairDisplay(
                                    color: AppColors.gold,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                Icon(
                                  _showAdminApply
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: Colors.white38,
                                ),
                              ],
                            ),
                          ),
                          if (_showAdminApply) ...[
                            const SizedBox(height: 14),
                            Text(
                              'Topluluk kurabilmek için admin yetkisi gereklidir. Başvurunuz uygulama sahibine iletilecektir.',
                              style: GoogleFonts.notoSans(
                                  color: Colors.white54, fontSize: 12),
                            ),
                            const SizedBox(height: 12),
                            _field(_nameCtrl, 'Adınız Soyadınız',
                                Icons.person_outline),
                            const SizedBox(height: 10),
                            _field(
                              _reasonCtrl,
                              'Neden admin olmak istiyorsunuz?',
                              Icons.edit_note,
                              maxLines: 4,
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _applyForAdmin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                child: Text(
                                  'Başvur',
                                  style: GoogleFonts.notoSans(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2035),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.15)),
          ),
          child: Column(
            children: [
              const Icon(Icons.group_outlined,
                  color: Colors.white24, size: 48),
              const SizedBox(height: 12),
              Text(
                'Henüz bir topluluğa katılmadınız',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSans(
                    color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                'Davet kodunuz varsa aşağıdan katılabilirsiniz.',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSans(
                    color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: child,
    );
  }

  Widget _field(
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
}

// ── Topluluk kartı (isim + üye sayısı + Kanala Git + Yönet) ─────────────────

class _CommunityCard extends StatelessWidget {
  final String communityId;
  final bool isAdminOfThis;

  const _CommunityCard({
    required this.communityId,
    required this.isAdminOfThis,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .snapshots(),
      builder: (_, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final name = data['name'] as String? ?? 'Topluluk';
        final desc = data['description'] as String? ?? '';
        final memberCount = data['memberCount'] as int? ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isAdminOfThis
                  ? [
                      AppColors.gold.withValues(alpha: 0.12),
                      const Color(0xFF1A2035),
                    ]
                  : [
                      AppColors.turquoise.withValues(alpha: 0.08),
                      const Color(0xFF1A2035),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAdminOfThis
                  ? AppColors.gold.withValues(alpha: 0.35)
                  : AppColors.turquoise.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isAdminOfThis ? AppColors.gold : AppColors.turquoise)
                          .withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isAdminOfThis
                          ? Icons.admin_panel_settings_outlined
                          : Icons.group_outlined,
                      color: isAdminOfThis
                          ? AppColors.gold
                          : AppColors.turquoise,
                      size: 20,
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
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.people_outline,
                                color: Colors.white38, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '$memberCount üye',
                              style: GoogleFonts.notoSans(
                                  color: Colors.white38, fontSize: 12),
                            ),
                            if (isAdminOfThis) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.gold.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Yönetici',
                                  style: GoogleFonts.notoSans(
                                      color: AppColors.gold, fontSize: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (desc.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  desc,
                  style: GoogleFonts.notoSans(
                      color: Colors.white54, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.forum_outlined,
                          size: 16, color: AppColors.turquoise),
                      label: Text(
                        'Kanala Git',
                        style: GoogleFonts.notoSans(
                            color: AppColors.turquoise,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: AppColors.turquoise.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CommunityScreen(communityId: communityId),
                        ),
                      ),
                    ),
                  ),
                  if (isAdminOfThis) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.settings_outlined,
                            size: 16, color: Colors.black),
                        label: Text(
                          'Yönet',
                          style: GoogleFonts.notoSans(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 13),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminDashboardScreen(
                                communityId: communityId),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
