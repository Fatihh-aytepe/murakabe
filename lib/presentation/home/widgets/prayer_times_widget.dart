import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../domain/usecases/get_prayer_times.dart';

class PrayerTimesWidget extends StatefulWidget {
  const PrayerTimesWidget({super.key});

  @override
  State<PrayerTimesWidget> createState() => _PrayerTimesWidgetState();
}

class _PrayerTimesWidgetState extends State<PrayerTimesWidget> {
  final _getPrayerTimes = GetPrayerTimes();
  PrayerTimesResult? _result;
  bool _isLoading = true;
  String _nextPrayerName = '';
  Duration _timeToNext = Duration.zero;
  late Stream<DateTime> _clockStream;

  final List<Map<String, dynamic>> _prayers = [];

  @override
  void initState() {
    super.initState();
    _clockStream =
        Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now());
    _loadPrayerTimes();
  }

  Future<void> _loadPrayerTimes() async {
    final result = await _getPrayerTimes();
    if (result != null && mounted) {
      setState(() {
        _result = result;
        _isLoading = false;
        _buildPrayerList(result.prayerTimes);
        _updateNextPrayer(result.prayerTimes);
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _buildPrayerList(PrayerTimes pt) {
    _prayers.clear();
    _prayers.addAll([
      {'name': 'İmsak', 'time': pt.fajr, 'icon': '🌙'},
      {'name': 'Güneş', 'time': pt.sunrise, 'icon': '🌅'},
      {'name': 'Öğle', 'time': pt.dhuhr, 'icon': '☀️'},
      {'name': 'İkindi', 'time': pt.asr, 'icon': '🌤'},
      {'name': 'Akşam', 'time': pt.maghrib, 'icon': '🌆'},
      {'name': 'Yatsı', 'time': pt.isha, 'icon': '🌃'},
    ]);
  }

  void _updateNextPrayer(PrayerTimes pt) {
    final now = DateTime.now();
    final prayers = [
      {'name': 'İmsak', 'time': pt.fajr},
      {'name': 'Öğle', 'time': pt.dhuhr},
      {'name': 'İkindi', 'time': pt.asr},
      {'name': 'Akşam', 'time': pt.maghrib},
      {'name': 'Yatsı', 'time': pt.isha},
    ];

    for (final p in prayers) {
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

  String _formatTime(DateTime dt) => DateFormat('HH:mm').format(dt);

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}s ${m}dk';
    return '${m}dk ${s}sn';
  }

  String _getHijriDate() {
    final now = DateTime.now();
    final hijri = _gregorianToHijri(now.year, now.month, now.day);
    const months = [
      '',
      'Muharrem',
      'Safer',
      'Rebiülevvel',
      'Rebiülahir',
      'Cemaziyelevvel',
      'Cemaziyelahir',
      'Recep',
      'Şaban',
      'Ramazan',
      'Şevval',
      'Zilkade',
      'Zilhicce',
    ];
    return '${hijri[2]} ${months[hijri[1]]} ${hijri[0]}';
  }

  List<int> _gregorianToHijri(int gy, int gm, int gd) {
    int a = ((14 - gm) ~/ 12);
    int y = gy + 4800 - a;
    int m = gm + 12 * a - 3;
    int jdn = gd +
        ((153 * m + 2) ~/ 5) +
        365 * y +
        (y ~/ 4) -
        (y ~/ 100) +
        (y ~/ 400) -
        32045;
    int l = jdn - 1948440 + 10632;
    int n = (l - 1) ~/ 10631;
    l = l - 10631 * n + 354;
    int j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
        (l ~/ 5670) * ((43 * l) ~/ 15238);
    l = l -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    int hm = (24 * l) ~/ 709;
    int hd = l - (709 * hm) ~/ 24;
    int hy = 30 * n + j - 30;
    return [hy, hm, hd];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildSkeleton();
    if (_result == null) return _buildError();
    return _buildStrip();
  }

  // ── Yüklenirken iskelet ───────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Container(
      height: 72,
      decoration: _stripDecoration(),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child:
              CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
        ),
      ),
    );
  }

  // ── Hata durumu ───────────────────────────────────────────────────────────
  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: _stripDecoration(),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Colors.white38, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Namaz vakitleri yüklenemedi',
              style: GoogleFonts.notoSans(color: Colors.white54, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() => _isLoading = true);
              _loadPrayerTimes();
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
            ),
            child: Text('Dene',
                style:
                    GoogleFonts.notoSans(color: AppColors.gold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── Ana şerit ─────────────────────────────────────────────────────────────
  Widget _buildStrip() {
    final pt = _result!.prayerTimes;

    return Container(
      decoration: _stripDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Üst satır: tarih + geri sayım ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                // Hicri tarih
                Text(
                  _getHijriDate(),
                  style: GoogleFonts.amiri(
                    color: AppColors.gold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                // Canlı geri sayım
                StreamBuilder<DateTime>(
                  stream: _clockStream,
                  builder: (_, __) {
                    if (_result != null) _updateNextPrayer(pt);
                    return Row(
                      children: [
                        Text(
                          '$_nextPrayerName\'a ',
                          style: GoogleFonts.notoSans(
                            color: AppColors.turquoiseLight,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _formatDuration(_timeToNext),
                          style: GoogleFonts.notoSans(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // ── Alt satır: yatay namaz vakitleri ──
          SizedBox(
            height: 58,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              itemCount: _prayers.length,
              itemBuilder: (_, i) {
                final p = _prayers[i];
                final time = p['time'] as DateTime;
                final now = DateTime.now();
                final isNext = p['name'] == _nextPrayerName;
                final isPast = time.isBefore(now);

                return _buildPrayerCell(
                  name: p['name'] as String,
                  icon: p['icon'] as String,
                  time: _formatTime(time),
                  isNext: isNext,
                  isPast: isPast,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerCell({
    required String name,
    required String icon,
    required String time,
    required bool isNext,
    required bool isPast,
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
            : Colors.white70;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isNext
            ? AppColors.gold.withOpacity(0.18)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNext
              ? AppColors.gold.withOpacity(0.6)
              : Colors.white.withOpacity(0.06),
          width: isNext ? 1 : 0.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: TextStyle(fontSize: isPast ? 12 : 14)),
          const SizedBox(height: 2),
          Text(
            name,
            style: GoogleFonts.notoSans(
              color: nameColor,
              fontSize: 10,
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            time,
            style: GoogleFonts.notoSans(
              color: timeColor,
              fontSize: 11,
              fontWeight: isNext ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _stripDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: AppColors.gold.withOpacity(0.12),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
