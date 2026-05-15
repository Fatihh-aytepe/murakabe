import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/repositories/note_repository.dart';

class TefhimulKuranScreen extends StatefulWidget {
  const TefhimulKuranScreen({super.key});

  @override
  State<TefhimulKuranScreen> createState() => _TefhimulKuranScreenState();
}

class _TefhimulKuranScreenState extends State<TefhimulKuranScreen> {
  final _noteRepo = NoteRepository();
  final _pdfKey = GlobalKey<SfPdfViewerState>();
  final PdfViewerController _pdfController = PdfViewerController();

  int _currentPage = 1;
  int _totalPages = 0;
  bool _showToolbar = true;

  // Yer imleri: sayfa numaraları listesi
  List<int> _bookmarks = [];

  static const String _prefKeyPage = 'tefhimul_last_page';
  static const String _prefKeyBookmarks = 'tefhimul_bookmarks';
  static const String _assetPath = 'assets/tefsir/tefhimul_kuran.pdf';

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPage = prefs.getInt(_prefKeyPage) ?? 1;
    final savedBookmarks = prefs.getStringList(_prefKeyBookmarks) ?? [];
    setState(() {
      _currentPage = savedPage;
      _bookmarks = savedBookmarks.map((e) => int.tryParse(e) ?? 1).toList();
    });
  }

  Future<void> _saveCurrentPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyPage, page);
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        _prefKeyBookmarks, _bookmarks.map((e) => e.toString()).toList());
  }

  void _toggleBookmark() {
    final wasBookmarked = _bookmarks.contains(_currentPage);
    setState(() {
      if (wasBookmarked) {
        _bookmarks.remove(_currentPage);
      } else {
        _bookmarks.add(_currentPage);
        _bookmarks.sort();
      }
    });
    _saveBookmarks();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          wasBookmarked
              ? 'Yer imi kaldırıldı'
              : 'Sayfa $_currentPage yer imine eklendi',
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF1B3A4B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _goToPage(int page) {
    _pdfController.jumpToPage(page);
  }

  void _showGoToPageDialog() {
    final ctrl = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        title: Text(
          'Sayfaya Git',
          style: GoogleFonts.playfairDisplay(
              color: AppColors.gold, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: '1 — $_totalPages',
            hintStyle: const TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: Colors.white24),
              borderRadius: BorderRadius.circular(10),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: const BorderSide(color: AppColors.gold),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('İptal',
                style: GoogleFonts.notoSans(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
            onPressed: () {
              final p = int.tryParse(ctrl.text);
              if (p != null && p >= 1 && p <= _totalPages) {
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

  void _showBookmarksSheet() {
    if (_bookmarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Henüz yer imi eklenmedi'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A2035),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Yer İmleri',
            style: GoogleFonts.playfairDisplay(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _bookmarks.length,
              itemBuilder: (_, i) {
                final page = _bookmarks[i];
                return ListTile(
                  leading: const Icon(Icons.bookmark,
                      color: AppColors.gold, size: 20),
                  title: Text(
                    'Sayfa $page',
                    style: GoogleFonts.notoSans(color: Colors.white70),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.red, size: 18),
                    onPressed: () {
                      setState(() => _bookmarks.remove(page));
                      _saveBookmarks();
                      Navigator.pop(context);
                    },
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _goToPage(page);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showNoteSheet(int page) {
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
              const SizedBox(height: 4),
              Text(
                'Tefhimul Kuran — Sayfa $page',
                style:
                    GoogleFonts.notoSans(color: Colors.white38, fontSize: 12),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: contentCtrl,
                maxLines: 5,
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
                    final messenger = ScaffoldMessenger.of(context);
                    await _noteRepo.addNote(
                      title: 'Tefhimul Kuran — Sayfa $page',
                      content: content,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Not kaydedildi'),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBookmarked = _bookmarks.contains(_currentPage);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : Colors.white,
      body: Column(
        children: [
          // ── Başlık ──
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: _showToolbar
                ? MediaQuery.of(context).padding.top + 60
                : MediaQuery.of(context).padding.top,
            child: _showToolbar
                ? Container(
                    padding: EdgeInsets.fromLTRB(
                        8, MediaQuery.of(context).padding.top, 8, 0),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios,
                              color: Colors.white, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Tefhimul Kuran',
                                style: GoogleFonts.playfairDisplay(
                                  color: AppColors.gold,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_totalPages > 0)
                                Text(
                                  'Sayfa $_currentPage / $_totalPages',
                                  style: GoogleFonts.notoSans(
                                      color: Colors.white54, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                        // Not alma
                        IconButton(
                          icon: const Icon(Icons.edit_note,
                              color: AppColors.turquoise),
                          tooltip: 'Not Al',
                          onPressed: () => _showNoteSheet(_currentPage),
                        ),
                        // Yer imi
                        IconButton(
                          icon: Icon(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_outline,
                            color: AppColors.gold,
                          ),
                          onPressed: _toggleBookmark,
                        ),
                        // Yer imleri listesi
                        IconButton(
                          icon: const Icon(Icons.bookmarks_outlined,
                              color: Colors.white70),
                          onPressed: _showBookmarksSheet,
                        ),
                      ],
                    ),
                  )
                : const SizedBox(),
          ),

          // ── İlerleme çubuğu ──
          if (_showToolbar && _totalPages > 0)
            LinearProgressIndicator(
              value: _currentPage / _totalPages,
              backgroundColor: Colors.grey.shade800,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              minHeight: 2,
            ),

          // ── PDF görüntüleyici ──
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _showToolbar = !_showToolbar),
              child: SfPdfViewer.asset(
                _assetPath,
                key: _pdfKey,
                controller: _pdfController,
                initialPageNumber: _currentPage,
                onDocumentLoaded: (details) {
                  setState(() {
                    _totalPages = details.document.pages.count;
                  });
                  // Kayıtlı sayfaya git
                  if (_currentPage > 1) {
                    _pdfController.jumpToPage(_currentPage);
                  }
                },
                onPageChanged: (details) {
                  setState(() => _currentPage = details.newPageNumber);
                  _saveCurrentPage(details.newPageNumber);
                },
                onDocumentLoadFailed: (details) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('PDF yüklenemedi: ${details.description}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                },
              ),
            ),
          ),

          // ── Alt sayfa navigasyon ──
          if (_showToolbar && _totalPages > 0)
            Container(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
              color: isDark ? const Color(0xFF1A2035) : Colors.white,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    color: _currentPage > 1 ? AppColors.gold : Colors.grey,
                    onPressed: _currentPage > 1
                        ? () => _goToPage(_currentPage - 1)
                        : null,
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showGoToPageDialog,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          '$_currentPage / $_totalPages',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.notoSans(
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    color: _currentPage < _totalPages
                        ? AppColors.gold
                        : Colors.grey,
                    onPressed: _currentPage < _totalPages
                        ? () => _goToPage(_currentPage + 1)
                        : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
