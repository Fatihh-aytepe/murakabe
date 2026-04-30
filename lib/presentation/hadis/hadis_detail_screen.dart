import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/notification_service.dart';
import '../../data/local/database_helper.dart';
import '../../data/models/hadis_model.dart';
import '../../data/models/note_model.dart';
import '../../data/repositories/content_repository.dart';

class HadisDetailScreen extends StatefulWidget {
  final HadisModel hadis;
  const HadisDetailScreen({super.key, required this.hadis});

  @override
  State<HadisDetailScreen> createState() => _HadisDetailScreenState();
}

class _HadisDetailScreenState extends State<HadisDetailScreen> {
  final _contentRepo = ContentRepository();
  final _db = DatabaseHelper();
  bool _isSaved = false;
  late HadisModel _currentHadis;

  @override
  void initState() {
    super.initState();
    _currentHadis = widget.hadis;
    _checkSaved();
  }

  Future<void> _checkSaved() async {
    final saved = await _contentRepo.isSaved('hadis', _currentHadis.id);
    if (mounted) setState(() => _isSaved = saved);
  }

  Future<void> _loadRandomHadis() async {
    final hadis = await _contentRepo.getRandomHadis();
    if (mounted) {
      setState(() {
        _currentHadis = hadis;
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
            colors: [Color(0xFF1A0A00), Color(0xFF3D1A00), Color(0xFF1A0A00)],
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
                        'Hadis',
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    _currentHadis.source,
                    style: GoogleFonts.notoSans(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                if (_currentHadis.arabic.isNotEmpty)
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
                        _currentHadis.arabic,
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: GoogleFonts.amiri(
                          fontSize: 22,
                          color: AppColors.gold,
                          height: 2,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                _buildInfoCard(
                  title: 'Hadis Metni',
                  content: _currentHadis.text,
                  icon: Icons.format_quote,
                  color: const Color(0xFF8B6914),
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
                      onPressed: _loadRandomHadis,
                      icon: const Icon(Icons.shuffle, color: AppColors.gold),
                      label: const Text('Yeni Hadis',
                          style: TextStyle(color: AppColors.gold)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.gold),
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
                        _isSaved
                            ? Icons.bookmark
                            : Icons.bookmark_outline,
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

  Future<void> _toggleSave() async {
    if (_isSaved) {
      await _contentRepo.unsaveContent('hadis', _currentHadis.id);
    } else {
      await _contentRepo.saveContent('hadis', _currentHadis.id);
    }
    if (mounted) setState(() => _isSaved = !_isSaved);
  }

  Future<void> _scheduleRemind() async {
    await NotificationService().scheduleRemindLater(
      'hadis',
      _currentHadis.source,
      _currentHadis.text,
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
    final prefill = 'Hadis: ${_currentHadis.source}';
    final titleCtrl = TextEditingController(text: prefill);
    final contentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
        child: _NoteSheet(
          titleCtrl: titleCtrl,
          contentCtrl: contentCtrl,
          onSave: () async {
            final nav = Navigator.of(sheetCtx);
            final messenger = ScaffoldMessenger.of(context);
            final t = titleCtrl.text.trim();
            final c = contentCtrl.text.trim();
            final now = DateTime.now();
            await _db.insert(
              'notes',
              NoteModel(
                id: const Uuid().v4(),
                title: t.isNotEmpty ? t : prefill,
                content: c,
                createdAt: now,
                updatedAt: now,
              ).toMap(),
            );
            nav.pop();
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Not kaydedildi'),
                backgroundColor: AppColors.success,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NoteSheet extends StatelessWidget {
  final TextEditingController titleCtrl;
  final TextEditingController contentCtrl;
  final VoidCallback onSave;

  const _NoteSheet({
    required this.titleCtrl,
    required this.contentCtrl,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF1A2035),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.edit_note, color: AppColors.turquoise),
              const SizedBox(width: 8),
              Text(
                'Tefekkür Notu',
                style: GoogleFonts.playfairDisplay(
                  color: AppColors.gold,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: titleCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Başlık',
              labelStyle: const TextStyle(color: Colors.white54),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.gold),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: contentCtrl,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Düşüncelerini buraya yaz...',
              hintStyle: const TextStyle(color: Colors.white38),
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: AppColors.gold),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                'Notu Kaydet',
                style: GoogleFonts.notoSans(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
