import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../data/models/ayet_model.dart';
import '../../data/repositories/content_repository.dart';
import '../notes/notes_screen.dart';
import '../notes/note_quote_builder.dart';

class AyetDetailScreen extends StatefulWidget {
  final AyetModel ayet;
  const AyetDetailScreen({super.key, required this.ayet});

  @override
  State<AyetDetailScreen> createState() => _AyetDetailScreenState();
}

class _AyetDetailScreenState extends State<AyetDetailScreen> {
  final _contentRepo = ContentRepository();
  bool _isSaved = false;
  late AyetModel _currentAyet;

  @override
  void initState() {
    super.initState();
    _currentAyet = widget.ayet;
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final saved = await _contentRepo.isSaved('ayet', _currentAyet.id);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _loadRandomAyet() async {
    final ayet = await _contentRepo.getRandomAyet();
    if (mounted) {
      setState(() {
        _currentAyet = ayet;
        _isSaved = false;
      });
      _checkSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scaffold arka planını gradient ile eşleştir — beyaz boşluk kalmasın
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B), Color(0xFF0D2233)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false, // Alt kısmı SafeArea'dan muaf tut — gradient dolsun
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    // AppBar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios,
                                color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          Text(
                            'Ayet',
                            style: GoogleFonts.playfairDisplay(
                              color: AppColors.gold,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.edit_note,
                                color: AppColors.turquoise),
                            tooltip: 'Tefekkür Notu',
                            onPressed: _openNoteEditor,
                          ),
                          IconButton(
                            icon: Icon(
                              _isSaved
                                  ? Icons.bookmark
                                  : Icons.bookmark_outline,
                              color: AppColors.gold,
                            ),
                            onPressed: _toggleSave,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.turquoise.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.turquoise.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '${_currentAyet.surah} • ${_currentAyet.ayahNumber}. Ayet',
                        style: GoogleFonts.notoSans(
                          color: AppColors.turquoiseLight,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Arapça metin
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _currentAyet.arabic,
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.amiri(
                            fontSize: 26,
                            color: AppColors.gold,
                            height: 2,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    _buildInfoCard(
                      title: 'Türkçe Meal',
                      content: _currentAyet.turkish,
                      icon: Icons.translate,
                      color: AppColors.turquoise,
                    ),

                    const SizedBox(height: 24),

                    // Tefekkür notu butonu
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GestureDetector(
                        onTap: _openNoteEditor,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.turquoise.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color:
                                    AppColors.turquoise.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.edit_note,
                                  color: AppColors.turquoise, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Tefekkür Notu Kaydet',
                                style: GoogleFonts.notoSans(
                                  color: AppColors.turquoise,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildActionButton(
                              label: 'Okudum',
                              icon: Icons.check_circle_outline,
                              color: const Color(0xFF4CAF50),
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildActionButton(
                              label: 'Tekrar Hatırlat',
                              icon: Icons.alarm_outlined,
                              color: const Color(0xFFFF9800),
                              onTap: _scheduleRemind,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _loadRandomAyet,
                          icon: const Icon(Icons.shuffle,
                              color: AppColors.turquoise),
                          label: const Text('Yeni Ayet',
                              style: TextStyle(color: AppColors.turquoise)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.turquoise),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Alt boşluk — home indicator + içerik arası
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.notoSans(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: GoogleFonts.notoSans(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 15,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.notoSans(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSave() async {
    if (_isSaved) {
      await _contentRepo.unsaveContent('ayet', _currentAyet.id);
    } else {
      await _contentRepo.saveContent('ayet', _currentAyet.id);
    }
    if (mounted) setState(() => _isSaved = !_isSaved);
  }

  Future<void> _scheduleRemind() async {
    await NotificationService().scheduleRemindLater(
      'ayet',
      _currentAyet.surah,
      _currentAyet.turkish,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('3 saat sonra tekrar hatırlatılacak'),
        backgroundColor: Color(0xFFFF9800),
      ),
    );
  }

  void _openNoteEditor() {
    final title =
        'Ayet: ${_currentAyet.surah} ${_currentAyet.ayahNumber}. Ayet';
    showNoteEditor(
      context,
      prefillTitle: title,
      prefillDocument: buildQuoteDocument(
        arabic: _currentAyet.arabic,
        meal: _currentAyet.turkish,
        source: '${_currentAyet.surah}, ${_currentAyet.ayahNumber}. Ayet',
      ),
      prefillTags: const ['ayet'],
      onSaved: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not kaydedildi'),
            backgroundColor: AppColors.success,
          ),
        );
      },
    );
  }
}
