import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/usecases/get_qibla_bearing.dart';

class KibleBulucuScreen extends StatefulWidget {
  const KibleBulucuScreen({super.key});

  @override
  State<KibleBulucuScreen> createState() => _KibleBulucuScreenState();
}

class _KibleBulucuScreenState extends State<KibleBulucuScreen> {
  final _getQiblaBearing = GetQiblaBearing();
  StreamSubscription<CompassEvent>? _compassSub;

  QiblaResult? _qibla;
  double? _heading;
  bool _isLoading = true;
  bool _compassAvailable = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
    _initCompass();
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    super.dispose();
  }

  void _initCompass() {
    final events = FlutterCompass.events;
    if (events == null) {
      setState(() => _compassAvailable = false);
      return;
    }
    _compassSub = events.listen((event) {
      if (!mounted) return;
      setState(() => _heading = event.heading);
    });
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await _getQiblaBearing();
    if (!mounted) return;
    setState(() {
      _qibla = result;
      _isLoading = false;
      if (result == null) {
        _errorMessage =
            'Konum alınamadı. Konum servisinin açık olduğundan ve izin verildiğinden emin ol.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B), Color(0xFF0D2233)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.gold))
                    : _errorMessage != null
                        ? _buildError()
                        : _buildCompass(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Text(
            'Kıble Bulucu',
            style: GoogleFonts.playfairDisplay(
              color: AppColors.gold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_off_outlined,
                color: Colors.white38, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.gold,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Tekrar Dene',
                  style: GoogleFonts.notoSans(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompass() {
    final qiblaBearing = _qibla!.bearing;
    final heading = _heading;
    final hasLiveHeading = _compassAvailable && heading != null;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            SizedBox(
              width: 280,
              height: 280,
              child: Transform.rotate(
                // Kadranı, telefonun gerçek yönünü yansıtsın diye ters
                // döndürüyoruz. Sensör/veri yoksa 0 kabul edilir — kadran
                // sabit kalır, sadece aşağıdaki sayısal açıya güvenilir.
                angle: hasLiveHeading ? -(heading * math.pi / 180) : 0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildDial(),
                    for (final dir in const [
                      {'label': 'K', 'angle': 0.0},
                      {'label': 'D', 'angle': 90.0},
                      {'label': 'G', 'angle': 180.0},
                      {'label': 'B', 'angle': 270.0},
                    ])
                      _buildDirectionLabel(
                          dir['label'] as String, dir['angle'] as double),
                    // Kıble oku — kadranın yerel çerçevesinde SABİT bir
                    // açıda (qiblaBearing) duruyor. Kadran dışarıdan
                    // -heading kadar döndüğü için, telefon fiziksel olarak
                    // döndükçe ok ekranda her zaman gerçek Kâbe yönünü
                    // gösterir.
                    Transform.rotate(
                      angle: qiblaBearing * math.pi / 180,
                      child: _buildQiblaArrow(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              '${qiblaBearing.toStringAsFixed(0)}°',
              style: GoogleFonts.playfairDisplay(
                color: AppColors.gold,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Kıble Açısı (Kuzeyden saat yönünde)',
              style: GoogleFonts.notoSans(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 20),
            if (!hasLiveHeading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _compassAvailable
                      ? 'Pusula verisi bekleniyor — telefonu havada 8 çizerek kalibre edebilirsin.'
                      : 'Cihazında pusula sensörü bulunamadı. Yukarıdaki açı '
                          'kuzeyi baz alarak hesaplandı — ayrı bir pusula '
                          'uygulamasıyla birlikte kullanabilirsin.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                      color: Colors.white38,
                      fontSize: 12,
                      fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDial() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border:
            Border.all(color: AppColors.gold.withValues(alpha: 0.4), width: 2),
        color: Colors.white.withValues(alpha: 0.03),
      ),
    );
  }

  Widget _buildDirectionLabel(String label, double angleDeg) {
    const radius = 120.0;
    final angle = angleDeg * math.pi / 180;
    // 0°'de (Kuzey) yukarıda başlayıp saat yönünde ilerler.
    final dx = radius * math.sin(angle);
    final dy = -radius * math.cos(angle);
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Text(
        label,
        style: GoogleFonts.notoSans(
          color: label == 'K' ? AppColors.gold : Colors.white54,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildQiblaArrow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.mosque, color: AppColors.gold, size: 22),
        const Icon(Icons.navigation, color: AppColors.gold, size: 48),
      ],
    );
  }
}
