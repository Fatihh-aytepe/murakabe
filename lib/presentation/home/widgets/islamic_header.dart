import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/usecases/get_prayer_times.dart';

class IslamicHeader extends StatefulWidget {
  final VoidCallback? onMenuTap;
  final UserModel? user;

  const IslamicHeader({super.key, this.onMenuTap, this.user});

  @override
  State<IslamicHeader> createState() => _IslamicHeaderState();
}

class _IslamicHeaderState extends State<IslamicHeader> {
  final _getPrayerTimes = GetPrayerTimes();
  PrayerTimesResult? _result;
  String _nextPrayerName = '';
  Duration _timeToNext = Duration.zero;
  late Stream<DateTime> _clockStream;
  List<Map<String, dynamic>> _prayers = [];
  final ScrollController _prayerScrollCtrl = ScrollController();

  @override
  void dispose() {
    _prayerScrollCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _clockStream = Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now())
        .asBroadcastStream();
    _loadPrayerTimes();
  }

  Future<void> _loadPrayerTimes() async {
    try {
      final result = await _getPrayerTimes();
      if (result != null && mounted) {
        setState(() {
          _result = result;
          _buildPrayerList(result.prayerTimes);
          _updateNextPrayer(result.prayerTimes);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_prayerScrollCtrl.hasClients) return;
          final nextIdx =
              _prayers.indexWhere((p) => p['name'] == _nextPrayerName);
          if (nextIdx > 0) {
            final target = ((nextIdx - 1) * 62.0).clamp(
                0.0, _prayerScrollCtrl.position.maxScrollExtent);
            _prayerScrollCtrl.animateTo(target,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut);
          }
        });
      }
    } catch (_) {
      // Namaz vakitleri yüklenemezse sessizce geçilir, iskelet kalır
    }
  }

  void _buildPrayerList(PrayerTimes pt) {
    _prayers = [
      {'name': 'İmsak', 'time': pt.fajr},
      {'name': 'Güneş', 'time': pt.sunrise},
      {'name': 'Öğle', 'time': pt.dhuhr},
      {'name': 'İkindi', 'time': pt.asr},
      {'name': 'Akşam', 'time': pt.maghrib},
      {'name': 'Yatsı', 'time': pt.isha},
    ];
  }

  void _updateNextPrayer(PrayerTimes pt) {
    final now = DateTime.now();
    final ordered = [
      {'name': 'İmsak', 'time': pt.fajr},
      {'name': 'Öğle', 'time': pt.dhuhr},
      {'name': 'İkindi', 'time': pt.asr},
      {'name': 'Akşam', 'time': pt.maghrib},
      {'name': 'Yatsı', 'time': pt.isha},
    ];
    for (final p in ordered) {
      final t = p['time'] as DateTime;
      if (t.isAfter(now)) {
        _nextPrayerName = p['name'] as String;
        _timeToNext = t.difference(now);
        return;
      }
    }
    _nextPrayerName = 'İmsak';
    _timeToNext = pt.fajr.add(const Duration(days: 1)).difference(now);
  }

  String _fmt(DateTime dt) => DateFormat('HH:mm').format(dt);

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}s ${m}dk';
    return '${m}dk ${s}sn';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Hayırlı Sabahlar';
    if (hour < 17) return 'Hayırlı Günler';
    if (hour < 20) return 'Hayırlı Akşamlar';
    return 'Hayırlı Geceler';
  }

  String _formatDate() {
    final now = DateTime.now();
    const months = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık',
    ];
    const days = ['', 'Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return '${days[now.weekday]}, ${now.day} ${months[now.month]} ${now.year}';
  }

  String _firstName() {
    final name = widget.user?.nameSurname ?? '';
    if (name.isEmpty) return '';
    return name.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: menu + date + countdown ──
              Row(
                children: [
                  GestureDetector(
                    onTap: widget.onMenuTap,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.menu,
                          color: AppColors.gold, size: 20),
                    ),
                  ),
                  const Spacer(),
                  // Miladi tarih kutusu
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.25)),
                    ),
                    child: Text(
                      _formatDate(),
                      style: GoogleFonts.notoSans(
                        fontSize: 11,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // ── Greeting + name ──
              Text(
                _firstName().isEmpty ? _greeting() : '${_greeting()},',
                style: GoogleFonts.notoSans(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
              if (_firstName().isNotEmpty)
                Text(
                  _firstName(),
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 26,
                    color: AppColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              const SizedBox(height: 14),

              // ── Prayer times strip ──
              if (_result != null) _buildPrayerStrip() else _prayerSkeleton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _prayerSkeleton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child:
              CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _buildPrayerStrip() {
    return StreamBuilder<DateTime>(
      stream: _clockStream,
      builder: (_, __) {
        if (_result != null) _updateNextPrayer(_result!.prayerTimes);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Geri sayım — sağa dayalı, prayer cards'ın hemen üstünde
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.turquoise.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.turquoise.withValues(alpha: 0.3),
                    width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_nextPrayerName\'a ',
                    style: GoogleFonts.notoSans(
                        color: AppColors.turquoiseLight, fontSize: 11),
                  ),
                  Text(
                    _fmtDuration(_timeToNext),
                    style: GoogleFonts.notoSans(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // Kaydırmalı namaz vakitleri
            SizedBox(
              height: 58,
              child: ListView.builder(
                controller: _prayerScrollCtrl,
                scrollDirection: Axis.horizontal,
                itemCount: _prayers.length,
                itemBuilder: (_, i) {
                  final p = _prayers[i];
                  final time = p['time'] as DateTime;
                  final now = DateTime.now();
                  final isNext = p['name'] == _nextPrayerName;
                  final isPast = time.isBefore(now);
                  return _cell(
                    name: p['name'] as String,
                    time: _fmt(time),
                    isNext: isNext,
                    isPast: isPast,
                    onTap: () => _showDetailSheet(p['name'] as String, time),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cell({
    required String name,
    required String time,
    required bool isNext,
    required bool isPast,
    required VoidCallback onTap,
  }) {
    final nameColor = isNext
        ? AppColors.gold
        : isPast
            ? Colors.white24
            : Colors.white54;
    final timeColor = isNext
        ? AppColors.gold
        : isPast
            ? Colors.white24
            : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 56,
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
          color: isNext
              ? AppColors.gold.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isNext
                ? AppColors.gold.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.1),
            width: isNext ? 1 : 0.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.notoSans(
                color: nameColor,
                fontSize: 10,
                fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                time,
                style: GoogleFonts.notoSans(
                  color: timeColor,
                  fontSize: 12,
                  fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(String prayerName, DateTime today) {
    if (_result == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PrayerTimesDetailSheet(
        result: _result!,
        highlightPrayer: prayerName,
      ),
    );
  }
}

// ─── Aylık Namaz Vakitleri Detail Sheet ───────────────────────────────────────

class PrayerTimesDetailSheet extends StatelessWidget {
  final PrayerTimesResult result;
  final String highlightPrayer;

  const PrayerTimesDetailSheet({
    super.key,
    required this.result,
    required this.highlightPrayer,
  });

  String _fmt(DateTime dt) => DateFormat('HH:mm').format(dt);

  String _dayLabel(DateTime d) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    const months = [
      '',
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month]}';
  }

  List<Map<String, dynamic>> _buildMonthly() {
    final coords = Coordinates(result.latitude, result.longitude);
    final params = CalculationMethod.turkey.getParameters();
    final now = DateTime.now();
    return List.generate(31, (i) {
      final day = now.add(Duration(days: i));
      final date = DateComponents.from(day);
      final pt = PrayerTimes(coords, date, params);
      return {
        'date': day,
        'fajr': pt.fajr,
        'sunrise': pt.sunrise,
        'dhuhr': pt.dhuhr,
        'asr': pt.asr,
        'maghrib': pt.maghrib,
        'isha': pt.isha,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final monthly = _buildMonthly();
    final today = monthly.first;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Başlık
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Icon(Icons.access_time_filled,
                      color: AppColors.gold, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Namaz Vakitleri',
                    style: GoogleFonts.playfairDisplay(
                      color: AppColors.gold,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Bugün detayı
            _buildTodayCard(today),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  Text(
                    '30 GÜNLÜK TAHMİNİ',
                    style: GoogleFonts.notoSans(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),

            // Aylık liste
            Expanded(
              child: ListView.builder(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: monthly.length - 1,
                itemBuilder: (_, i) => _buildDayRow(monthly[i + 1], i + 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayCard(Map<String, dynamic> day) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C3050), Color(0xFF243B5E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bugün',
            style: GoogleFonts.playfairDisplay(
              color: AppColors.gold,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _todayCell('İmsak', day['fajr'] as DateTime),
              _todayCell('Güneş', day['sunrise'] as DateTime),
              _todayCell('Öğle', day['dhuhr'] as DateTime),
              _todayCell('İkindi', day['asr'] as DateTime),
              _todayCell('Akşam', day['maghrib'] as DateTime),
              _todayCell('Yatsı', day['isha'] as DateTime),
            ],
          ),
        ],
      ),
    );
  }

  Widget _todayCell(String name, DateTime time) {
    final isHighlighted = name == highlightPrayer;
    return Expanded(
      child: Column(
        children: [
          Text(
            name,
            style: GoogleFonts.notoSans(
              color: isHighlighted ? AppColors.gold : Colors.white54,
              fontSize: 10,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            decoration: isHighlighted
                ? BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.5)),
                  )
                : null,
            child: Text(
              _fmt(time),
              style: GoogleFonts.notoSans(
                color: isHighlighted ? AppColors.gold : Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(Map<String, dynamic> day, int offset) {
    final date = day['date'] as DateTime;
    final isToday = offset == 0;
    final isFriday = date.weekday == DateTime.friday;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isFriday
            ? AppColors.turquoise.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isToday
              ? AppColors.gold.withValues(alpha: 0.3)
              : isFriday
                  ? AppColors.turquoise.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              _dayLabel(date),
              style: GoogleFonts.notoSans(
                color: isFriday ? AppColors.turquoiseLight : Colors.white60,
                fontSize: 11,
                fontWeight: isFriday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _miniTime(_fmt(day['fajr'] as DateTime)),
                _miniTime(_fmt(day['dhuhr'] as DateTime)),
                _miniTime(_fmt(day['asr'] as DateTime)),
                _miniTime(_fmt(day['maghrib'] as DateTime)),
                _miniTime(_fmt(day['isha'] as DateTime)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniTime(String t) => Text(
        t,
        style: GoogleFonts.notoSans(color: Colors.white70, fontSize: 11),
      );
}
