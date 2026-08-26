import 'dart:math' as math;
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/widget_bridge_service.dart';
import '../../data/repositories/zikir_repository.dart';

class ZikirSayacScreen extends StatefulWidget {
  const ZikirSayacScreen({super.key});

  @override
  State<ZikirSayacScreen> createState() => _ZikirSayacScreenState();
}

class _ZikirSayacScreenState extends State<ZikirSayacScreen>
    with SingleTickerProviderStateMixin {
  final _repo = ZikirRepository();

  ActiveZikir? _active;
  int _count = 0;
  bool _isLoading = true;
  bool _showCelebration = false;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _load();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final active = await _repo.getActiveZikir();
      if (!mounted) return;
      setState(() {
        _active = active;
        _count = _repo.currentCount;
        _isLoading = false;
      });
      // Aktif zikir özelleştirilmiş/temizlenmiş olabilir — widget'ı tazele.
      WidgetBridgeService().refreshZikirAndNotify();
    } catch (e) {
      debugPrint('❌ Zikir yüklenemedi: $e');
      if (!mounted) return;
      // Veri çekilemese bile ekran sonsuza dek dönen bir yükleme
      // göstergesinde takılı kalmasın diye güvenli bir varsayılanla devam et.
      setState(() {
        _active = ActiveZikir(
          isCustom: false,
          turkish: 'Sübhanallah',
          arabic: '',
          meaning: '',
          target: 33,
        );
        _count = _repo.currentCount;
        _isLoading = false;
      });
    }
  }

  // ── ZİKRİ ÖZELLEŞTİR ──────────────────────────────────────────────────────
  // Kullanıcı kendi zikrini (Türkçe metin, opsiyonel Arapça, hedef sayı,
  // opsiyonel süre) girebilir. setCustomZikir zaten repository katmanında
  // vardı ama hiçbir ekran çağırmıyordu — bu eksik olan giriş noktasıydı.
  void _showCustomizeSheet() {
    final turkishCtrl = TextEditingController(
      text: _repo.isCustomActive ? (_active?.turkish ?? '') : '',
    );
    final arabicCtrl = TextEditingController(
      text: _repo.isCustomActive ? (_active?.arabic ?? '') : '',
    );
    int target = _repo.isCustomActive ? (_active?.target ?? 33) : 33;
    int? durationDays; // null = süresiz

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF2A1500),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Zikri Özelleştir',
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: turkishCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Zikir (Türkçe)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      hintText: 'Örn: Sübhanallah',
                      hintStyle: const TextStyle(color: Colors.white24),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.gold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: arabicCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Arapça (opsiyonel)',
                      labelStyle: const TextStyle(color: Colors.white54),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.gold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text('Hedef sayı',
                          style: GoogleFonts.notoSans(
                              color: Colors.white70, fontSize: 13)),
                      const Spacer(),
                      IconButton(
                        onPressed: () => setSheetState(
                            () => target = (target - 1).clamp(1, 9999)),
                        icon: const Icon(Icons.remove_circle_outline,
                            color: AppColors.gold),
                      ),
                      Text('$target',
                          style: GoogleFonts.playfairDisplay(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () => setSheetState(
                            () => target = (target + 1).clamp(1, 9999)),
                        icon: const Icon(Icons.add_circle_outline,
                            color: AppColors.gold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Süre',
                      style: GoogleFonts.notoSans(
                          color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final opt in [null, 7, 30, 90])
                        GestureDetector(
                          onTap: () => setSheetState(() => durationDays = opt),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: durationDays == opt
                                  ? AppColors.gold
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: durationDays == opt
                                    ? AppColors.gold
                                    : Colors.white24,
                              ),
                            ),
                            child: Text(
                              opt == null ? 'Süresiz' : '$opt gün',
                              style: GoogleFonts.notoSans(
                                color: durationDays == opt
                                    ? Colors.black
                                    : Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      if (_repo.isCustomActive)
                        TextButton(
                          onPressed: () async {
                            await _repo.clearCustomZikir();
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);
                            await _load();
                          },
                          child: Text('Varsayılana dön',
                              style: GoogleFonts.notoSans(
                                  color: Colors.white54, fontSize: 13)),
                        ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () async {
                          final text = turkishCtrl.text.trim();
                          if (text.isEmpty) return;
                          await _repo.setCustomZikir(
                            turkish: text,
                            arabic: arabicCtrl.text.trim(),
                            target: target,
                            durationDays: durationDays,
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          await _load();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Kaydet',
                            style: GoogleFonts.notoSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap() async {
    if (_active == null || _showCelebration) return;
    HapticFeedback.mediumImpact();
    _pulseController.forward().then((_) {
      if (mounted) _pulseController.reverse();
    });

    final completed = await _repo.increment();
    if (!mounted) return;
    setState(() => _count = _repo.currentCount);
    WidgetBridgeService().refreshZikirAndNotify();

    if (completed) {
      HapticFeedback.heavyImpact();
      setState(() => _showCelebration = true);
      await Future.delayed(const Duration(milliseconds: 2200));
      if (!mounted) return;
      setState(() => _showCelebration = false);
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2035),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Sayacı Sıfırla',
          style: GoogleFonts.notoSans(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Zikir sayacını sıfırlamak istediğine emin misin?',
          style: GoogleFonts.notoSans(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style: GoogleFonts.notoSans(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sıfırla',
              style: GoogleFonts.notoSans(
                  color: AppColors.gold, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _repo.resetCount();
      if (!mounted) return;
      setState(() => _count = 0);
      WidgetBridgeService().refreshZikirAndNotify();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A00),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A0A00), Color(0xFF3D1A00), Color(0xFF1A0A00)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _isLoading || _active == null
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.gold))
              : Stack(
                  children: [
                    Column(
                      children: [
                        _buildTopBar(),
                        _buildZikirTextCard(),
                        Expanded(child: _buildRingAndButton()),
                        _buildBottomActions(),
                      ],
                    ),
                    if (_showCelebration) _buildCelebrationOverlay(),
                  ],
                ),
        ),
      ),
    );
  }

  // ── ÜST BAR: geri + güncel sayı (sol) + hedef (sağ) ──────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new,
                    color: Colors.white70, size: 18),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GÜNCEL SAYI',
                    style: GoogleFonts.notoSans(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 1.2),
                  ),
                  Text(
                    '$_count',
                    style: GoogleFonts.playfairDisplay(
                        color: AppColors.goldLight,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'HEDEF',
                    style: GoogleFonts.notoSans(
                        color: Colors.white38,
                        fontSize: 10,
                        letterSpacing: 1.2),
                  ),
                  Text(
                    '${_active!.target}',
                    style: GoogleFonts.notoSans(
                        color: AppColors.turquoiseLight,
                        fontSize: 16,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              IconButton(
                onPressed: _showCustomizeSheet,
                tooltip: 'Zikri özelleştir',
                icon: const Icon(Icons.tune, color: Colors.white70, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── ZİKİR METNİ KARTI ─────────────────────────────────────────────────────
  Widget _buildZikirTextCard() {
    final active = _active!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            if (active.isCustom)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.turquoise.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'ÖZEL ZİKRİN',
                    style: GoogleFonts.notoSans(
                        color: AppColors.turquoiseLight,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                  ),
                ),
              ),
            if (active.arabic.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  active.arabic,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: const TextStyle(
                    fontFamily: 'NotoNaskhArabic',
                    color: AppColors.goldLight,
                    fontSize: 26,
                    height: 1.6,
                  ),
                ),
              ),
            Text(
              active.turkish,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            if (active.meaning.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  active.meaning,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                      color: Colors.white54,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── TESBİH HALKASI + ORTA BUTON ───────────────────────────────────────────
  Widget _buildRingAndButton() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size =
            math.min(constraints.maxWidth, constraints.maxHeight) * 0.82;
        final center = size / 2;
        final ringRadius = size / 2 - 16;
        final target = _active!.target < 1 ? 1 : _active!.target;

        final beadCount = target.clamp(1, 100);
        // Boncuklar ORANTISAL doldurulur (count / target). Böylece hedef
        // 100'den büyük ve boncuk sayısına tam bölünmese bile (örn. 101,
        // 997 gibi asal sayılar), hedefe ulaşıldığında halka HER ZAMAN
        // tam dolu görünür — kaç boncuğun kaça denk geldiği önemsizleşir.
        final progress = (_count / target).clamp(0.0, 1.0);
        final coloredBeads = (progress * beadCount).round().clamp(0, beadCount);

        return Center(
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (int i = 0; i < beadCount; i++)
                  _buildBead(
                    index: i,
                    total: beadCount,
                    isFilled: i < coloredBeads,
                    center: center,
                    radius: ringRadius,
                  ),
                _buildCenterButton(size * 0.42),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBead({
    required int index,
    required int total,
    required bool isFilled,
    required double center,
    required double radius,
  }) {
    // 12 hizasından (-90°) başlayıp saat yönünde diz
    final angle = (2 * math.pi * index / total) - (math.pi / 2);
    final dx = center + radius * math.cos(angle);
    final dy = center + radius * math.sin(angle);
    final beadSize = total > 60 ? 6.0 : (total > 33 ? 9.0 : 13.0);

    return Positioned(
      left: dx - beadSize / 2,
      top: dy - beadSize / 2,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: beadSize,
        height: beadSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isFilled
              ? const LinearGradient(
                  colors: [Color(0xFF9C7A5A), Color(0xFF5D4037)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isFilled ? null : Colors.transparent,
          border: Border.all(
            color: isFilled ? const Color(0xFF3E2723) : Colors.white24,
            width: 1,
          ),
          boxShadow: isFilled
              ? [
                  BoxShadow(
                    color: const Color(0xFF8D6E63).withValues(alpha: 0.5),
                    blurRadius: 5,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _buildCenterButton(double buttonSize) {
    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) => Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        ),
        child: Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF9C7A5A), Color(0xFF4E342E)],
            ),
            border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.6), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.25),
                blurRadius: 26,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_outlined,
                    color: Colors.white.withValues(alpha: 0.75),
                    size: buttonSize * 0.2),
                const SizedBox(height: 6),
                Text(
                  '$_count',
                  style: GoogleFonts.playfairDisplay(
                    color: Colors.white,
                    fontSize: buttonSize * 0.22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── ALT AKSİYON: sıfırla ──────────────────────────────────────────────────
  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 4),
      child: TextButton.icon(
        onPressed: _confirmReset,
        icon: const Icon(Icons.refresh, color: Colors.white38, size: 18),
        label: Text(
          'Sayacı Sıfırla',
          style: GoogleFonts.notoSans(color: Colors.white38, fontSize: 13),
        ),
      ),
    );
  }

  // ── KUTLAMA OVERLAY ────────────────────────────────────────────────────────
  Widget _buildCelebrationOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: ZoomIn(
            duration: const Duration(milliseconds: 450),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                gradient: AppColors.goldGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.4),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎉', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 12),
                  Text(
                    'Mâşallah!',
                    style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Hedefi tamamladınız',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSans(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 15,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
