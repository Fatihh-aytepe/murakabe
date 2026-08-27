import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../domain/usecases/get_qibla_bearing.dart';

/// Kıble Bulucu — temiz bir "normal ekran" (başlık → konum → büyük pusula →
/// anlık tek yönlendirme → kıble yönü/açısı) ve gerektiğinde bunun ÜZERİNE
/// açılan, otomatik kapanan bir kalibrasyon overlay'inden oluşur.
///
/// Önemli tasarım kararları (bkz. ilgili yorumlar):
/// - Kıble bearing'i Geolocator'ın test edilmiş büyük daire (great circle)
///   formülüyle hesaplanıyor (bkz. GetQiblaBearing) — burada elle trigonometri
///   yazılmıyor.
/// - Cihaz heading'i flutter_compass'tan geliyor. iOS'ta konum izni varsa
///   plugin zaten `trueHeading`'i kullanıyor (gerçek kuzey); Android'de
///   plugin manyetik alan sensörünün ham (manyetik) heading'ini veriyor —
///   iki platform arasındaki bu fark flutter_compass'ın kendi sınırıdır,
///   burada "true heading" simüle edilmiyor, platformun verdiği en iyi değer
///   kullanılıyor.
/// - `accuracy` alanı her iki platformda da DERECE cinsinden bir hata payı
///   (küçük = daha güvenilir; null/negatif = bilinmiyor/güvenilmez) —
///   Android SENSOR_STATUS sabitlerini (HIGH→15°, MEDIUM→30°, LOW→45°,
///   UNRELIABLE→-1) dereceye çeviriyor, iOS ise CLHeading.headingAccuracy'yi
///   doğrudan derece olarak veriyor. Bu yüzden tek bir eşik değeriyle
///   (aşağıdaki `_accuracyGoodThresholdDeg`) iki platformu da tutarlı
///   şekilde değerlendirebiliyoruz.
class KibleBulucuScreen extends StatefulWidget {
  const KibleBulucuScreen({super.key});

  @override
  State<KibleBulucuScreen> createState() => _KibleBulucuScreenState();
}

class _KibleBulucuScreenState extends State<KibleBulucuScreen>
    with SingleTickerProviderStateMixin {
  final _getQiblaBearing = GetQiblaBearing();
  StreamSubscription<CompassEvent>? _compassSub;
  Timer? _staleCheckTimer;
  Timer? _calibrationEnterTimer;
  final DateTime _initTime = DateTime.now();

  // ── Konum ────────────────────────────────────────────────────────────────
  QiblaResult? _qibla;
  String? _locationLabel;
  bool _isLoadingLocation = true;
  String? _locationError;

  // ── Pusula / sensör ─────────────────────────────────────────────────────
  double? _smoothedHeading; // 0-360, düşük geçiren filtre uygulanmış
  double? _headingAccuracyDeg; // derece; küçük=iyi, null/negatif=bilinmiyor
  bool _compassAvailable = true;
  bool _hasHeadingData = false;
  DateTime? _lastEventAt;

  // ── Kalibrasyon overlay durumu ──────────────────────────────────────────
  bool _showCalibrationOverlay = false;
  int _goodAccuracyStreak = 0;
  DateTime? _manualDismissUntil;

  // ── Sağ/sol yönlendirme histerezisi ─────────────────────────────────────
  bool _isAligned = false;

  // Ayarlanabilir eşikler — küçük sensör dalgalanmalarının metni sürekli
  // değiştirmemesi için histerezis bantları kullanılıyor.
  static const double _accuracyGoodThresholdDeg = 35.0;
  static const double _alignedEnterDeg = 6.0;
  static const double _alignedExitDeg = 10.0;
  static const Duration _calibrationEnterDelay = Duration(milliseconds: 1200);
  static const Duration _staleHeadingTimeout = Duration(seconds: 3);
  static const Duration _manualDismissCooldown = Duration(seconds: 15);

  late final AnimationController _infinityController;

  @override
  void initState() {
    super.initState();
    _infinityController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _loadLocation();
    _initCompass();
    _staleCheckTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _checkStaleHeading());
  }

  @override
  void dispose() {
    _compassSub?.cancel();
    _staleCheckTimer?.cancel();
    _calibrationEnterTimer?.cancel();
    _infinityController.dispose();
    super.dispose();
  }

  // ── Konum yükleme ────────────────────────────────────────────────────────

  Future<void> _loadLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });
    // Konum izni/servis kontrolü GetQiblaBearing → LocationService içinde
    // ele alınıyor; burada sadece sonucu UI durumuna çeviriyoruz. Bu, konum
    // problemini kalibrasyon/sensör problemünden ayrı tutuyor: konum
    // alınamazsa aşağıda ayrı bir hata ekranı gösteriliyor, kalibrasyon
    // overlay'i asla bu yüzden açılmıyor.
    final result = await _getQiblaBearing();
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _isLoadingLocation = false;
        _locationError =
            'Konum alınamadı. Konum servisinin açık olduğundan ve izin verildiğinden emin ol.';
      });
      return;
    }
    setState(() {
      _qibla = result;
      _locationLabel =
          '${result.latitude.toStringAsFixed(3)}, ${result.longitude.toStringAsFixed(3)}';
      _isLoadingLocation = false;
    });
    unawaited(_resolveLocationLabel(result.latitude, result.longitude));
  }

  /// Enlem/boylamı okunabilir "Şehir, Ülke" biçimine çevirir. Başarısız
  /// olursa (ağ yok, platform desteklemiyor vb.) sessizce koordinat
  /// etiketinde kalınır — bu bir konum HATASI değildir, kıble hesabını
  /// etkilemez, sadece görüntülenen isim daha az okunaklı olur.
  Future<void> _resolveLocationLabel(double lat, double lng) async {
    try {
      final placemarks =
          await geocoding.Geocoding().placemarkFromCoordinates(lat, lng);
      if (!mounted || placemarks.isEmpty) return;
      final p = placemarks.first;
      String? city;
      for (final candidate in [
        p.locality,
        p.subAdministrativeArea,
        p.administrativeArea,
      ]) {
        if (candidate != null && candidate.trim().isNotEmpty) {
          city = candidate.trim();
          break;
        }
      }
      final country = p.country?.trim() ?? '';
      final label = [
        if (city != null && city.isNotEmpty) city,
        if (country.isNotEmpty) country,
      ].join(', ');
      if (label.isNotEmpty && mounted) {
        setState(() => _locationLabel = label);
      }
    } catch (_) {
      // Reverse geocoding başarısız — koordinat etiketi zaten gösteriliyor.
    }
  }

  // ── Pusula sensörü ───────────────────────────────────────────────────────

  void _initCompass() {
    final events = FlutterCompass.events;
    if (events == null) {
      setState(() => _compassAvailable = false);
      return;
    }
    _compassSub = events.listen(_onCompassEvent, onError: (_) {
      if (!mounted) return;
      setState(() => _compassAvailable = false);
    });
  }

  void _onCompassEvent(CompassEvent event) {
    if (!mounted) return;
    final heading = event.heading;
    if (heading == null) return; // ilk okumalar bazı cihazlarda null gelebilir

    setState(() {
      _hasHeadingData = true;
      _lastEventAt = DateTime.now();
      _smoothedHeading = _lowPassHeading(_smoothedHeading, heading);
      _headingAccuracyDeg = event.accuracy;
      _evaluateCalibration();
      _evaluateAlignment();
    });
  }

  /// Dairesel (0/360 sarımlı) düşük geçiren filtre: ani sensör
  /// dalgalanmalarını yumuşatır ama gerçek dönüşe gecikmeden tepki verir.
  double _lowPassHeading(double? previous, double next, {double alpha = 0.2}) {
    if (previous == null) return next;
    final delta = _shortestDiff(next, previous);
    return (previous + alpha * delta + 360) % 360;
  }

  /// `a - b` farkını en kısa dönüş yönünü verecek şekilde [-180, 180)
  /// aralığına normalize eder.
  double _shortestDiff(double a, double b) => ((a - b + 540) % 360) - 180;

  void _checkStaleHeading() {
    if (!mounted || !_compassAvailable) return;
    final noDataYet = !_hasHeadingData &&
        DateTime.now().difference(_initTime) >
            const Duration(seconds: 2, milliseconds: 500);
    final stale = _hasHeadingData &&
        _lastEventAt != null &&
        DateTime.now().difference(_lastEventAt!) > _staleHeadingTimeout;
    if (noDataYet || stale) {
      setState(() {
        _headingAccuracyDeg = -1;
        _evaluateCalibration();
      });
    }
  }

  bool get _accuracyIsGood {
    final acc = _headingAccuracyDeg;
    if (acc == null || acc < 0) return false;
    return acc <= _accuracyGoodThresholdDeg;
  }

  /// Kalibrasyon overlay'inin açılıp kapanma mantığı: küçük dalgalanmalarla
  /// sürekli açılıp kapanmasın diye hem açılışta kısa bir gecikme, hem
  /// kapanışta ardışık birkaç iyi okuma şartı (histerezis) uygulanıyor.
  /// Kullanıcı overlay'i elle kapatırsa bir süre tekrar açılmıyor.
  void _evaluateCalibration() {
    final good = _accuracyIsGood;
    if (good) {
      _goodAccuracyStreak++;
      _calibrationEnterTimer?.cancel();
      _calibrationEnterTimer = null;
      if (_showCalibrationOverlay && _goodAccuracyStreak >= 3) {
        _showCalibrationOverlay = false;
      }
    } else {
      _goodAccuracyStreak = 0;
      final dismissedUntil = _manualDismissUntil;
      final suppressed =
          dismissedUntil != null && DateTime.now().isBefore(dismissedUntil);
      if (!_showCalibrationOverlay &&
          !suppressed &&
          _calibrationEnterTimer == null) {
        _calibrationEnterTimer = Timer(_calibrationEnterDelay, () {
          _calibrationEnterTimer = null;
          if (!mounted) return;
          setState(() => _showCalibrationOverlay = true);
        });
      }
    }
  }

  void _dismissCalibrationManually() {
    setState(() {
      _showCalibrationOverlay = false;
      _manualDismissUntil = DateTime.now().add(_manualDismissCooldown);
    });
  }

  void _evaluateAlignment() {
    final qibla = _qibla;
    final heading = _smoothedHeading;
    if (qibla == null || heading == null) return;
    final diff = _shortestDiff(qibla.bearing, heading).abs();
    if (_isAligned) {
      if (diff > _alignedExitDeg) _isAligned = false;
    } else {
      if (diff <= _alignedEnterDeg) _isAligned = true;
    }
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0B111F) : const Color(0xFFF7F7F8);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(isDark),
                _buildLocationField(isDark),
                Expanded(
                  child: _isLoadingLocation
                      ? const Center(
                          child:
                              CircularProgressIndicator(color: AppColors.gold),
                        )
                      : _locationError != null
                          ? _buildLocationErrorState(isDark)
                          : _buildQiblaContent(isDark),
                ),
              ],
            ),
            if (_showCalibrationOverlay) _buildCalibrationOverlay(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final chipBg = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          _roundIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
            bg: chipBg,
            color: textColor,
          ),
          Expanded(
            child: Text(
              'Kıble Bulucu',
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                color: textColor,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _roundIconButton(
            icon: Icons.info_outline_rounded,
            onTap: () => _showInfoSheet(isDark),
            bg: chipBg,
            color: textColor,
          ),
        ],
      ),
    );
  }

  Widget _roundIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color bg,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildLocationField(bool isDark) {
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final labelColor = isDark ? Colors.white54 : AppColors.textLight;
    final valueColor = isDark ? Colors.white : AppColors.textPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.location_on_outlined,
                color: AppColors.gold.withValues(alpha: 0.9), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Konumunuz',
                      style: GoogleFonts.notoSans(
                          color: labelColor, fontSize: 11.5)),
                  const SizedBox(height: 2),
                  Text(
                    _isLoadingLocation
                        ? 'Konum belirleniyor...'
                        : (_locationLabel ?? '—'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSans(
                      color: valueColor,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _loadLocation,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.my_location_rounded,
                    color: AppColors.gold, size: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationErrorState(bool isDark) {
    final textColor = isDark ? Colors.white70 : AppColors.textSecondary;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined,
                color: textColor.withValues(alpha: 0.6), size: 44),
            const SizedBox(height: 16),
            Text(
              _locationError!,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(color: textColor, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadLocation,
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

  Widget _buildQiblaContent(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dialSize =
            math.min(constraints.maxWidth * 0.86, constraints.maxHeight * 0.64)
                .clamp(200.0, 380.0)
                .toDouble();
        return Column(
          children: [
            Expanded(
              child: Center(child: _buildCompass(isDark, dialSize)),
            ),
            _buildDirectionHint(isDark),
            const SizedBox(height: 14),
            _buildInfoCard(isDark),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildCompass(bool isDark, double dialSize) {
    final qibla = _qibla!;
    final heading = _smoothedHeading;
    final hasLiveHeading = _compassAvailable && heading != null;

    return SizedBox(
      width: dialSize,
      height: dialSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            // Kadranı telefonun gerçek yönüne göre ters döndürüyoruz —
            // sensör yoksa/henüz veri gelmediyse kadran sabit kalır, sadece
            // aşağıdaki sayısal açı ve kart güvenilir olur.
            angle: hasLiveHeading ? -(heading * math.pi / 180) : 0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildDialFace(isDark, dialSize),
                CustomPaint(
                  size: Size(dialSize, dialSize),
                  painter: _CompassTicksPainter(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppColors.textLight.withValues(alpha: 0.5),
                  ),
                ),
                for (final dir in const [
                  {'label': 'K', 'angle': 0.0},
                  {'label': 'D', 'angle': 90.0},
                  {'label': 'G', 'angle': 180.0},
                  {'label': 'B', 'angle': 270.0},
                ])
                  _buildDirectionLabel(
                    dir['label'] as String,
                    dir['angle'] as double,
                    dialSize,
                    isDark,
                  ),
                // Kıble göstergesi kadranın yerel çerçevesinde SABİT bir
                // açıda (qiblaBearing) duruyor. Kadran dışarıdan -heading
                // kadar döndüğü için, telefon fiziksel olarak döndükçe
                // gösterge ekranda her zaman gerçek Kâbe yönünü işaret eder.
                Transform.rotate(
                  angle: qibla.bearing * math.pi / 180,
                  child: _buildQiblaNeedle(isDark, dialSize),
                ),
              ],
            ),
          ),
          if (!hasLiveHeading) _buildNoHeadingBadge(isDark, dialSize),
        ],
      ),
    );
  }

  Widget _buildDialFace(bool isDark, double dialSize) {
    return Container(
      width: dialSize,
      height: dialSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : AppColors.textLight.withValues(alpha: 0.25),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionLabel(
      String label, double angleDeg, double dialSize, bool isDark) {
    final radius = dialSize / 2 - 22;
    final angle = angleDeg * math.pi / 180;
    // 0°'de (Kuzey) yukarıda başlayıp saat yönünde ilerler.
    final dx = radius * math.sin(angle);
    final dy = -radius * math.cos(angle);
    final isNorth = label == 'K';
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Text(
        label,
        style: GoogleFonts.notoSans(
          color: isNorth
              ? AppColors.gold
              : (isDark ? Colors.white54 : AppColors.textSecondary),
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNoHeadingBadge(bool isDark, double dialSize) {
    final textColor = isDark ? Colors.white38 : AppColors.textLight;
    return Positioned(
      bottom: 6,
      child: SizedBox(
        width: dialSize * 0.72,
        child: Text(
          _compassAvailable
              ? 'Pusula verisi bekleniyor...'
              : 'Cihazda pusula sensörü bulunamadı. Açı sabit konuma göre hesaplandı.',
          textAlign: TextAlign.center,
          style: GoogleFonts.notoSans(
            color: textColor,
            fontSize: 10.5,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  /// Kıble göstergesi: üstte Kâbe rozetiyle biten altın bir uç, altta koyu
  /// kısa bir kuyruk — klasik pusula ibnesi görünümü. Toplam yükseklik
  /// merkeze göre simetrik tutuluyor ki Transform.rotate tam kadran
  /// merkezinde dönsün.
  Widget _buildQiblaNeedle(bool isDark, double dialSize) {
    final length = dialSize * 0.74;
    final topLen = length * 0.56;
    final bottomLen = length * 0.30;
    final totalHeight = (topLen + bottomLen);
    final width = dialSize * 0.10;
    final darkTail = isDark ? Colors.white24 : const Color(0xFF2B2B2B);

    return SizedBox(
      width: width * 2.4,
      height: totalHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(width * 2.4, totalHeight),
            painter: _NeedlePainter(
              topLen: topLen,
              bottomLen: bottomLen,
              width: width,
              topColor: AppColors.gold,
              bottomColor: darkTail,
              pivotColor: isDark ? const Color(0xFF0B111F) : Colors.white,
            ),
          ),
          Positioned(
            top: totalHeight / 2 - topLen * 0.62,
            child: _buildKaabaBadge(dialSize),
          ),
        ],
      ),
    );
  }

  Widget _buildKaabaBadge(double dialSize) {
    final size = dialSize * 0.15;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.gold,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: EdgeInsets.all(size * 0.22),
      child: Image.asset(
        'assets/images/kaabe.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: BorderRadius.circular(2.5),
          ),
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Container(height: 2.6, color: AppColors.gold),
          ),
        ),
      ),
    );
  }

  /// Pusulanın altında yalnızca TEK bir anlık yönlendirme: hizalıysa onay,
  /// değilse fark işaretine göre yalnızca sağ YA DA sol ok — asla ikisi
  /// birden. `_isAligned` histerezis ile güncellendiği için sınırda
  /// (aligned/yön arasında) metin titremez.
  Widget _buildDirectionHint(bool isDark) {
    if (!_hasHeadingData || _qibla == null) return const SizedBox.shrink();

    final cardColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;

    if (_isAligned) {
      return _hintCard(
        isDark: isDark,
        cardColor: cardColor,
        icon: Icons.check_circle_rounded,
        accent: AppColors.success,
        caption: null,
        text: 'Kıble yönündesiniz',
      );
    }

    final heading = _smoothedHeading ?? _qibla!.bearing;
    final diff = _shortestDiff(_qibla!.bearing, heading);
    final turnRight = diff > 0;
    return _hintCard(
      isDark: isDark,
      cardColor: cardColor,
      icon: turnRight ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
      accent: AppColors.gold,
      caption: 'Kıble yönüne ilerlemek için',
      text: turnRight ? 'Sağa dönün' : 'Sola dönün',
    );
  }

  Widget _hintCard({
    required bool isDark,
    required Color cardColor,
    required IconData icon,
    required Color accent,
    required String? caption,
    required String text,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (caption != null)
            Text(
              caption,
              style: GoogleFonts.notoSans(
                color: isDark ? Colors.white54 : AppColors.textLight,
                fontSize: 11.5,
              ),
            ),
          if (caption != null) const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accent, size: 18),
              const SizedBox(width: 8),
              Text(
                text,
                style: GoogleFonts.notoSans(
                  color: accent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    final qibla = _qibla!;
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    final labelColor = isDark ? Colors.white54 : AppColors.textLight;
    final valueColor = isDark ? Colors.white : AppColors.textPrimary;
    final dividerColor =
        isDark ? Colors.white12 : AppColors.textLight.withValues(alpha: 0.25);
    final compassLabel = _turkishCompassLabel(qibla.bearing);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  Text('Kıble Yönü',
                      style:
                          GoogleFonts.notoSans(color: labelColor, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    compassLabel,
                    style: GoogleFonts.notoSans(
                      color: valueColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            VerticalDivider(color: dividerColor, thickness: 1, width: 1),
            Expanded(
              child: Column(
                children: [
                  Text('Kıble Açısı',
                      style:
                          GoogleFonts.notoSans(color: labelColor, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    '${qibla.bearing.toStringAsFixed(0)}°',
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('Saat yönünde',
                      style:
                          GoogleFonts.notoSans(color: labelColor, fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Kuzeyden saat yönünde 8 yönlü Türkçe pusula etiketi (ör. "Güneydoğu ↘").
  String _turkishCompassLabel(double bearingDeg) {
    const labels = [
      'Kuzey',
      'Kuzeydoğu',
      'Doğu',
      'Güneydoğu',
      'Güney',
      'Güneybatı',
      'Batı',
      'Kuzeybatı',
    ];
    const arrows = ['↑', '↗', '→', '↘', '↓', '↙', '←', '↖'];
    final normalized = bearingDeg % 360;
    final index = (((normalized + 22.5) ~/ 45) % 8);
    return '${labels[index]} ${arrows[index]}';
  }

  void _showInfoSheet(bool isDark) {
    final bg = isDark ? const Color(0xFF1A2035) : Colors.white;
    final textColor = isDark ? Colors.white70 : AppColors.textSecondary;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.explore_outlined, color: AppColors.gold),
                const SizedBox(width: 8),
                Text('Kıble Bulucu Hakkında',
                    style: GoogleFonts.playfairDisplay(
                        color: titleColor,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Kıble açısı, konumunuzdan Kâbe\'ye olan gerçek coğrafi yön '
              '(bearing) hesaplanarak bulunur. Pusula, telefonunuzun '
              'manyetik/gerçek yön sensörünü kullanır — bazı cihazlarda '
              'doğruluk düşebilir. Bu durumda telefonu havada 8 (∞) şeklinde '
              'yavaşça çevirmeniz, sensörün yeniden kalibre olmasına yardımcı '
              'olur.',
              style: GoogleFonts.notoSans(color: textColor, fontSize: 13.5, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  // ── Kalibrasyon overlay ──────────────────────────────────────────────────

  Widget _buildCalibrationOverlay(bool isDark) {
    final cardColor = isDark ? const Color(0xFF1E2438) : Colors.white;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;
    final bodyColor = isDark ? Colors.white70 : AppColors.textSecondary;

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              // Arka planı hafifçe karart — kıble ekranı arkada görünmeye
              // devam ediyor, sadece dikkat modalın üstüne çekiliyor.
              onTap: () {},
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Jiroskopu kalibre edin',
                          style: GoogleFonts.playfairDisplay(
                            color: titleColor,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _dismissCalibrationManually,
                        child: Icon(Icons.close,
                            color: bodyColor.withValues(alpha: 0.8), size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Daha doğru kıble yönü için cihazınızı 8 (∞) şeklinde '
                    'yavaşça hareket ettirin.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSans(
                        color: bodyColor, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  AnimatedBuilder(
                    animation: _infinityController,
                    builder: (context, _) => CustomPaint(
                      size: const Size(180, 96),
                      painter: _InfinityPainter(
                        t: _infinityController.value,
                        color: AppColors.gold,
                        trackColor: bodyColor.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 4,
                      child: LinearProgressIndicator(
                        // Kasıtlı olarak `value` verilmiyor: gerçek bir
                        // ilerleme yüzdesi elde edemiyoruz (platform bunu
                        // sunmuyor) — sahte bir yüzde göstermek yerine
                        // belirsiz (indeterminate) bir hareket kullanılıyor.
                        backgroundColor: bodyColor.withValues(alpha: 0.12),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.gold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Kalibrasyon tamamlanana kadar hareket ettirmeye devam edin.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSans(
                        color: bodyColor.withValues(alpha: 0.85),
                        fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kadranın kenarındaki ince tik işaretleri: her 30°'de kısa, ana yönlerde
/// (0/90/180/270) biraz daha uzun çizgiler.
class _CompassTicksPainter extends CustomPainter {
  final Color color;
  _CompassTicksPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 4;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;

    for (var deg = 0; deg < 360; deg += 15) {
      final isMajor = deg % 90 == 0;
      final tickLen = isMajor ? 10.0 : 5.0;
      final angle = deg * math.pi / 180;
      final outer = Offset(
        center.dx + outerRadius * math.sin(angle),
        center.dy - outerRadius * math.cos(angle),
      );
      final inner = Offset(
        center.dx + (outerRadius - tickLen) * math.sin(angle),
        center.dy - (outerRadius - tickLen) * math.cos(angle),
      );
      canvas.drawLine(inner, outer, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CompassTicksPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Klasik pusula ibnesi: üstte uzun/altın, altta kısa/koyu iki kite (baklava)
/// şekli, ortada küçük bir pivot dairesi.
class _NeedlePainter extends CustomPainter {
  final double topLen;
  final double bottomLen;
  final double width;
  final Color topColor;
  final Color bottomColor;
  final Color pivotColor;

  _NeedlePainter({
    required this.topLen,
    required this.bottomLen,
    required this.width,
    required this.topColor,
    required this.bottomColor,
    required this.pivotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final halfW = width / 2;

    final topPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx + halfW, center.dy - topLen * 0.4)
      ..lineTo(center.dx, center.dy - topLen)
      ..lineTo(center.dx - halfW, center.dy - topLen * 0.4)
      ..close();

    final bottomPath = Path()
      ..moveTo(center.dx, center.dy)
      ..lineTo(center.dx + halfW * 0.8, center.dy + bottomLen * 0.5)
      ..lineTo(center.dx, center.dy + bottomLen)
      ..lineTo(center.dx - halfW * 0.8, center.dy + bottomLen * 0.5)
      ..close();

    canvas.drawPath(topPath, Paint()..color = topColor);
    canvas.drawPath(bottomPath, Paint()..color = bottomColor);
    canvas.drawCircle(center, width * 0.22, Paint()..color = pivotColor);
    canvas.drawCircle(
      center,
      width * 0.22,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _NeedlePainter oldDelegate) => false;
}

/// Kalibrasyon overlay'indeki 8 (∞) hareketi animasyonu: telefonu andıran
/// küçük bir dikdörtgen, lemniscate (∞) eğrisi üzerinde dolaşır ve eğrinin
/// teğetine göre döner — kullanıcı metni okumadan hareketi anlayabilsin diye.
class _InfinityPainter extends CustomPainter {
  final double t; // 0..1, döngüsel
  final Color color;
  final Color trackColor;

  _InfinityPainter({required this.t, required this.color, required this.trackColor});

  Offset _pointAt(double theta, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final a = size.width / 2 - 18;
    final b = size.height / 2 - 14;
    final x = cx + a * math.cos(theta);
    final y = cy + b * math.sin(theta) * math.cos(theta);
    return Offset(x, y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    const steps = 120;
    for (var i = 0; i <= steps; i++) {
      final theta = (i / steps) * 2 * math.pi;
      final p = _pointAt(theta, size);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, trackPaint);

    // Hareketli "telefon" — eğrinin teğet açısına göre döndürülüyor.
    final theta = t * 2 * math.pi;
    final pos = _pointAt(theta, size);
    const dTheta = 0.01;
    final ahead = _pointAt(theta + dTheta, size);
    final tangent = math.atan2(ahead.dy - pos.dy, ahead.dx - pos.dx);

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(tangent + math.pi / 2);
    final rect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-6, -10, 12, 20),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(rect, Paint()..color = color);
    canvas.drawRRect(
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InfinityPainter oldDelegate) =>
      oldDelegate.t != t;
}
