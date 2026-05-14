import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../data/local/local_storage.dart';
import '../../data/repositories/user_repository.dart';
import '../home/home_screen.dart';

/// Kayıt + e-posta doğrulama sonrası bir kez gösterilen profil kurulum ekranı.
/// Fotoğraf, biyografi ve cinsiyet bilgilerini alır.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _bioController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _userRepo = UserRepository();

  String? _photoPath;
  String _selectedGender = ''; // 'erkek' | 'kadin' | ''
  bool _isLoading = false;

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _photoPath = picked.path);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf seçilemedi')),
        );
      }
    }
  }

  void _showPhotoSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF1A2035),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Profil Fotoğrafı',
              style: GoogleFonts.playfairDisplay(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.gold),
              title: Text('Kamera',
                  style: GoogleFonts.notoSans(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: AppColors.turquoise),
              title: Text('Galeri',
                  style: GoogleFonts.notoSans(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    try {
      final user = await _userRepo.getCurrentUser();
      if (user != null) {
        // Fotoğraf yolunu local storage'a kaydet
        if (_photoPath != null) {
          await LocalStorage().setProfilePhotoPath(_photoPath!);
        }

        // Biyografi + cinsiyeti modele yaz
        await _userRepo.updateUser(user.copyWith(
          bio: _bioController.text.trim(),
          gender: _selectedGender,
        ));
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Text(
                  'Profilinizi Oluşturun',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Bu bilgiler isteğe bağlıdır, daha sonra değiştirebilirsiniz.',
                  textAlign: TextAlign.center,
                  style:
                      GoogleFonts.notoSans(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 36),

                // ── Fotoğraf seçici ──
                GestureDetector(
                  onTap: _showPhotoSheet,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.gold, AppColors.turquoise],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.35),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: _photoPath != null
                            ? ClipOval(
                                child: Image.file(
                                  File(_photoPath!),
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                ),
                              )
                            : const Center(
                                child: Icon(Icons.person,
                                    color: Colors.white, size: 48),
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt,
                              color: Colors.white, size: 15),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fotoğraf Ekle',
                  style: GoogleFonts.notoSans(
                      color: AppColors.gold.withValues(alpha: 0.8), fontSize: 13),
                ),

                const SizedBox(height: 32),

                // ── Cinsiyet seçimi ──
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Cinsiyet',
                    style: GoogleFonts.notoSans(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _buildGenderCard(
                      label: 'Erkek',
                      icon: Icons.male,
                      value: 'erkek',
                    ),
                    const SizedBox(width: 12),
                    _buildGenderCard(
                      label: 'Kadın',
                      icon: Icons.female,
                      value: 'kadin',
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── Biyografi ──
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Biyografi',
                    style: GoogleFonts.notoSans(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bioController,
                  maxLines: 4,
                  maxLength: 200,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Kendinizden kısaca bahsedin (isteğe bağlı)...',
                    hintStyle: GoogleFonts.notoSans(
                        color: Colors.white30, fontSize: 13),
                    counterStyle: GoogleFonts.notoSans(color: Colors.white30),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          BorderSide(color: AppColors.gold.withValues(alpha: 0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.gold),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                  ),
                ),

                const SizedBox(height: 36),

                // ── Kaydet butonu ──
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
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
                            'Başlayalım →',
                            style: GoogleFonts.notoSans(
                                fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HomeScreen()),
                          ),
                  child: Text(
                    'Şimdi değil, atla',
                    style: GoogleFonts.notoSans(
                        color: Colors.white38, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderCard({
    required String label,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGender = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.gold.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.gold : Colors.white24,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  color: isSelected ? AppColors.gold : Colors.white38,
                  size: 24),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.notoSans(
                  color: isSelected ? AppColors.gold : Colors.white54,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
