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

  // Gregorian → Hicri takvim çevirisi (Julian Day tabanlı)
  List<int> _gregorianToHijri(int gy, int gm, int gd) {
    // Julian Day Number hesapla
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

    // JDN → Hicri
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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              ),
            )
          : _result == null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_off, color: Colors.white38, size: 32),
          const SizedBox(height: 8),
          Text(
            'Namaz vakitleri yüklenemedi\nKonum iznini kontrol edin',
            style: GoogleFonts.notoSans(color: Colors.white54, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              setState(() => _isLoading = true);
              _loadPrayerTimes();
            },
            icon: const Icon(Icons.refresh, color: AppColors.gold, size: 18),
            label: Text(
              'Tekrar Dene',
              style: GoogleFonts.notoSans(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final pt = _result!.prayerTimes;
    return Column(
      children: [
        // Üst: Tarih + Geri sayım
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd MMMM yyyy', 'tr').format(DateTime.now()),
                    style: GoogleFonts.notoSans(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    _getHijriDate(),
                    style: GoogleFonts.amiri(
                      color: AppColors.gold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              // Geri sayım
              StreamBuilder<DateTime>(
                stream: _clockStream,
                builder: (_, snap) {
                  if (_result != null) {
                    _updateNextPrayer(pt);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _nextPrayerName,
                        style: GoogleFonts.notoSans(
                          color: AppColors.turquoiseLight,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        _formatDuration(_timeToNext),
                        style: GoogleFonts.playfairDisplay(
                          color: Colors.white,
                          fontSize: 16,
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

        const Divider(color: Colors.white12, height: 1),

        // Namaz vakitleri listesi
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: _prayers.map((p) {
              final time = p['time'] as DateTime;
              final now = DateTime.now();
              final isNext = p['name'] == _nextPrayerName;
              final isPast = time.isBefore(now);

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isNext
                      ? AppColors.gold.withOpacity(0.2)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isNext
                      ? Border.all(color: AppColors.gold.withOpacity(0.5))
                      : null,
                ),
                child: Row(
                  children: [
                    Text(p['icon'] as String,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 10),
                    Text(
                      p['name'] as String,
                      style: GoogleFonts.notoSans(
                        color: isNext
                            ? AppColors.gold
                            : isPast
                                ? Colors.white38
                                : Colors.white70,
                        fontSize: 13,
                        fontWeight:
                            isNext ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(time),
                      style: GoogleFonts.playfairDisplay(
                        color: isNext
                            ? AppColors.gold
                            : isPast
                                ? Colors.white38
                                : Colors.white,
                        fontSize: 14,
                        fontWeight:
                            isNext ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isNext)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.arrow_forward_ios,
                            color: AppColors.gold, size: 12),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
