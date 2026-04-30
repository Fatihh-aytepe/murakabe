import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../data/local/local_storage.dart';
import '../../data/repositories/user_repository.dart';
import '../home/home_screen.dart';
import '../admin/admin_panel_screen.dart';
import '../../core/utils/permission_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  // Admin giriş için gizli alanlar
  int _tapCount = 0;
  bool _showAdminFields = false;
  final _adminEmailController = TextEditingController();
  final _adminPassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    PermissionHelper.requestAllPermissions();
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
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Logo
                GestureDetector(
                  onTap: () {
                    _tapCount++;
                    if (_tapCount >= 7) {
                      setState(() => _showAdminFields = true);
                    }
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold, width: 2),
                    ),
                    child: ClipOval(
                      child: Image.asset('assets/images/logo.png',
                          fit: BoxFit.cover),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  AppStrings.appName,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 32,
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  AppStrings.loginSubtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    fontSize: 14,
                    color: AppColors.white.withOpacity(0.7),
                  ),
                ),

                const SizedBox(height: 40),

                // Form kartı
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.gold.withOpacity(0.3), width: 1),
                  ),
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _nameController,
                        label: AppStrings.nameSurname,
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _phoneController,
                        label: AppStrings.phone,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(
                        controller: _emailController,
                        label: AppStrings.email,
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      if (_showAdminFields) ...[
                        const SizedBox(height: 16),
                        const Divider(color: Colors.orange),
                        const SizedBox(height: 8),
                        Text('Admin Girişi',
                            style: TextStyle(color: Colors.orange)),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: _adminEmailController,
                          label: 'Admin E-posta',
                          icon: Icons.admin_panel_settings,
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(
                          controller: _adminPassController,
                          label: 'Admin Şifre',
                          icon: Icons.lock_outline,
                          obscure: true,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Başla butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(AppStrings.startButton),
                  ),
                ),

                const SizedBox(height: 20),

                // Bismillah
                Text(
                  'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                  style: GoogleFonts.amiri(
                    fontSize: 18,
                    color: AppColors.gold.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.gold.withOpacity(0.8)),
        prefixIcon: Icon(icon, color: AppColors.turquoise),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.gold.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    // Admin kontrolü
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

    // Normal kullanıcı kaydı
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen tüm alanları doldurun')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await UserRepository().createUser(
        nameSurname: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
      );

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
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _adminEmailController.dispose();
    _adminPassController.dispose();
    super.dispose();
  }
}
