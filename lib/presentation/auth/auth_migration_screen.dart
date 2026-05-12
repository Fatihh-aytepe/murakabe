import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/role_service.dart';
import '../../../data/local/local_storage.dart';
import '../../../data/local/database_helper.dart';
import '../../../data/models/user_model.dart';
import '../../../data/remote/firebase_service.dart';
import '../home/home_screen.dart';
import '../community/owner_panel_screen.dart';
import '../community/admin_dashboard_screen.dart';

/// Güncelleme sonrası eski kullanıcıları Firebase Auth'a bağlayan ekran.
/// Bir kez gösterilir, tamamlanınca bir daha açılmaz.
class AuthMigrationScreen extends StatefulWidget {
  final String oldUserId;
  const AuthMigrationScreen({super.key, required this.oldUserId});

  @override
  State<AuthMigrationScreen> createState() => _AuthMigrationScreenState();
}

class _AuthMigrationScreenState extends State<AuthMigrationScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _passConfirmCtrl = TextEditingController();
  final _db = DatabaseHelper();
  final _storage = LocalStorage();
  final _firebase = FirebaseService();

  bool _isLoading = false;
  bool _passVisible = false;
  bool _passConfirmVisible = false;
  String? _emailError;
  String? _passError;
  String? _passConfirmError;
  String? _generalError;

  // Mevcut kullanıcı bilgilerini önceden doldur
  UserModel? _existingUser;

  @override
  void initState() {
    super.initState();
    _loadExistingUser();
  }

  Future<void> _loadExistingUser() async {
    final rows = await _db.query(
      'users',
      where: 'id = ?',
      whereArgs: [widget.oldUserId],
    );
    if (rows.isNotEmpty && mounted) {
      final user = UserModel.fromMap(rows.first);
      setState(() {
        _existingUser = user;
        _emailCtrl.text = user.email;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _passConfirmCtrl.dispose();
    super.dispose();
  }

  bool _validateForm() {
    bool valid = true;
    setState(() {
      _emailError = null;
      _passError = null;
      _passConfirmError = null;
      _generalError = null;

      final emailRegex = RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(_emailCtrl.text.trim())) {
        _emailError = 'Geçerli bir e-posta girin';
        valid = false;
      }
      if (_passCtrl.text.length < 8) {
        _passError = 'En az 8 karakter, büyük/küçük harf ve rakam';
        valid = false;
      }
      if (_passCtrl.text != _passConfirmCtrl.text) {
        _passConfirmError = 'Şifreler eşleşmiyor';
        valid = false;
      }
    });
    return valid;
  }

  Future<void> _migrate() async {
    if (!_validateForm()) return;
    setState(() => _isLoading = true);

    try {
      final email = _emailCtrl.text.trim();
      final password = _passCtrl.text;

      // 1. Firebase Auth'a kayıt ol
      UserCredential credential;
      try {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        // E-posta zaten kayıtlıysa giriş yap
        if (e.code == 'email-already-in-use') {
          credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }

      final newUid = credential.user!.uid;

      // 2. SQLite'da kullanıcı ID'sini güncelle
      await _db.update(
        'users',
        {'id': newUid},
        where: 'id = ?',
        whereArgs: [widget.oldUserId],
      );

      // 3. LocalStorage'daki ID'yi güncelle
      await _storage.setUserId(newUid);

      // 4. Firestore'a kullanıcı verisini aktar
      if (_existingUser != null) {
        final updatedUser = UserModel(
          id: newUid,
          nameSurname: _existingUser!.nameSurname,
          phone: _existingUser!.phone,
          email: email,
          createdAt: _existingUser!.createdAt,
          quranReadDays: _existingUser!.quranReadDays,
          missedQuranDays: _existingUser!.missedQuranDays,
          tahajjudAlarmEnabled: _existingUser!.tahajjudAlarmEnabled,
          tahajjudAlarmTimes: _existingUser!.tahajjudAlarmTimes,
          streakDays: _existingUser!.streakDays,
          mercyDaysUsed: _existingUser!.mercyDaysUsed,
          lastStreakDate: _existingUser!.lastStreakDate,
          bio: _existingUser!.bio,
          gender: _existingUser!.gender,
          photoUrl: _existingUser!.photoUrl,
          isEmailVerified: true,
        );
        await _firebase.saveUser(updatedUser);
      }

      // 5. Migration tamamlandı olarak işaretle
      await _storage.setAuthMigrationDone();

      if (!mounted) return;

      // 6. Role göre yönlendir
      final role = await RoleService().getCurrentRole();
      if (!mounted) return;

      Widget target;
      switch (role) {
        case UserRole.owner:
          target = const OwnerPanelScreen();
          break;
        case UserRole.admin:
          target = const AdminDashboardScreen();
          break;
        case UserRole.user:
          target = const HomeScreen();
          break;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => target),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _generalError = _parseError(e.code);
      });
    } catch (e) {
      setState(() {
        _generalError = 'Bir hata oluştu: $e';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _parseError(String code) {
    switch (code) {
      case 'wrong-password':
        return 'Şifre hatalı. Bu e-postaya daha önce farklı bir şifre belirlediniz.';
      case 'network-request-failed':
        return 'İnternet bağlantısı yok.';
      case 'too-many-requests':
        return 'Çok fazla deneme. Lütfen bekleyin.';
      default:
        return 'Hata: $code';
    }
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const SizedBox(height: 32),

                // İkon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withOpacity(0.15),
                    border: Border.all(color: AppColors.gold.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.security,
                      color: AppColors.gold, size: 48),
                ),

                const SizedBox(height: 24),

                Text(
                  'Hesabınızı Güvenli Hale Getirin',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Murakabe yeni bir güvenlik sistemi kullanıyor.\nTüm verileriniz korunuyor — sadece bir şifre belirlemeniz yeterli.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),

                if (_existingUser != null) ...[
                  const SizedBox(height: 16),
                  // Mevcut kullanıcı bilgisi
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.gold.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person,
                            color: AppColors.gold, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _existingUser!.nameSurname,
                                style: GoogleFonts.notoSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                              Row(
                                children: [
                                  const Text('🔥',
                                      style: TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${_existingUser!.streakDays} günlük seri korunacak',
                                    style: GoogleFonts.notoSans(
                                        color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle,
                            color: Color(0xFF4CAF50), size: 18),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),

                // E-posta
                _buildField(
                  controller: _emailCtrl,
                  label: 'E-posta',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  errorText: _emailError,
                  onChanged: (_) => setState(() => _emailError = null),
                ),

                const SizedBox(height: 14),

                // Şifre
                _buildField(
                  controller: _passCtrl,
                  label: 'Yeni Şifre',
                  icon: Icons.lock_outline,
                  obscure: !_passVisible,
                  errorText: _passError,
                  helperText: 'En az 8 karakter, büyük/küçük harf ve rakam',
                  onChanged: (_) => setState(() => _passError = null),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passVisible ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.gold.withOpacity(0.6),
                      size: 20,
                    ),
                    onPressed: () =>
                        setState(() => _passVisible = !_passVisible),
                  ),
                ),

                const SizedBox(height: 14),

                // Şifre tekrar
                _buildField(
                  controller: _passConfirmCtrl,
                  label: 'Şifre Tekrar',
                  icon: Icons.lock_outline,
                  obscure: !_passConfirmVisible,
                  errorText: _passConfirmError,
                  onChanged: (_) => setState(() => _passConfirmError = null),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _passConfirmVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppColors.gold.withOpacity(0.6),
                      size: 20,
                    ),
                    onPressed: () => setState(
                        () => _passConfirmVisible = !_passConfirmVisible),
                  ),
                ),

                if (_generalError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _generalError!,
                            style: GoogleFonts.notoSans(
                                color: Colors.red.shade300, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _migrate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2.5),
                          )
                        : Text(
                            'Hesabımı Güvenceye Al',
                            style: GoogleFonts.notoSans(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Bu işlem yalnızca bir kez yapılır.\nVerileriniz kaybolmaz.',
                  textAlign: TextAlign.center,
                  style:
                      GoogleFonts.notoSans(color: Colors.white30, fontSize: 11),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? errorText,
    String? helperText,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.gold.withOpacity(0.8)),
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
                : AppColors.gold.withOpacity(0.3),
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
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }
}
