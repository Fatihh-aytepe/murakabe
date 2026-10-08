import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/models/esma_model.dart';
import '../../data/repositories/content_repository.dart';
import '../../core/services/notification_service.dart';
import '../notes/notes_screen.dart';
import '../notes/note_quote_builder.dart';
import '../rewards/reward_flow.dart';

class EsmaDetailScreen extends StatefulWidget {
  final EsmaModel esma;
  const EsmaDetailScreen({super.key, required this.esma});

  @override
  State<EsmaDetailScreen> createState() => _EsmaDetailScreenState();
}

class _EsmaDetailScreenState extends State<EsmaDetailScreen> {
  final _contentRepo = ContentRepository();
  bool _isSaved = false;
  late EsmaModel _currentEsma;

  @override
  void initState() {
    super.initState();
    _currentEsma = widget.esma;
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final saved = await _contentRepo.isSaved('esma', _currentEsma.id);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _loadRandomEsma() async {
    final esma = await _contentRepo.getRandomEsma();
    if (mounted) {
      setState(() {
        _currentEsma = esma;
        _isSaved = false;
      });
      _checkSaved();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B), Color(0xFF0D2233)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      Text(
                        'Esmaül Hüsna',
                        style: GoogleFonts.playfairDisplay(
                          color: AppColors.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Tefekkür notu ikonu
                      IconButton(
                        icon: const Icon(Icons.edit_note,
                            color: AppColors.turquoise),
                        tooltip: 'Tefekkür Notu',
                        onPressed: _openNoteEditor,
                      ),
                      IconButton(
                        icon: Icon(
                          _isSaved ? Icons.bookmark : Icons.bookmark_outline,
                          color: AppColors.gold,
                        ),
                        onPressed: _toggleSave,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 2),
                    color: AppColors.gold.withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Text(
                      '${_currentEsma.id}',
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.gold,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    _currentEsma.arabic,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.amiri(
                      fontSize: 48,
                      color: AppColors.gold,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  _currentEsma.turkish,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 32),

                _buildInfoCard(
                  title: 'Anlamı',
                  content: _currentEsma.meaning,
                  icon: Icons.translate,
                  color: AppColors.turquoise,
                ),

                const SizedBox(height: 16),

                _buildInfoCard(
                  title: 'Duası',
                  content: _currentEsma.dua,
                  icon: Icons.volunteer_activism,
                  color: AppColors.gold,
                ),

                const SizedBox(height: 24),

                // Tefekkür notu butonu (belirgin)
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
                            color: AppColors.turquoise.withValues(alpha: 0.4)),
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
                          onTap: _markReadAndClose,
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
                      onPressed: _loadRandomEsma,
                      icon:
                          const Icon(Icons.shuffle, color: AppColors.turquoise),
                      label: const Text('Yeni Esma',
                          style: TextStyle(color: AppColors.turquoise)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.turquoise),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _toggleSave,
                      icon: Icon(
                        _isSaved ? Icons.bookmark : Icons.bookmark_outline,
                        color: AppColors.gold,
                      ),
                      label: Text(
                        _isSaved ? 'Kaydedildi' : 'Kaydet',
                        style: const TextStyle(color: AppColors.gold),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.gold),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
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
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
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

  // Önce ekran ANINDA güncellenir, kayıt arkadan yapılır. Kayıt hata
  // verirse eski duruma geri dönülür.
  Future<void> _toggleSave() async {
    final wasSaved = _isSaved;
    setState(() => _isSaved = !wasSaved);
    try {
      if (wasSaved) {
        await _contentRepo.unsaveContent('esma', _currentEsma.id);
      } else {
        await _contentRepo.saveContent('esma', _currentEsma.id);
      }
    } catch (_) {
      if (mounted) setState(() => _isSaved = wasSaved);
    }
  }

  void _markReadAndClose() {
    final nav = Navigator.of(context);
    final alreadyRead = _contentRepo.isReadToday('esma', _currentEsma.id);
    _contentRepo.markReadToday('esma', _currentEsma.id);
    nav.pop();
    // Seri + tebrik + rozet kontrolü anında; aynı içerik bugün zaten
    // okunduysa tekrar sayılmaz.
    if (!alreadyRead) RewardFlow.afterRead(nav, 'esma');
  }

  Future<void> _scheduleRemind() async {
    await NotificationService().scheduleRemindLater(
      'esma',
      _currentEsma.arabic,
      _currentEsma.meaning,
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
    final title = 'Esma: ${_currentEsma.arabic} (${_currentEsma.turkish})';
    showNoteEditor(
      context,
      prefillTitle: title,
      prefillDocument: buildQuoteDocument(
        arabic: _currentEsma.arabic,
        meal: _currentEsma.meaning,
        source: 'Esmaül Hüsna — ${_currentEsma.turkish}',
      ),
      prefillTags: const ['esma'],
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
