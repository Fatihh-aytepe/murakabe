import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/note_repository.dart';

class QuranPageView extends StatefulWidget {
  final int initialPage;
  final Qari selectedQari;
  final QuranAyah? selectedAyah;
  final bool showMeal;
  final void Function(int page, int surah, int ayah) onProgressChanged;
  final void Function(QuranAyah ayah) onAyahSelected;

  const QuranPageView({
    super.key,
    required this.initialPage,
    required this.selectedQari,
    this.selectedAyah,
    this.showMeal = true,
    required this.onProgressChanged,
    required this.onAyahSelected,
  });

  @override
  State<QuranPageView> createState() => _QuranPageViewState();
}

class _QuranPageViewState extends State<QuranPageView> {
  final _repo = QuranRepository();
  final _noteRepo = NoteRepository();
  late PageController _pageController;

  int _currentPage = 1;
  static const int _totalPages = 604;

  // Cache — yüklenen sayfalar tekrar API'ya gitmez
  final Map<int, List<QuranAyah>> _pageCache = {};
  final Set<int> _loadingPages = {};

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage.clamp(1, _totalPages);
    _pageController = PageController(initialPage: _currentPage - 1);
    _preloadPage(_currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _preloadPage(int page) async {
    if (_pageCache.containsKey(page)) return;
    if (_loadingPages.contains(page)) return;

    _loadingPages.add(page);
    final ayahs = await _repo.getAyahsByPage(page);
    if (mounted) {
      setState(() {
        _pageCache[page] = ayahs;
        _loadingPages.remove(page);
      });
      // İlerleme kaydet
      if (ayahs.isNotEmpty) {
        widget.onProgressChanged(
            page, ayahs.first.surahNumber, ayahs.first.number);
      }
    }
    // Sonraki sayfayı arka planda prefetch et
    if (page < _totalPages && !_pageCache.containsKey(page + 1)) {
      _repo.getAyahsByPage(page + 1).then((a) {
        if (mounted) setState(() => _pageCache[page + 1] = a);
      });
    }
  }

  void _onPageChanged(int index) {
    final page = index + 1;
    setState(() => _currentPage = page);
    _preloadPage(page);
  }

  void _goToPage(int page) {
    final target = page.clamp(1, _totalPages);
    _pageController.animateToPage(
      target - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Sayfa numarası + gezinme
        _buildPageNav(isDark),

        // Sayfa içeriği
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            reverse: true,
            onPageChanged: _onPageChanged,
            itemCount: _totalPages,
            itemBuilder: (_, index) {
              final page = index + 1;
              final ayahs = _pageCache[page];

              if (ayahs == null) {
                // Sayfa henüz yüklenmemişse yükle
                _preloadPage(page);
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                );
              }

              return _buildPageContent(ayahs, isDark);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPageNav(bool isDark) {
    final bg = isDark ? const Color(0xFF1A2035) : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: bg,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            color: _currentPage < _totalPages ? AppColors.gold : Colors.grey,
            onPressed: _currentPage < _totalPages
                ? () => _goToPage(_currentPage + 1)
                : null,
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _showGoToPageDialog(),
              child: Column(
                children: [
                  Text(
                    'Sayfa $_currentPage / $_totalPages',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSans(
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  // İlerleme çubuğu
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _currentPage / _totalPages,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            color: _currentPage > 1 ? AppColors.gold : Colors.grey,
            onPressed:
                _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent(List<QuranAyah> ayahs, bool isDark) {
    final bg = isDark ? const Color(0xFF0A0E1A) : const Color(0xFFFAF8F0);
    final arabicColor = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final turkishColor = isDark ? Colors.white60 : AppColors.textSecondary;

    return Container(
      color: bg,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
        itemCount: ayahs.length,
        itemBuilder: (_, i) {
          final ayah = ayahs[i];
          return _buildAyahTile(ayah, arabicColor, turkishColor, isDark);
        },
      ),
    );
  }

  Widget _buildAyahTile(
    QuranAyah ayah,
    Color arabicColor,
    Color turkishColor,
    bool isDark,
  ) {
    final isSelected =
        widget.selectedAyah?.globalNumber == ayah.globalNumber;

    return GestureDetector(
      onTap: () => widget.onAyahSelected(ayah),
      onLongPress: () => _showNoteSheet(ayah),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected
              ? AppColors.gold.withValues(alpha: 0.12)
              : isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
          border: isSelected
              ? Border.all(color: AppColors.gold.withValues(alpha: 0.5), width: 1)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _buildAyahNumber(ayah.number, isSelected),
                const Spacer(),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.volume_up,
                            color: AppColors.gold, size: 10),
                        const SizedBox(width: 3),
                        Text(
                          'Seçili',
                          style: GoogleFonts.notoSans(
                              color: AppColors.gold, fontSize: 9),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    '${ayah.surahNumber}:${ayah.number}',
                    style:
                        GoogleFonts.notoSans(color: Colors.grey, fontSize: 10),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ayah.arabic,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: GoogleFonts.amiri(
                fontSize: widget.showMeal ? 26 : 32,
                color: isSelected ? AppColors.gold : arabicColor,
                height: 2.0,
              ),
            ),
            if (widget.showMeal) ...[
              const SizedBox(height: 6),
              Text(
                ayah.turkish,
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  color: turkishColor,
                  height: 1.6,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAyahNumber(int number, [bool isSelected = false]) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppColors.gold : Colors.transparent,
        border: Border.all(
          color: isSelected
              ? AppColors.gold
              : AppColors.gold.withValues(alpha: 0.6),
        ),
      ),
      child: Center(
        child: Text(
          '$number',
          style: GoogleFonts.notoSans(
            color: isSelected ? Colors.white : AppColors.gold,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showGoToPageDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sayfaya Git',
            style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '1 — 604',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () {
              final p = int.tryParse(ctrl.text);
              if (p != null) {
                Navigator.pop(context);
                _goToPage(p);
              }
            },
            child:
                Text('Git', style: GoogleFonts.notoSans(color: Colors.black)),
          ),
        ],
      ),
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
              // Ayet önizleme
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${ayah.surahNumber}:${ayah.number} — ${ayah.arabic}',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.amiri(color: AppColors.gold, fontSize: 16),
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
                    final title = 'Ayet ${ayah.surahNumber}:${ayah.number}';
                    await _noteRepo.addNote(title: title, content: content);
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
