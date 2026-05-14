import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/role_service.dart';
import 'community_screen.dart';

class CommunityJoinScreen extends StatefulWidget {
  const CommunityJoinScreen({super.key});

  @override
  State<CommunityJoinScreen> createState() => _CommunityJoinScreenState();
}

class _CommunityJoinScreenState extends State<CommunityJoinScreen> {
  final _roleService = RoleService();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  bool _isLoading = false;
  bool _showAdminApply = false;
  String? _joinedCommunityId;

  @override
  void initState() {
    super.initState();
    _checkExistingCommunity();
  }

  Future<void> _checkExistingCommunity() async {
    // Kullanıcının zaten üye olduğu topluluk var mı?
    _roleService.getUserCommunities().listen((snap) {
      if (snap.docs.isNotEmpty && mounted) {
        // members subcollection'dan community ID'yi al
        final ref = snap.docs.first.reference;
        final communityId = ref.parent.parent?.id;
        if (communityId != null) {
          setState(() => _joinedCommunityId = communityId);
        }
      }
    });
  }

  Future<void> _joinCommunity() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await _roleService.joinCommunity(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Topluluğa katıldınız!'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
      _checkExistingCommunity();
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
                    Text(
                      'Topluluk',
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.gold,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Zaten üyeyse direkt aç
                  if (_joinedCommunityId != null) ...[
                    _buildCard(
                      child: Column(
                        children: [
                          const Icon(Icons.group,
                              color: AppColors.gold, size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Topluluğunuz hazır',
                            style: GoogleFonts.playfairDisplay(
                              color: AppColors.gold,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.forum_outlined,
                                  color: Colors.white),
                              label: Text(
                                'Kanala Git',
                                style: GoogleFonts.notoSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => CommunityScreen(
                                      communityId: _joinedCommunityId!),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Davet koduyla katıl
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.vpn_key,
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
                            ],
                          ),
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
                                borderSide:
                                    const BorderSide(color: Colors.white24),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
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
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Admin başvurusu
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
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

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
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
