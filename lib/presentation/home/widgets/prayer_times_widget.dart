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

  List<Map<String, dynamic>> _prayers = [];

  @override
  void initState() {
    super.initState();
    _clockStream = Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now())
        .asBroadcastStream();
    _loadPrayerTimes();
  }

  Future<void> _loadPrayerTimes() async {
    try {
      final result = await _getPrayerTimes()
          .timeout(const Duration(seconds: 15), onTimeout: () => null);
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
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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

  String _getHijriDate() {
    final now = DateTime.now();
    final h = _toHijri(now.year, now.month, now.day);
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
    return '${h[2]} ${months[h[1]]} ${h[0]}';
  }

  List<int> _toHijri(int gy, int gm, int gd) {
    int a = (14 - gm) ~/ 12;
    int y = gy + 4800 - a;
    int m = gm + 12 * a - 3;
    int jdn = gd +
        (153 * m + 2) ~/ 5 +
        365 * y +
        y ~/ 4 -
        y ~/ 100 +
        y ~/ 400 -
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
    if (_isLoading) return _skeleton();
    if (_result == null) return _error();
    return _card();
  }

  Widget _skeleton() => Container(
        height: 110,
        decoration: _cardDecoration(),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                color: AppColors.gold, strokeWidth: 2),
          ),
        ),
      );

  Widget _error() => Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Row(
          children: [
            const Icon(Icons.location_off, color: Colors.white38, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Namaz vakitleri yüklenemedi',
                  style: GoogleFonts.notoSans(
                      color: Colors.white54, fontSize: 12)),
            ),
            TextButton(
              onPressed: () {
                setState(() => _isLoading = true);
                _loadPrayerTimes();
              },
              style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero),
              child: Text('Dene',
                  style: GoogleFonts.notoSans(
                      color: AppColors.gold, fontSize: 12)),
            ),
          ],
        ),
      );

  Widget _card() {
    final pt = _result!.prayerTimes;
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _topRow(pt),
          const SizedBox(height: 2),
          _prayerRow(),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _topRow(PrayerTimes pt) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(
        children: [
          // Hicri tarih
          Flexible(
            child: Text(
              _getHijriDate(),
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.amiri(
                color: AppColors.gold.withValues(alpha: 0.9),
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Canlı geri sayım
          StreamBuilder<DateTime>(
            stream: _clockStream,
            builder: (_, snap) {
              // State mutation yok — her build'de local hesapla
              String nextName = _nextPrayerName;
              Duration timeLeft = _timeToNext;
              if (_result != null) {
                final now = snap.data ?? DateTime.now();
                final pt2 = _result!.prayerTimes;
                final ordered = [
                  {'name': 'İmsak', 'time': pt2.fajr},
                  {'name': 'Öğle', 'time': pt2.dhuhr},
                  {'name': 'İkindi', 'time': pt2.asr},
                  {'name': 'Akşam', 'time': pt2.maghrib},
                  {'name': 'Yatsı', 'time': pt2.isha},
                ];
                bool found = false;
                for (final p in ordered) {
                  final t = p['time'] as DateTime;
                  if (t.isAfter(now)) {
                    nextName = p['name'] as String;
                    timeLeft = t.difference(now);
                    found = true;
                    break;
                  }
                }
                if (!found) {
                  nextName = 'İmsak';
                  timeLeft =
                      pt2.fajr.add(const Duration(days: 1)).difference(now);
                }
              }
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                      '$nextName\'a ',
                      style: GoogleFonts.notoSans(
                          color: AppColors.turquoiseLight, fontSize: 11),
                    ),
                    Text(
                      _fmtDuration(timeLeft),
                      style: GoogleFonts.notoSans(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _prayerRow() {
    return SizedBox(
      height: 62,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
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
          );
        },
      ),
    );
  }

  Widget _cell({
    required String name,
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
            : Colors.white;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 56,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: isNext
            ? AppColors.gold.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isNext
              ? AppColors.gold.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.07),
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
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1C3050), Color(0xFF243B5E)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.08),
        width: 0.8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
