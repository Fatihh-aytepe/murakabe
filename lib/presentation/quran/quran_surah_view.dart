import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/note_repository.dart';
import 'quran_ayah_tile.dart';

class QuranSurahView extends StatefulWidget {
  final int initialSurah;
  final int initialAyah;
  final Qari selectedQari;
  final QuranAyah? selectedAyah;
  final bool showMeal;
  final double arabicFontSize;
  final void Function(int page, int surah, int ayah) onProgressChanged;
  final void Function(QuranAyah ayah) onAyahSelected;

  const QuranSurahView({
    super.key,
    required this.initialSurah,
    required this.initialAyah,
    required this.selectedQari,
    this.selectedAyah,
    this.showMeal = true,
    this.arabicFontSize = 32,
    required this.onProgressChanged,
    required this.onAyahSelected,
  });

  @override
  State<QuranSurahView> createState() => _QuranSurahViewState();
}

class _QuranSurahViewState extends State<QuranSurahView> {
  final _repo = QuranRepository();
  final _noteRepo = NoteRepository();

  List<QuranSurah> _surahs = [];
  List<QuranAyah> _ayahs = [];
  int? _selectedSurah;
  bool _loadingSurahs = true;
  bool _loadingAyahs = false;

  @override
  void initState() {
    super.initState();
    _loadSurahs();
  }

  Future<void> _loadSurahs() async {
    final surahs = await _repo.getSurahs();
    if (mounted) {
      setState(() {
        _surahs = surahs;
        _loadingSurahs = false;
      });
    }
  }

  Future<void> _loadAyahs(int surahNumber) async {
    setState(() {
      _selectedSurah = surahNumber;
      _loadingAyahs = true;
      _ayahs = [];
    });
    final ayahs = await _repo.getAyahsBySurah(surahNumber);
    if (mounted) {
      setState(() {
        _ayahs = ayahs;
        _loadingAyahs = false;
      });
      // DÜZELTME (yarış durumu): kullanıcı hızlıca birden fazla sure
      // arasında geçiş yaparsa, her biri için ayrı bir ağ isteği
      // (getAyahsBySurah) eşzamanlı başlıyor ve yanıtların hangi sırayla
      // döneceğinin garantisi yok. Önceden yanıt hangi sureye ait olursa
      // olsun koşulsuzca ilerleme kaydediliyordu — eski/yavaş bir sure
      // isteği, kullanıcı çoktan başka bir sureye geçtikten SONRA dönerse
      // ilerlemeyi geri alabiliyordu. Artık yalnızca yanıt hâlâ kullanıcının
      // O AN seçili olan suresine aitse ilerleme güncelleniyor.
      if (ayahs.isNotEmpty && _selectedSurah == surahNumber) {
        widget.onProgressChanged(
            ayahs.first.page, surahNumber, ayahs.first.number);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loadingSurahs) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.gold));
    }

    if (_selectedSurah != null) {
      return _buildAyahList(isDark);
    }

    return _buildSurahList(isDark);
  }

  Widget _buildSurahList(bool isDark) {
    final bg = isDark ? const Color(0xFF0A0E1A) : const Color(0xFFFAF8F0);
    final cardBg = isDark ? const Color(0xFF1A2035) : Colors.white;

    return Container(
      color: bg,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: _surahs.length,
        itemBuilder: (_, i) {
          final surah = _surahs[i];
          return GestureDetector(
            onTap: () => _loadAyahs(surah.number),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.gold, Color(0xFFB8860B)],
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${surah.number}',
                        style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          surah.nameTurkish,
                          style: GoogleFonts.notoSans(
                            color:
                                isDark ? Colors.white : AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${surah.nameTransliteration} • ${surah.ayahCount} ayet • ${surah.revelationType}',
                          style: GoogleFonts.notoSans(
                            color:
                                isDark ? Colors.white38 : AppColors.textLight,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    surah.nameArabic,
                    style: GoogleFonts.amiri(
                      color: AppColors.gold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAyahList(bool isDark) {
    final surah = _surahs.firstWhere(
      (s) => s.number == _selectedSurah,
      orElse: () => const QuranSurah(
        number: 0,
        nameArabic: '',
        nameTurkish: '',
        nameTransliteration: '',
        ayahCount: 0,
        revelationType: '',
      ),
    );

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark ? const Color(0xFF1A2035) : Colors.white,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 18),
                color: AppColors.gold,
                onPressed: () => setState(() {
                  _selectedSurah = null;
                  _ayahs = [];
                }),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      surah.nameTurkish,
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${surah.ayahCount} ayet • ${surah.revelationType}',
                      style: GoogleFonts.notoSans(
                          color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Text(
                surah.nameArabic,
                style: GoogleFonts.amiri(color: AppColors.gold, fontSize: 22),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingAyahs
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold))
              : Container(
                  color: isDark
                      ? const Color(0xFF0A0E1A)
                      : const Color(0xFFFAF8F0),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: _ayahs.length,
                    itemBuilder: (_, i) => _buildAyahTile(_ayahs[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAyahTile(QuranAyah ayah) {
    final isSelected = widget.selectedAyah?.globalNumber == ayah.globalNumber;

    return QuranAyahTile(
      ayah: ayah,
      isSelected: isSelected,
      showMeal: widget.showMeal,
      arabicFontSize: widget.arabicFontSize,
      secondaryLabel: 'Sayfa ${ayah.page}',
      onTap: () => widget.onAyahSelected(ayah),
      onLongPress: () => _showNoteSheet(ayah),
    );
  }

  void _showNoteSheet(QuranAyah ayah) {
    final contentCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (ctx) => AnimatedPadding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: Container(
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
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.edit_note, color: AppColors.turquoise),
                  const SizedBox(width: 8),
                  Text('Tefekkür Notu',
                      style: GoogleFonts.playfairDisplay(
                          color: AppColors.gold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  ayah.displayArabic,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: 'UthmanicHafs',
                    color: AppColors.gold,
                    fontSize: 18,
                    height: 2.1,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentCtrl,
                maxLines: 4,
                autofocus: true,
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final content = contentCtrl.text.trim();
                    if (content.isEmpty) return;
                    await _noteRepo.addNote(
                      title: 'Ayet ${ayah.surahNumber}:${ayah.number}',
                      content: content,
                      tags: const ['ayet'],
                    );
                    if (mounted && ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tefekkür notu kaydedildi'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                  child: Text('Notu Kaydet',
                      style: GoogleFonts.notoSans(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
