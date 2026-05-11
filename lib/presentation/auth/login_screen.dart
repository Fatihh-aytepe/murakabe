import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../data/local/local_storage.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/remote/firebase_service.dart';
import '../home/home_screen.dart';
import '../admin/admin_panel_screen.dart';
import '../profile/profile_setup_screen.dart';
import '../../core/utils/permission_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Kayıt alanları
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPassController = TextEditingController();
  final _registerPassConfirmController = TextEditingController();

  // Giriş alanları
  final _loginEmailController = TextEditingController();
  final _loginPassController = TextEditingController();

  bool _isLoading = false;
  bool _registerPassVisible = false;
  bool _registerPassConfirmVisible = false;
  bool _loginPassVisible = false;

  // Hata mesajları
  String? _nameError;
  String? _phoneError;
  String? _registerEmailError;
  String? _registerPassError;
  String? _registerPassConfirmError;
  String? _loginEmailError;
  String? _loginPassError;

  // Admin gizli giriş
  int _tapCount = 0;
  bool _showAdminFields = false;
  final _adminEmailController = TextEditingController();
  final _adminPassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    PermissionHelper.requestAllPermissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _registerEmailController.dispose();
    _registerPassController.dispose();
    _registerPassConfirmController.dispose();
    _loginEmailController.dispose();
    _loginPassController.dispose();
    _adminEmailController.dispose();
    _adminPassController.dispose();
    super.dispose();
  }

  // ─── DOĞRULAMA ────────────────────────────────────────────────────────────

  bool _validateEmail(String email) {
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email.trim());
  }

  bool _validatePhone(String phone) {
    // Türkiye formatı: 05xx xxx xx xx — sadece rakam, 11 hane, 05 ile başlar
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11 && digits.startsWith('05');
  }

  bool _validatePassword(String pass) {
    // En az 8 karakter, 1 büyük harf, 1 küçük harf, 1 rakam
    if (pass.length < 8) return false;
    if (!pass.contains(RegExp(r'[A-Z]'))) return false;
    if (!pass.contains(RegExp(r'[a-z]'))) return false;
    if (!pass.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }

  bool _validateRegisterForm() {
    bool valid = true;
    setState(() {
      _nameError = null;
      _phoneError = null;
      _registerEmailError = null;
      _registerPassError = null;
      _registerPassConfirmError = null;

      if (_nameController.text.trim().length < 2) {
        _nameError = 'Ad soyad en az 2 karakter olmalı';
        valid = false;
      }
      if (!_validatePhone(_phoneController.text)) {
        _phoneError = 'Geçerli telefon: 05xx xxx xx xx (11 rakam)';
        valid = false;
      }
      if (!_validateEmail(_registerEmailController.text)) {
        _registerEmailError = 'Geçerli bir e-posta girin (örn: ad@site.com)';
        valid = false;
      }
      if (!_validatePassword(_registerPassController.text)) {
        _registerPassError =
            'En az 8 karakter, büyük/küçük harf ve rakam içermeli';
        valid = false;
      }
      if (_registerPassController.text != _registerPassConfirmController.text) {
        _registerPassConfirmError = 'Şifreler eşleşmiyor';
        valid = false;
      }
    });
    return valid;
  }

  bool _validateLoginForm() {
    bool valid = true;
    setState(() {
      _loginEmailError = null;
      _loginPassError = null;

      if (!_validateEmail(_loginEmailController.text)) {
        _loginEmailError = 'Geçerli bir e-posta girin';
        valid = false;
      }
      if (_loginPassController.text.length < 6) {
        _loginPassError = 'Şifre en az 6 karakter olmalı';
        valid = false;
      }
    });
    return valid;
  }

  // ─── KAYIT ────────────────────────────────────────────────────────────────

  Future<void> _handleRegister() async {
    if (!_validateRegisterForm()) return;
    setState(() => _isLoading = true);

    try {
      await UserRepository().createUser(
        nameSurname: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _registerEmailController.text.trim(),
        password: _registerPassController.text,
      );

      if (!mounted) return;
      // Doğrulama maili gönderildi — bekleme ekranına git
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(
            email: _registerEmailController.text.trim(),
          ),
        ),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = _parseFirebaseError(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── GİRİŞ ────────────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
    // Admin gizli girişi
    if (_showAdminFields &&
        _adminEmailController.text == AppStrings.adminEmail &&
        _adminPassController.text == AppStrings.adminPassword) {
      await LocalStorage().setAdmin(true);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
      );
      return;
    }

    if (!_validateLoginForm()) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseService().signInWithEmail(
        email: _loginEmailController.text.trim(),
        password: _loginPassController.text,
      );

      final authUser = FirebaseService().currentAuthUser;
      if (authUser == null) throw Exception('Giriş başarısız');

      // E-posta doğrulandı mı?
      await authUser.reload();
      if (!authUser.emailVerified) {
        if (!mounted) return;
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(
              email: _loginEmailController.text.trim(),
            ),
          ),
        );
        return;
      }

      // Kullanıcı yerel kayıtlı mı?
      final stored = LocalStorage().userId;
      if (stored == null || stored != authUser.uid) {
        // İlk giriş — yerel kayıt yok → profil kurulum
        await LocalStorage().setUserId(authUser.uid);
        await LocalStorage().setUserRegistered(true);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on Exception catch (e) {
      if (!mounted) return;
      final msg = _parseFirebaseError(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade700,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseFirebaseError(String error) {
    if (error.contains('email-already-in-use')) {
      return 'Bu e-posta zaten kayıtlı. Giriş yapın.';
    } else if (error.contains('wrong-password') ||
        error.contains('invalid-credential')) {
      return 'E-posta veya şifre hatalı.';
    } else if (error.contains('user-not-found')) {
      return 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
    } else if (error.contains('network-request-failed')) {
      return 'İnternet bağlantısı yok. Lütfen tekrar deneyin.';
    } else if (error.contains('too-many-requests')) {
      return 'Çok fazla deneme yapıldı. Lütfen biraz bekleyin.';
    }
    return 'Bir hata oluştu. Lütfen tekrar deneyin.';
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Üst logo bölümü
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _tapCount++;
                        if (_tapCount >= 7) {
                          setState(() => _showAdminFields = true);
                        }
                      },
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Image.asset('assets/images/logo.png',
                              fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      AppStrings.appName,
                      style: GoogleFonts.playfairDisplay(
                        fontSize: 28,
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                      style: GoogleFonts.amiri(
                        fontSize: 16,
                        color: AppColors.gold.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Tab bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.white60,
                        labelStyle: GoogleFonts.notoSans(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        tabs: const [
                          Tab(text: 'Kayıt Ol'),
                          Tab(text: 'Giriş Yap'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Form içeriği
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildRegisterTab(),
                    _buildLoginTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── KAYIT FORMU ──────────────────────────────────────────────────────────

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildField(
            controller: _nameController,
            label: 'Ad Soyad',
            icon: Icons.person_outline,
            errorText: _nameError,
            onChanged: (_) => setState(() => _nameError = null),
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _phoneController,
            label: 'Telefon (05xx xxx xx xx)',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            errorText: _phoneError,
            onChanged: (_) => setState(() => _phoneError = null),
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _registerEmailController,
            label: 'E-posta',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            errorText: _registerEmailError,
            onChanged: (_) => setState(() => _registerEmailError = null),
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _registerPassController,
            label: 'Şifre',
            icon: Icons.lock_outline,
            obscure: !_registerPassVisible,
            suffixIcon: IconButton(
              icon: Icon(
                _registerPassVisible ? Icons.visibility_off : Icons.visibility,
                color: AppColors.gold.withValues(alpha: 0.6),
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _registerPassVisible = !_registerPassVisible),
            ),
            errorText: _registerPassError,
            helperText: 'En az 8 karakter, büyük/küçük harf ve rakam',
            onChanged: (_) => setState(() => _registerPassError = null),
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _registerPassConfirmController,
            label: 'Şifre Tekrar',
            icon: Icons.lock_outline,
            obscure: !_registerPassConfirmVisible,
            suffixIcon: IconButton(
              icon: Icon(
                _registerPassConfirmVisible
                    ? Icons.visibility_off
                    : Icons.visibility,
                color: AppColors.gold.withValues(alpha: 0.6),
                size: 20,
              ),
              onPressed: () => setState(() =>
                  _registerPassConfirmVisible = !_registerPassConfirmVisible),
            ),
            errorText: _registerPassConfirmError,
            onChanged: (_) => setState(() => _registerPassConfirmError = null),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2),
                    )
                  : Text('Hesap Oluştur',
                      style: GoogleFonts.notoSans(
                          fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Kayıt olduktan sonra e-postanıza doğrulama linki gönderilecektir.',
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── GİRİŞ FORMU ──────────────────────────────────────────────────────────

  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildField(
            controller: _loginEmailController,
            label: 'E-posta',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            errorText: _loginEmailError,
            onChanged: (_) => setState(() => _loginEmailError = null),
          ),
          const SizedBox(height: 14),
          _buildField(
            controller: _loginPassController,
            label: 'Şifre',
            icon: Icons.lock_outline,
            obscure: !_loginPassVisible,
            suffixIcon: IconButton(
              icon: Icon(
                _loginPassVisible ? Icons.visibility_off : Icons.visibility,
                color: AppColors.gold.withValues(alpha: 0.6),
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _loginPassVisible = !_loginPassVisible),
            ),
            errorText: _loginPassError,
            onChanged: (_) => setState(() => _loginPassError = null),
          ),
          if (_showAdminFields) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.orange),
            const SizedBox(height: 8),
            Text('Admin Girişi',
                style: GoogleFonts.notoSans(
                    color: Colors.orange, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildField(
              controller: _adminEmailController,
              label: 'Admin E-posta',
              icon: Icons.admin_panel_settings,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _adminPassController,
              label: 'Admin Şifre',
              icon: Icons.lock_outline,
              obscure: true,
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.black, strokeWidth: 2),
                    )
                  : Text('Giriş Yap',
                      style: GoogleFonts.notoSans(
                          fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: _isLoading
                ? null
                : () async {
                    final email = _loginEmailController.text.trim();
                    if (!_validateEmail(email)) {
                      setState(
                          () => _loginEmailError = 'Önce e-postanızı girin');
                      return;
                    }
                    try {
                      await FirebaseService().resetPassword(
                        _loginEmailController.text.trim(),
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Şifre sıfırlama maili gönderildi')),
                      );
                    } catch (_) {}
                  },
            child: Text(
              'Şifremi Unuttum',
              style: GoogleFonts.notoSans(
                  color: AppColors.turquoiseLight, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ORTAK FIELD ──────────────────────────────────────────────────────────

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? errorText,
    String? helperText,
    List<TextInputFormatter>? inputFormatters,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.gold.withValues(alpha: 0.8)),
        prefixIcon: Icon(icon, color: AppColors.turquoise, size: 20),
        suffixIcon: suffixIcon,
        errorText: errorText,
        errorStyle:
            GoogleFonts.notoSans(fontSize: 11, color: Colors.red.shade300),
        helperText: helperText,
        helperStyle: GoogleFonts.notoSans(fontSize: 10, color: Colors.white38),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: errorText != null
                ? Colors.red.shade400
                : AppColors.gold.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: errorText != null ? Colors.red.shade400 : AppColors.gold,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade400),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }
}

// ─── E-POSTA DOĞRULAMA BEKLEME EKRANI ─────────────────────────────────────

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isChecking = false;
  bool _resent = false;

  Future<void> _checkVerified() async {
    setState(() => _isChecking = true);
    try {
      final verified = await UserRepository().syncEmailVerified();
      if (!mounted) return;
      if (verified) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'E-posta henüz doğrulanmamış. Gelen kutunuzu kontrol edin.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  Future<void> _resend() async {
    await FirebaseService().resendVerificationEmail();
    if (!mounted) return;
    setState(() => _resent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Doğrulama maili tekrar gönderildi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.15),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.mark_email_unread_outlined,
                      color: AppColors.gold, size: 56),
                ),
                const SizedBox(height: 32),
                Text(
                  'E-postanızı Doğrulayın',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 24,
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${widget.email}\nadresine doğrulama linki gönderdik.\nLinke tıkladıktan sonra aşağıdaki butona basın.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                      color: Colors.white70, fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _checkVerified,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isChecking
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2),
                          )
                        : Text('Doğruladım, Devam Et',
                            style: GoogleFonts.notoSans(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _resent ? null : _resend,
                  icon: Icon(Icons.refresh,
                      color:
                          _resent ? Colors.white24 : AppColors.turquoiseLight,
                      size: 18),
                  label: Text(
                    _resent ? 'Mail gönderildi' : 'Tekrar Gönder',
                    style: GoogleFonts.notoSans(
                      color:
                          _resent ? Colors.white24 : AppColors.turquoiseLight,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
