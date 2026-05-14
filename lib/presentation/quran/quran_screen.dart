import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../data/repositories/quran_repository.dart';
import 'quran_page_view.dart';
import 'quran_surah_view.dart';
import 'quran_audio_bar.dart';

class QuranScreen extends StatefulWidget {
  const QuranScreen({super.key});

  @override
  State<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends State<QuranScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _repo = QuranRepository();

  QuranProgress? _progress;
  bool _isLoading = true;

  // Ses çubuğu için seçili ayet
  QuranAyah? _selectedAyah;
  Qari _selectedQari = kQariler.first;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadProgress();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProgress() async {
    final progress = await _repo.loadProgress();
    if (mounted) {
      setState(() {
        _progress = progress;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProgress({
    required int page,
    required int surah,
    required int ayah,
  }) async {
    await _repo.saveProgress(page: page, surah: surah, ayah: ayah);
    if (mounted) {
      setState(() {
        _progress = QuranProgress(
          lastPage: page,
          lastSurah: surah,
          lastAyah: ayah,
          updatedAt: DateTime.now(),
        );
      });
    }
  }

  void _onAyahSelected(QuranAyah ayah) {
    setState(() => _selectedAyah = ayah);
  }

  void _onQariChanged(Qari qari) {
    setState(() => _selectedQari = qari);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0E1A) : const Color(0xFFFAF8F0),
      body: Column(
        children: [
          // ── Başlık ──
          _buildHeader(isDark),

          // ── Tab bar ──
          Container(
            color: isDark ? const Color(0xFF0D1B2A) : const Color(0xFF0D1B2A),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AppColors.gold,
              indicatorWeight: 2,
              labelColor: AppColors.gold,
              unselectedLabelColor: Colors.white54,
              labelStyle: GoogleFonts.notoSans(
                  fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Sayfa'),
                Tab(text: 'Sure'),
              ],
            ),
          ),

          // ── İçerik ──
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      QuranPageView(
                        initialPage: _progress?.lastPage ?? 1,
                        selectedQari: _selectedQari,
                        selectedAyah: _selectedAyah,
                        onProgressChanged: (page, surah, ayah) =>
                            _saveProgress(page: page, surah: surah, ayah: ayah),
                        onAyahSelected: _onAyahSelected,
                      ),
                      QuranSurahView(
                        initialSurah: _progress?.lastSurah ?? 1,
                        initialAyah: _progress?.lastAyah ?? 1,
                        selectedQari: _selectedQari,
                        selectedAyah: _selectedAyah,
                        onProgressChanged: (page, surah, ayah) =>
                            _saveProgress(page: page, surah: surah, ayah: ayah),
                        onAyahSelected: _onAyahSelected,
                      ),
                    ],
                  ),
          ),

          // ── Ses çubuğu ──
          QuranAudioBar(
            ayah: _selectedAyah,
            qari: _selectedQari,
            availableQariler: kQariler,
            onQariChanged: _onQariChanged,
            audioUrlBuilder: (ayah, qari) => _repo.getAudioUrl(ayah, qari),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 8, 16, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon:
                const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kuran-ı Kerim',
                  style: GoogleFonts.playfairDisplay(
                    color: AppColors.gold,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_progress != null)
                  Text(
                    'Kaldığın yer: Sayfa ${_progress!.lastPage}',
                    style: GoogleFonts.notoSans(
                        color: Colors.white54, fontSize: 11),
                  ),
              ],
            ),
          ),
          // Kaldığım yere git
          if (_progress != null)
            TextButton.icon(
              onPressed: () {
                _tabController.animateTo(0);
              },
              icon: const Icon(Icons.bookmark, color: AppColors.gold, size: 16),
              label: Text(
                'Devam Et',
                style:
                    GoogleFonts.notoSans(color: AppColors.gold, fontSize: 12),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
    );
  }
}
