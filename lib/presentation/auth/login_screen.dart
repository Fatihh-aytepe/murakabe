import 'dart:async';
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

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPassController = TextEditingController();
  final _registerPassConfirmController = TextEditingController();

  final _loginEmailController = TextEditingController();
  final _loginPassController = TextEditingController();

  bool _isLoading = false;
  bool _registerPassVisible = false;
  bool _registerPassConfirmVisible = false;
  bool _loginPassVisible = false;

  String? _nameError;
  String? _phoneError;
  String? _registerEmailError;
  String? _registerPassError;
  String? _registerPassConfirmError;
  String? _loginEmailError;
  String? _loginPassError;

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

  // ── Hata dialog'u ─────────────────────────────────────────────────────────

  void _showErrorDialog(String message, {bool isSuccess = false}) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2035),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSuccess
                  ? Colors.green.withValues(alpha: 0.5)
                  : Colors.red.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: (isSuccess ? Colors.green : Colors.red)
                    .withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (isSuccess ? Colors.green : Colors.red)
                      .withValues(alpha: 0.15),
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                  color: isSuccess ? Colors.green : Colors.red.shade300,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isSuccess ? 'Başarılı' : 'Hata',
                style: GoogleFonts.playfairDisplay(
                  color: isSuccess ? Colors.green : Colors.red.shade300,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSans(
                    color: Colors.white70, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isSuccess ? Colors.green : Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    'Tamam',
                    style: GoogleFonts.notoSans(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Doğrulama ─────────────────────────────────────────────────────────────

  bool _validateEmail(String email) {
    final regex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
    return regex.hasMatch(email.trim());
  }

  bool _validatePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11 && digits.startsWith('05');
  }

  bool _validatePassword(String pass) {
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

  // ── Kayıt ─────────────────────────────────────────────────────────────────

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
      _showErrorDialog(_parseFirebaseError(e.toString()));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Giriş ─────────────────────────────────────────────────────────────────

  Future<void> _handleLogin() async {
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

    final navigator = Navigator.of(context);
    final email = _loginEmailController.text.trim();

    try {
      await FirebaseService().signInWithEmail(
        email: email,
        password: _loginPassController.text,
      );

      final authUser = FirebaseService().currentAuthUser;
      if (authUser == null) throw Exception('Giriş başarısız');

      await authUser.reload();
      if (!authUser.emailVerified) {
        if (!mounted) return;
        await navigator.pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(email: email),
          ),
        );
        return;
      }

      // Her girişte userId ve kayıtlı hesap listesini güncelle
      await LocalStorage().setUserId(authUser.uid);
      await LocalStorage().setUserRegistered(true);
      await LocalStorage().saveAccount(
        uid: authUser.uid,
        email: email,
        name: authUser.displayName ?? email,
      );

      // 1. Yerel SQLite'da kullanıcı var mı? (normal açılış)
      final existing = await UserRepository().getCurrentUser();
      if (existing != null) {
        if (!mounted) return;
        navigator.pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()));
        return;
      }

      // 2. SQLite boş (yeniden yükleme) → Firestore'dan geri yükle
      final restored =
          await UserRepository().restoreFromFirestore(authUser.uid);
      if (restored) {
        if (!mounted) return;
        navigator.pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()));
        return;
      }

      // 3. Gerçekten yeni kullanıcı → profil kurulum
      if (!mounted) return;
      navigator.pushReplacement(
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()));
    } catch (e) {
      debugPrint('[Login] ERROR: $e');
      if (!mounted) return;
      final msg = e is Exception
          ? _parseFirebaseError(e.toString())
          : 'Beklenmeyen hata: $e';
      _showErrorDialog(msg);
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

  // ── Build ─────────────────────────────────────────────────────────────────

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

  // ── Kayıt formu ───────────────────────────────────────────────────────────

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
            onChanged: (_) =>
                setState(() => _registerPassConfirmError = null),
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

  // ── Giriş formu ───────────────────────────────────────────────────────────

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
                      await FirebaseService().resetPassword(email);
                      if (!mounted) return;
                      _showErrorDialog(
                        'Şifre sıfırlama maili gönderildi.\nGelen kutunuzu kontrol edin.',
                        isSuccess: true,
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

  // ── Ortak field ───────────────────────────────────────────────────────────

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
        labelStyle:
            TextStyle(color: AppColors.gold.withValues(alpha: 0.8)),
        prefixIcon: Icon(icon, color: AppColors.turquoise, size: 20),
        suffixIcon: suffixIcon,
        errorText: errorText,
        errorStyle:
            GoogleFonts.notoSans(fontSize: 11, color: Colors.red.shade300),
        helperText: helperText,
        helperStyle:
            GoogleFonts.notoSans(fontSize: 10, color: Colors.white38),
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

// ─── E-posta Doğrulama Bekleme Ekranı ─────────────────────────────────────────

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
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Otomatik kontrol: her 4 saniyede bir doğrulama durumunu sorgula
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _autoCheck();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _autoCheck() async {
    if (_isChecking) return;
    try {
      final verified = await UserRepository().syncEmailVerified();
      if (verified && mounted) {
        _pollTimer?.cancel();
        _navigateAfterVerification();
      }
    } catch (_) {}
  }

  Future<void> _checkVerified() async {
    setState(() => _isChecking = true);
    try {
      final verified = await UserRepository().syncEmailVerified();
      if (!mounted) return;
      if (verified) {
        _pollTimer?.cancel();
        _navigateAfterVerification();
      } else {
        _showDialog(
          'Henüz doğrulanmamış',
          'E-posta henüz doğrulanmamış. Gelen kutunuzu ve spam klasörünü kontrol edin.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isChecking = false);
    }
  }

  void _navigateAfterVerification() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
    );
  }

  void _showDialog(String title, String message, {bool isError = false}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: GoogleFonts.playfairDisplay(
            color: isError ? Colors.orange : Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          message,
          style:
              GoogleFonts.notoSans(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam',
                style: GoogleFonts.notoSans(color: AppColors.gold)),
          ),
        ],
      ),
    );
  }

  Future<void> _resend() async {
    await FirebaseService().resendVerificationEmail();
    if (!mounted) return;
    setState(() => _resent = true);
    _showDialog(
      'Mail Gönderildi',
      'Doğrulama maili tekrar gönderildi.\nSpam klasörünü de kontrol edin.',
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
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4)),
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
                  '${widget.email}\nadresine doğrulama linki gönderdik.\nLinke tıkladıktan sonra otomatik olarak devam edilecek.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                      color: Colors.white70, fontSize: 14, height: 1.6),
                ),
                const SizedBox(height: 12),
                // Otomatik kontrol göstergesi
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          color: AppColors.turquoiseLight, strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Doğrulama bekleniyor...',
                      style: GoogleFonts.notoSans(
                          color: AppColors.turquoiseLight, fontSize: 12),
                    ),
                  ],
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
