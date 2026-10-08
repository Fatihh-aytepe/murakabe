import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/legal_links.dart';
import '../../core/services/consent_service.dart';
import '../../core/services/firestore_notification_service.dart';
import '../../core/services/notification_service.dart';
import '../../data/local/local_storage.dart';
import '../../data/remote/firebase_service.dart';
import '../home/home_screen.dart';
import 'login_screen.dart';

/// Güncel Kullanım Koşulları, Gizlilik Politikası ve KVKK açık rıza
/// metinlerini onaylamamış kullanıcılara (eski kullanıcılar dahil) gösterilir.
/// Onay verilmeden uygulamaya girilemez; kullanıcı ya onaylar ya çıkış yapar.
/// Bkz. HomeScreen._enforceConsent.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _acceptTerms = false;
  bool _acceptConsent = false;
  bool _busy = false;

  Future<void> _accept() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      await _logout();
      return;
    }
    setState(() => _busy = true);
    await ConsentService.recordAcceptance(uid);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  Future<void> _logout() async {
    setState(() => _busy = true);
    final uid = LocalStorage().userId ?? '';
    try {
      await FirebaseService().signOut();
    } catch (_) {}
    FirestoreNotificationService().stop();
    try {
      await NotificationService().cancelAll();
    } catch (_) {}
    if (uid.isNotEmpty) await LocalStorage().markAccountLoggedOut(uid);
    await LocalStorage().setUserRegistered(false);
    await LocalStorage().clearUserId();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Widget _check({
    required bool value,
    required ValueChanged<bool> onChanged,
    required String text,
  }) {
    return InkWell(
      onTap: _busy ? null : () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: Checkbox(
                value: value,
                onChanged: _busy ? null : (v) => onChanged(v ?? false),
                activeColor: AppColors.gold,
                checkColor: Colors.black,
                side: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.6), width: 1.4),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(text,
                    style: GoogleFonts.notoSans(
                        color: Colors.white70, fontSize: 13.5, height: 1.45)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _link(String label, String url) {
    return InkWell(
      onTap: () => LegalLinks.open(context, url),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            const Icon(Icons.description_outlined,
                color: AppColors.turquoiseLight, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: GoogleFonts.notoSans(
                      color: Colors.white, fontSize: 14.5)),
            ),
            const Icon(Icons.open_in_new, color: Colors.white38, size: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _acceptTerms && _acceptConsent && !_busy;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D1B2A), Color(0xFF1B2A3B), Color(0xFF0A1628)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              children: [
                const Icon(Icons.verified_user_outlined,
                    color: AppColors.gold, size: 40),
                const SizedBox(height: 16),
                Text('Devam etmeden önce',
                    style: GoogleFonts.playfairDisplay(
                        color: AppColors.gold,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Text(
                  'Murakabe\'yi kullanmaya devam etmek için kullanım şartlarımızı '
                  've verilerinin nasıl işlendiğini anlatan metinleri onaylaman '
                  'gerekiyor. Metinleri aşağıdan okuyabilirsin.',
                  style: GoogleFonts.notoSans(
                      color: Colors.white60, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    children: [
                      _link('Kullanım Koşulları', LegalLinks.terms),
                      const Divider(color: Colors.white10, height: 1),
                      _link('Gizlilik Politikası', LegalLinks.privacy),
                      const Divider(color: Colors.white10, height: 1),
                      _link('KVKK Aydınlatma Metni', LegalLinks.kvkk),
                      const Divider(color: Colors.white10, height: 1),
                      _link('Açık Rıza Metni', LegalLinks.consent),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _check(
                  value: _acceptTerms,
                  onChanged: (v) => setState(() => _acceptTerms = v),
                  text: 'Kullanım Koşulları\'nı ve Gizlilik Politikası\'nı okudum '
                      've kabul ediyorum. KVKK Aydınlatma Metni\'ni okudum.',
                ),
                _check(
                  value: _acceptConsent,
                  onChanged: (v) => setState(() => _acceptConsent = v),
                  text: 'İbadet kayıtlarımın işlenmesine ve verilerimin yurt '
                      'dışındaki sunucularda saklanmasına ilişkin Açık Rıza '
                      'Metni\'ni onaylıyorum.',
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: canContinue ? _accept : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor:
                          AppColors.gold.withValues(alpha: 0.25),
                      disabledForegroundColor: Colors.black45,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2))
                        : Text('Onayla ve devam et',
                            style: GoogleFonts.notoSans(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy ? null : _logout,
                  child: Text('Onaylamıyorum, çıkış yap',
                      style: GoogleFonts.notoSans(
                          color: Colors.white38, fontSize: 13)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
