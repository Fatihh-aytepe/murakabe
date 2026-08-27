import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/alarm_service.dart';
import '../../core/services/firestore_notification_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/theme_service.dart';
import '../../data/local/local_storage.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/remote/firebase_service.dart';
import '../auth/login_screen.dart';
import 'alarm_sound_screen.dart';
import 'nav_shortcuts_screen.dart';
import 'widget_appearance_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _userRepo = UserRepository();
  final _alarmService = AlarmService();
  final _storage = LocalStorage();
  final _imagePicker = ImagePicker();
  final _notifService = NotificationService();

  UserModel? _user;
  String? _profilePhotoPath;
  bool _isSaving = false;
  String? _saveError;

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;

  bool _esmaNotif = true;
  bool _hadisNotif = true;
  bool _ayetNotif = true;
  bool _kuranNotif = true;
  bool _zikirNotif = true;
  int _esmaHour = 9;
  int _esmaMinute = 0;
  int _hadisHour = 13;
  int _hadisMinute = 0;
  int _ayetHour = 18;
  int _ayetMinute = 0;
  int _kuranHour = 19;
  int _kuranMinute = 0;
  int _zikirHour = 20;
  int _zikirMinute = 0;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _profilePhotoPath = _storage.profilePhotoPath;
    _esmaNotif = _storage.esmaNotifEnabled;
    _hadisNotif = _storage.hadisNotifEnabled;
    _ayetNotif = _storage.ayetNotifEnabled;
    _kuranNotif = _storage.kuranNotifEnabled;
    _zikirNotif = _storage.zikirNotifEnabled;
    _esmaHour = _storage.esmaNotifHour;
    _esmaMinute = _storage.esmaNotifMinute;
    _hadisHour = _storage.hadisNotifHour;
    _hadisMinute = _storage.hadisNotifMinute;
    _ayetHour = _storage.ayetNotifHour;
    _ayetMinute = _storage.ayetNotifMinute;
    _kuranHour = _storage.kuranNotifHour;
    _kuranMinute = _storage.kuranNotifMinute;
    _zikirHour = _storage.zikirNotifHour;
    _zikirMinute = _storage.zikirNotifMinute;
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _userRepo.getCurrentUser();
    if (mounted) {
      setState(() {
        _user = user;
        _nameCtrl.text = user?.nameSurname ?? '';
        _phoneCtrl.text = user?.phone ?? '';
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ── Profile save ──────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    if (_user == null) return;
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.length < 2) {
      setState(() => _saveError = 'Ad soyad en az 2 karakter olmalıdır.');
      return;
    }
    if (phone.isNotEmpty &&
        !RegExp(r'^[0-9]{10,11}$')
            .hasMatch(phone.replaceAll(RegExp(r'[\s\-\+\(\)]'), ''))) {
      setState(() => _saveError = 'Geçerli bir telefon numarası giriniz.');
      return;
    }
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final updated = _user!.copyWith(nameSurname: name, phone: phone);
      await _userRepo.updateUser(updated);
      try {
        await FirebaseService().updateDisplayName(name);
      } catch (_) {}
      if (mounted) {
        setState(() {
          _user = updated;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil güncellendi'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = 'Güncelleme başarısız.';
        });
      }
    }
  }

  Future<void> _pickPhoto() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    await _storage.setProfilePhotoPath(picked.path);
    if (mounted) setState(() => _profilePhotoPath = picked.path);
  }

  // ── Email change dialog ───────────────────────────────────────────────────

  Future<void> _showEmailChangeDialog() async {
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    bool isSaving = false;
    bool showPassword = false;
    String? errorMsg;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final dialogBg = isDark ? const Color(0xFF1A2035) : Colors.white;
          final textColor = isDark ? Colors.white : AppColors.textPrimary;
          final subColor = isDark ? Colors.white60 : AppColors.textSecondary;

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: dialogBg,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.turquoise.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.email_outlined,
                            color: AppColors.turquoise, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'E-posta Değiştir',
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Güvenlik için mevcut şifrenizi ve yeni e-posta adresinizi girin.',
                    style: GoogleFonts.notoSans(
                        color: subColor, fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Yeni E-posta',
                      labelStyle: TextStyle(color: subColor),
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: AppColors.turquoise, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            const BorderSide(color: AppColors.turquoise),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: !showPassword,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Mevcut Şifre',
                      labelStyle: TextStyle(color: subColor),
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppColors.turquoise, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 18,
                          color: AppColors.textLight,
                        ),
                        onPressed: () =>
                            setDialogState(() => showPassword = !showPassword),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderSide:
                            const BorderSide(color: AppColors.turquoise),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withValues(alpha: 0.4)),
                      ),
                      child: Text(errorMsg!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Vazgeç',
                              style: GoogleFonts.notoSans(
                                  color: AppColors.textLight)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving
                              ? null
                              : () async {
                                  final newEmail = emailCtrl.text.trim();
                                  final password = passwordCtrl.text;
                                  if (!RegExp(r'^[\w\.\-\+]+@[\w\-]+\.\w{2,}$')
                                      .hasMatch(newEmail)) {
                                    setDialogState(() => errorMsg =
                                        'Geçerli bir e-posta adresi giriniz.');
                                    return;
                                  }
                                  if (password.length < 6) {
                                    setDialogState(() => errorMsg =
                                        'Şifre en az 6 karakter olmalıdır.');
                                    return;
                                  }
                                  setDialogState(() {
                                    isSaving = true;
                                    errorMsg = null;
                                  });
                                  try {
                                    await FirebaseService()
                                        .updateEmail(newEmail, password);
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Doğrulama maili $newEmail adresine gönderildi'),
                                          backgroundColor: AppColors.success,
                                        ),
                                      );
                                    }
                                  } on FirebaseAuthException catch (e) {
                                    String msg;
                                    switch (e.code) {
                                      case 'wrong-password':
                                      case 'invalid-credential':
                                        msg =
                                            'Şifre hatalı. Lütfen tekrar deneyin.';
                                        break;
                                      case 'email-already-in-use':
                                        msg =
                                            'Bu e-posta adresi zaten kullanımda.';
                                        break;
                                      case 'invalid-email':
                                        msg = 'Geçersiz e-posta adresi.';
                                        break;
                                      case 'requires-recent-login':
                                        msg =
                                            'Güvenlik için tekrar giriş yapmanız gerekmektedir.';
                                        break;
                                      default:
                                        msg =
                                            'Bir hata oluştu. Lütfen tekrar deneyin.';
                                    }
                                    setDialogState(() {
                                      isSaving = false;
                                      errorMsg = msg;
                                    });
                                  } catch (_) {
                                    setDialogState(() {
                                      isSaving = false;
                                      errorMsg = 'Beklenmeyen bir hata oluştu.';
                                    });
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.turquoise,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Değiştir',
                                  style: GoogleFonts.notoSans(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    emailCtrl.dispose();
    passwordCtrl.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF0F2F5);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isDark),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildProfileCard(isDark),
                const SizedBox(height: 16),
                _buildShortcutsCard(isDark),
                const SizedBox(height: 16),
                _buildWidgetsCard(isDark),
                const SizedBox(height: 16),
                _buildThemeCard(isDark),
                const SizedBox(height: 16),
                _buildSoundCard(isDark),
                const SizedBox(height: 16),
                _buildNotifCard(isDark),
                const SizedBox(height: 16),
                _buildDangerZoneCard(isDark),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tehlikeli bölge: hesap silme ─────────────────────────────────────────
  // Play Store, hesap oluşturmaya izin veren her uygulamadan uygulama içinde
  // kolayca bulunabilir bir "hesabı ve verileri sil" seçeneği bekler
  // (Kullanıcı Verileri Politikası — Hesap Silme). Bu kart o gereksinimi
  // karşılar; ayrıca uygulamayı silmeden de erişilebilecek bir web sayfası
  // gerekiyor (bkz. proje köküne eklenen hesap-silme.html).

  Widget _buildDangerZoneCard(bool isDark) {
    final cardColor = isDark ? const Color(0xFF2A1414) : const Color(0xFFFFF3F3);
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.redAccent, size: 18),
              const SizedBox(width: 8),
              Text(
                'TEHLİKELİ BÖLGE',
                style: GoogleFonts.notoSans(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Hesabını sildiğinde profilin, notların, zikir/oruç/Kur\'ân '
            'istatistiklerin, rozetlerin ve tüm kişisel verilerin sunucularımızdan '
            've bu cihazdan kalıcı olarak silinir. Bu işlem geri alınamaz.',
            style: GoogleFonts.notoSans(
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _confirmDeleteAccount,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.delete_forever_outlined, size: 18),
              label: Text('Hesabımı Kalıcı Olarak Sil',
                  style: GoogleFonts.notoSans(
                      fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final passwordCtrl = TextEditingController();
    String? errorText;
    bool isDeleting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: const Color(0xFF1A2035),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Hesabını silmek üzeresin',
            style: GoogleFonts.playfairDisplay(
                color: Colors.redAccent,
                fontSize: 17,
                fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bu işlem geri alınamaz. Devam etmek için şifreni gir.',
                style: GoogleFonts.notoSans(
                    color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  labelStyle: const TextStyle(color: Colors.white38),
                  errorText: errorText,
                  prefixIcon:
                      const Icon(Icons.lock_outline, color: Colors.redAccent, size: 18),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.pop(ctx, false),
              child: Text('Vazgeç',
                  style: GoogleFonts.notoSans(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: isDeleting
                  ? null
                  : () async {
                      if (passwordCtrl.text.isEmpty) {
                        setDlg(() => errorText = 'Şifre gerekli');
                        return;
                      }
                      setDlg(() {
                        isDeleting = true;
                        errorText = null;
                      });
                      // DÜZELTME: silme sırasında Firestore bildirim/sohbet
                      // dinleyicileri (FirestoreNotificationService) hâlâ
                      // çalışıyordu — tam da veriler siliniyorken topluluk
                      // tarafından tetiklenen bir olay yerel bir bildirim
                      // gösterebiliyordu. Logout'ta zaten uygulanan aynı
                      // desen (bkz. profile_screen.dart _logout): silmeden
                      // önce durdur, başarısız olursa (kullanıcı hâlâ
                      // oturumda kaldığı için) tekrar başlat.
                      FirestoreNotificationService().stop();
                      try {
                        await _userRepo
                            .deleteAccountPermanently(passwordCtrl.text);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } on FirebaseAuthException catch (e) {
                        FirestoreNotificationService().start();
                        setDlg(() {
                          isDeleting = false;
                          errorText = e.code == 'wrong-password' ||
                                  e.code == 'invalid-credential'
                              ? 'Şifre hatalı'
                              : 'Bir hata oluştu: ${e.message}';
                        });
                      } catch (e) {
                        FirestoreNotificationService().start();
                        setDlg(() {
                          isDeleting = false;
                          errorText = 'Bir hata oluştu, tekrar dene';
                        });
                      }
                    },
              child: isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text('Hesabımı Sil',
                      style: GoogleFonts.notoSans(
                          color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );

    passwordCtrl.dispose();
    if (confirmed != true) return;
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hesabın ve tüm verilerin silindi.')),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  SliverAppBar _buildAppBar(bool isDark) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios,
            color: isDark ? Colors.white : AppColors.textPrimary, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Ayarlar',
        style: GoogleFonts.playfairDisplay(
          color: isDark ? AppColors.gold : AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required Widget child,
  }) {
    final cardColor = isDark ? const Color(0xFF1A2035) : Colors.white;
    final titleColor = isDark ? Colors.white70 : AppColors.textSecondary;
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Icon(icon, color: AppColors.gold, size: 18),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.notoSans(
                    color: titleColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // ── Profile section ───────────────────────────────────────────────────────

  Widget _buildProfileCard(bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final borderColor = Colors.grey.withValues(alpha: 0.3);

    InputDecoration fieldDecor(String label, IconData icon) => InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: textColor.withValues(alpha: 0.6)),
          prefixIcon: Icon(icon, color: AppColors.gold, size: 20),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: borderColor),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: AppColors.gold),
            borderRadius: BorderRadius.circular(12),
          ),
        );

    return _buildCard(
      title: 'Profil Bilgileri',
      icon: Icons.person_outline,
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          children: [
            // Avatar
            GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.gold, AppColors.turquoise],
                      ),
                    ),
                    child: _profilePhotoPath != null &&
                            _profilePhotoPath!.isNotEmpty
                        ? ClipOval(
                            child: Image.file(
                              File(_profilePhotoPath!),
                              fit: BoxFit.cover,
                              width: 72,
                              height: 72,
                            ),
                          )
                        : Center(
                            child: Text(
                              _user?.nameSurname.isNotEmpty == true
                                  ? _user!.nameSurname[0].toUpperCase()
                                  : '?',
                              style: GoogleFonts.playfairDisplay(
                                fontSize: 28,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color:
                                isDark ? const Color(0xFF1A2035) : Colors.white,
                            width: 2),
                      ),
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 11),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Name
            TextField(
              controller: _nameCtrl,
              style: TextStyle(color: textColor),
              decoration: fieldDecor('Ad Soyad', Icons.person_outline),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            // Phone
            TextField(
              controller: _phoneCtrl,
              style: TextStyle(color: textColor),
              decoration: fieldDecor('Telefon', Icons.phone_outlined),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            // Email row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: borderColor),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.email_outlined,
                      color: AppColors.gold, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'E-posta',
                          style: TextStyle(
                              color: textColor.withValues(alpha: 0.6),
                              fontSize: 12),
                        ),
                        Text(
                          _user?.email ?? '',
                          style: TextStyle(color: textColor, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _showEmailChangeDialog,
                    child: Text(
                      'Değiştir',
                      style: GoogleFonts.notoSans(
                          color: AppColors.turquoise, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            if (_saveError != null) ...[
              const SizedBox(height: 8),
              Text(_saveError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        'Kaydet',
                        style: GoogleFonts.notoSans(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutsCard(bool isDark) {
    return _buildCard(
      title: 'Alt Menü',
      icon: Icons.apps_outlined,
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NavShortcutsScreen()),
          ),
          child: Row(
            children: [
              const Icon(Icons.dashboard_customize_outlined,
                  color: Colors.white60, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Kısayolları Düzenle',
                  style: GoogleFonts.notoSans(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
            ],
          ),
        ),
      ),
    );
  }
  // ── Ana ekran widget'ları ────────────────────────────────────────────────

  Widget _buildWidgetsCard(bool isDark) {
    return _buildCard(
      title: 'Ana Ekran Widget\'ları',
      icon: Icons.widgets_outlined,
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WidgetAppearanceScreen()),
          ),
          child: Row(
            children: [
              const Icon(Icons.format_paint_outlined,
                  color: Colors.white60, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Widget Görünümünü Özelleştir',
                      style: GoogleFonts.notoSans(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tema, saydamlık ve vurgu rengi',
                      style: GoogleFonts.notoSans(
                        color: isDark ? Colors.white38 : AppColors.textLight,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Theme section ─────────────────────────────────────────────────────────

  Widget _buildThemeCard(bool isDark) {
    return _buildCard(
      title: 'Görünüm',
      icon: Icons.palette_outlined,
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Consumer<ThemeService>(
          builder: (_, theme, __) => Row(
            children: [
              const Icon(Icons.light_mode, color: Colors.white60, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  theme.isDark ? 'Karanlık Mod' : 'Aydınlık Mod',
                  style: GoogleFonts.notoSans(
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              Switch(
                value: theme.isDark,
                onChanged: (_) => theme.toggleTheme(),
                activeThumbColor: AppColors.gold,
                activeTrackColor: AppColors.gold.withValues(alpha: 0.3),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.white24,
              ),
              const SizedBox(width: 4),
              const Icon(Icons.dark_mode, color: Colors.white60, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sound section ─────────────────────────────────────────────────────────

  Widget _buildSoundCard(bool isDark) {
    final current = _alarmService.selectedSound;

    return _buildCard(
      title: 'Alarm Sesi',
      icon: Icons.music_note_outlined,
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AlarmSoundScreen()),
            );
            if (mounted) setState(() {});
          },
          child: Row(
            children: [
              const Icon(Icons.music_note, color: Colors.white60, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.label,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.notoSans(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Teheccüd alarmı için ses seç veya kendi sesini yükle',
                      style: GoogleFonts.notoSans(
                        color: isDark ? Colors.white38 : AppColors.textLight,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ── Notification preferences section ─────────────────────────────────────

  Widget _buildNotifCard(bool isDark) {
    return _buildCard(
      title: 'Bildirim Tercihleri',
      icon: Icons.notifications_outlined,
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            _buildNotifTile(
              isDark: isDark,
              label: 'Esmaül Hüsna',
              subtitle:
                  'Her gün ${_esmaHour.toString().padLeft(2, '0')}:${_esmaMinute.toString().padLeft(2, '0')}',
              icon: Icons.auto_awesome_outlined,
              value: _esmaNotif,
              onChanged: (v) async {
                await _storage.setEsmaNotif(v);
                if (v) {
                  await _notifService.rescheduleEsmaNotification();
                } else {
                  await _notifService.cancelEsmaNotification();
                }
                setState(() => _esmaNotif = v);
              },
            ),
            if (_esmaNotif)
              _buildTimeRow(
                isDark: isDark,
                hour: _esmaHour,
                minute: _esmaMinute,
                onPicked: (h, m) async {
                  await _storage.setEsmaNotifTime(h, m);
                  await _notifService.rescheduleEsmaNotification();
                  if (mounted) {
                    setState(() {
                      _esmaHour = h;
                      _esmaMinute = m;
                    });
                  }
                },
              ),
            _buildNotifTile(
              isDark: isDark,
              label: 'Günün Hadisi',
              subtitle:
                  'Her gün ${_hadisHour.toString().padLeft(2, '0')}:${_hadisMinute.toString().padLeft(2, '0')}',
              icon: Icons.menu_book_outlined,
              value: _hadisNotif,
              onChanged: (v) async {
                await _storage.setHadisNotif(v);
                if (v) {
                  await _notifService.rescheduleHadisNotification();
                } else {
                  await _notifService.cancelHadisNotification();
                }
                setState(() => _hadisNotif = v);
              },
            ),
            if (_hadisNotif)
              _buildTimeRow(
                isDark: isDark,
                hour: _hadisHour,
                minute: _hadisMinute,
                onPicked: (h, m) async {
                  await _storage.setHadisNotifTime(h, m);
                  await _notifService.rescheduleHadisNotification();
                  if (mounted) {
                    setState(() {
                      _hadisHour = h;
                      _hadisMinute = m;
                    });
                  }
                },
              ),
            _buildNotifTile(
              isDark: isDark,
              label: 'Günün Ayeti',
              subtitle:
                  'Her gün ${_ayetHour.toString().padLeft(2, '0')}:${_ayetMinute.toString().padLeft(2, '0')}',
              icon: Icons.import_contacts_outlined,
              value: _ayetNotif,
              onChanged: (v) async {
                await _storage.setAyetNotif(v);
                if (v) {
                  await _notifService.rescheduleAyetNotification();
                } else {
                  await _notifService.cancelAyetNotification();
                }
                setState(() => _ayetNotif = v);
              },
            ),
            if (_ayetNotif)
              _buildTimeRow(
                isDark: isDark,
                hour: _ayetHour,
                minute: _ayetMinute,
                onPicked: (h, m) async {
                  await _storage.setAyetNotifTime(h, m);
                  await _notifService.rescheduleAyetNotification();
                  if (mounted) {
                    setState(() {
                      _ayetHour = h;
                      _ayetMinute = m;
                    });
                  }
                },
              ),
            _buildNotifTile(
              isDark: isDark,
              label: 'Kuran Hatırlatması',
              subtitle:
                  'Her gün ${_kuranHour.toString().padLeft(2, '0')}:${_kuranMinute.toString().padLeft(2, '0')}',
              icon: Icons.mosque_outlined,
              value: _kuranNotif,
              onChanged: (v) async {
                await _storage.setKuranNotif(v);
                if (v) {
                  await _notifService.rescheduleKuranNotification();
                } else {
                  await _notifService.cancelKuranNotification();
                }
                setState(() => _kuranNotif = v);
              },
            ),
            if (_kuranNotif)
              _buildTimeRow(
                isDark: isDark,
                hour: _kuranHour,
                minute: _kuranMinute,
                onPicked: (h, m) async {
                  await _storage.setKuranNotifTime(h, m);
                  await _notifService.rescheduleKuranNotification();
                  if (mounted) {
                    setState(() {
                      _kuranHour = h;
                      _kuranMinute = m;
                    });
                  }
                },
              ),
            _buildNotifTile(
              isDark: isDark,
              label: 'Zikir Hatırlatıcısı',
              subtitle:
                  'Her gün ${_zikirHour.toString().padLeft(2, '0')}:${_zikirMinute.toString().padLeft(2, '0')}',
              icon: Icons.spa_outlined,
              value: _zikirNotif,
              onChanged: (v) async {
                await _storage.setZikirNotif(v);
                if (v) {
                  await _notifService.rescheduleZikirNotification();
                } else {
                  await _notifService.cancelZikirNotification();
                }
                setState(() => _zikirNotif = v);
              },
            ),
            if (_zikirNotif)
              _buildTimeRow(
                isDark: isDark,
                hour: _zikirHour,
                minute: _zikirMinute,
                onPicked: (h, m) async {
                  await _storage.setZikirNotifTime(h, m);
                  await _notifService.rescheduleZikirNotification();
                  if (mounted) {
                    setState(() {
                      _zikirHour = h;
                      _zikirMinute = m;
                    });
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRow({
    required bool isDark,
    required int hour,
    required int minute,
    required Future<void> Function(int hour, int minute) onPicked,
  }) {
    final textColor = isDark ? Colors.white70 : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 16, 8),
      child: GestureDetector(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: TimeOfDay(hour: hour, minute: minute),
          );
          if (picked == null) return;
          await onPicked(picked.hour, picked.minute);
        },
        child: Row(
          children: [
            const Icon(Icons.access_time, color: AppColors.turquoise, size: 16),
            const SizedBox(width: 8),
            Text(
              'Bildirim saatini değiştir',
              style: GoogleFonts.notoSans(
                  color: AppColors.turquoise, fontSize: 12),
            ),
            const Spacer(),
            Text(
              '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
              style: GoogleFonts.notoSans(
                  color: textColor, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotifTile({
    required bool isDark,
    required String label,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white54 : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        GoogleFonts.notoSans(color: textColor, fontSize: 14)),
                Text(subtitle,
                    style: GoogleFonts.notoSans(color: subColor, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.gold,
            activeTrackColor: AppColors.gold.withValues(alpha: 0.3),
            inactiveThumbColor: Colors.white54,
            inactiveTrackColor: Colors.white12,
          ),
        ],
      ),
    );
  }
}
