import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/alarm_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/theme_service.dart';
import '../../data/local/local_storage.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/remote/firebase_service.dart';

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
  final _previewPlayer = AudioPlayer();
  final _notifService = NotificationService();

  UserModel? _user;
  String? _profilePhotoPath;
  bool _isPreviewing = false;
  bool _isSaving = false;
  String? _saveError;

  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;

  bool _esmaNotif = true;
  bool _hadisNotif = true;
  bool _ayetNotif = true;
  bool _kuranNotif = true;

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
    _previewPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPreviewing = false);
    });
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
    _previewPlayer.dispose();
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

  // ── Sound preview ─────────────────────────────────────────────────────────

  Future<void> _toggleSoundPreview() async {
    if (_isPreviewing) {
      await _previewPlayer.stop();
      if (mounted) setState(() => _isPreviewing = false);
    } else {
      if (mounted) setState(() => _isPreviewing = true);
      try {
        await _previewPlayer.play(
          AssetSource('sounds/${_alarmService.selectedSound.id}.mp3'),
        );
      } catch (_) {
        if (mounted) setState(() => _isPreviewing = false);
      }
    }
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
                        border:
                            Border.all(color: Colors.red.withValues(alpha: 0.4)),
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
                                  if (!RegExp(
                                          r'^[\w\.\-\+]+@[\w\-]+\.\w{2,}$')
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
    final bgColor =
        isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF0F2F5);

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
                _buildThemeCard(isDark),
                const SizedBox(height: 16),
                _buildSoundCard(isDark),
                const SizedBox(height: 16),
                _buildNotifCard(isDark),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _buildAppBar(bool isDark) {
    return SliverAppBar(
      pinned: true,
      backgroundColor:
          isDark ? const Color(0xFF0D1B2A) : Colors.white,
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
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
                            color: isDark
                                ? const Color(0xFF1A2035)
                                : Colors.white,
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
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
              const Icon(Icons.light_mode,
                  color: Colors.white60, size: 20),
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
              const Icon(Icons.dark_mode,
                  color: Colors.white60, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Sound section ─────────────────────────────────────────────────────────

  Widget _buildSoundCard(bool isDark) {
    final current = _alarmService.selectedSound;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;

    return _buildCard(
      title: 'Alarm Sesi',
      icon: Icons.music_note_outlined,
      isDark: isDark,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: DropdownButton<String>(
                value: current.id,
                isExpanded: true,
                dropdownColor:
                    isDark ? const Color(0xFF1A2035) : Colors.white,
                underline: const SizedBox(),
                style: GoogleFonts.notoSans(
                  color: textColor,
                  fontSize: 14,
                ),
                icon: const Icon(Icons.music_note,
                    color: AppColors.gold, size: 20),
                items: AlarmService.availableSounds
                    .map((s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.label),
                        ))
                    .toList(),
                onChanged: (val) async {
                  if (val == null) return;
                  await _previewPlayer.stop();
                  if (mounted) setState(() => _isPreviewing = false);
                  final sound = AlarmService.availableSounds
                      .firstWhere((s) => s.id == val);
                  await _alarmService.setSelectedSound(sound);
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _toggleSoundPreview,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isPreviewing
                      ? Colors.red.withValues(alpha: 0.15)
                      : AppColors.gold.withValues(alpha: 0.15),
                  border: Border.all(
                    color: _isPreviewing ? Colors.red : AppColors.gold,
                  ),
                ),
                child: Icon(
                  _isPreviewing
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  color: _isPreviewing ? Colors.red : AppColors.gold,
                  size: 18,
                ),
              ),
            ),
          ],
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
              subtitle: 'Her gün 08:00',
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
            _buildNotifTile(
              isDark: isDark,
              label: 'Günün Hadisi',
              subtitle: 'Her gün 12:00',
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
            _buildNotifTile(
              isDark: isDark,
              label: 'Günün Ayeti',
              subtitle: 'Her gün 14:00',
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
            _buildNotifTile(
              isDark: isDark,
              label: 'Kuran Hatırlatması',
              subtitle: 'Her gün 19:00',
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
                    style: GoogleFonts.notoSans(
                        color: textColor, fontSize: 14)),
                Text(subtitle,
                    style: GoogleFonts.notoSans(
                        color: subColor, fontSize: 12)),
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
