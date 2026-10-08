import 'dart:convert';
import 'package:flutter/services.dart';
import '../local/local_storage.dart';
import '../models/zikir_model.dart';

/// O anda ekranda/bildirimde gösterilecek aktif zikri temsil eder.
class ActiveZikir {
  final bool isCustom;
  final String turkish;
  final String arabic; // boş olabilir (opsiyonel)
  final String meaning; // sadece varsayılan zikirlerde dolu olur
  final int target;

  ActiveZikir({
    required this.isCustom,
    required this.turkish,
    required this.arabic,
    required this.meaning,
    required this.target,
  });
}

class ZikirRepository {
  final LocalStorage _storage = LocalStorage();
  List<ZikirModel>? _cache;

  // ── Havuz yükleme ──────────────────────────────────────────────────────
  Future<List<ZikirModel>> getZikirler() async {
    if (_cache != null) return _cache!;
    final json = await rootBundle.loadString('assets/data/zikirler.json');
    final list = jsonDecode(json) as List;
    _cache = list.map((e) => ZikirModel.fromMap(e)).toList();
    return _cache!;
  }

  // ContentRepository ile BİREBİR aynı formül — tutarlılık için kasıtlı.
  int _dayOfYear(DateTime date) =>
      date.difference(DateTime(date.year, 1, 1)).inDays;

  String _todayStr() => DateTime.now().toIso8601String().substring(0, 10);

  /// Süreli özel zikir (7/30/90 gün) aktif mi? Bu modda hedef, sürenin
  /// TAMAMI için toplam hedeftir: sayaç günler boyunca birikir, gece
  /// sıfırlanmaz. Süresiz özel zikir ve varsayılan zikirler günlük
  /// sıfırlanmaya devam eder.
  /// NOT: android/.../ZikirWidgetProvider.kt aynı kuralı uygular — anahtar
  /// isimleri değişirse orayı da güncelle.
  bool get isTimedCustomActive {
    if (_storage.zikirMode != 'custom') return false;
    final endDate = _storage.customZikirEndDate;
    return endDate != null &&
        endDate.isNotEmpty &&
        _todayStr().compareTo(endDate) <= 0;
  }

  Future<void> _checkCustomExpiry() async {
    if (_storage.zikirMode != 'custom') return;
    final endDate = _storage.customZikirEndDate;
    if (endDate == null || endDate.isEmpty) return;
    if (_todayStr().compareTo(endDate) > 0) {
      // Süre doldu: varsayılan (günlük) zikirlere dönülür ve birikmiş
      // toplam sayaç sıfırlanır.
      await _storage.setZikirMode('default');
      await _storage.clearCustomZikirEndDate();
      await resetCount();
      await _storage.setZikirProgressDate(_todayStr());
    }
  }

  Future<void> _checkProgressRollover() async {
    final today = _todayStr();
    if (_storage.zikirProgressDate == today) return;
    // Süreli özel zikirde sayaç gece SIFIRLANMAZ (toplam hedef) — yalnızca
    // tarih güncellenir ki widget tarafı da sıfırlamaya kalkmasın.
    if (!isTimedCustomActive) {
      await _storage.setZikirCurrentCount(0);
      await _storage.setZikirCelebrationShown(false);
    }
    await _storage.setZikirProgressDate(today);
  }

  Future<ActiveZikir> getActiveZikir() async {
    await _checkCustomExpiry();
    await _checkProgressRollover();
    return getZikirForDate(DateTime.now());
  }

  int get currentCount => _storage.zikirCurrentCount;

  Future<bool> increment() async {
    await _checkCustomExpiry();
    await _checkProgressRollover();
    final active = await getZikirForDate(DateTime.now());
    final newCount = _storage.zikirCurrentCount + 1;
    await _storage.setZikirCurrentCount(newCount);

    if (newCount >= active.target && !_storage.zikirCelebrationShown) {
      await _storage.setZikirCelebrationShown(true);
      return true;
    }
    return false;
  }

  Future<void> resetCount() async {
    await _storage.setZikirCurrentCount(0);
    await _storage.setZikirCelebrationShown(false);
  }

  Future<void> setCustomZikir({
    required String turkish,
    String arabic = '',
    required int target,
    int? durationDays,
  }) async {
    await _storage.setCustomZikirTurkish(turkish);
    await _storage.setCustomZikirArabic(arabic);
    await _storage.setCustomZikirTarget(target);

    if (durationDays != null) {
      // Bugün dahil [durationDays] gün: "7 gün" = bugün + 6 gün sonrası.
      // (Önceden bugün + 7 alınıyordu, süre fiilen 8 gün sürüyordu.)
      final end = DateTime.now().add(Duration(days: durationDays - 1));
      await _storage
          .setCustomZikirEndDate(end.toIso8601String().substring(0, 10));
    } else {
      await _storage.clearCustomZikirEndDate();
    }

    await _storage.setZikirMode('custom');
    await resetCount();
    await _storage.setZikirProgressDate(_todayStr());
  }

  Future<void> clearCustomZikir() async {
    await _storage.setZikirMode('default');
    await _storage.clearCustomZikirEndDate();
    await resetCount();
    await _storage.setZikirProgressDate(_todayStr());
  }

  Future<void> setDefaultTarget(int target) =>
      _storage.setZikirDefaultTarget(target);

  bool get isCustomActive => _storage.zikirMode == 'custom';

  Future<ActiveZikir> getZikirForDate(DateTime date) async {
    if (_storage.zikirMode == 'custom') {
      final endDate = _storage.customZikirEndDate;
      final dateStr = date.toIso8601String().substring(0, 10);
      final stillActive =
          endDate == null || endDate.isEmpty || dateStr.compareTo(endDate) <= 0;
      if (stillActive) {
        return ActiveZikir(
          isCustom: true,
          turkish: _storage.customZikirTurkish ?? '',
          arabic: _storage.customZikirArabic ?? '',
          meaning: '',
          target: _storage.customZikirTarget,
        );
      }
    }

    final zikirler = await getZikirler();
    if (zikirler.isEmpty) {
      return ActiveZikir(
        isCustom: false,
        turkish: 'Sübhanallah',
        arabic: '',
        meaning: '',
        target: _storage.zikirDefaultTarget,
      );
    }
    final index = _dayOfYear(date) % zikirler.length;
    final z = zikirler[index];
    return ActiveZikir(
      isCustom: false,
      turkish: z.turkish,
      arabic: z.arabic,
      meaning: z.meaning,
      target: _storage.zikirDefaultTarget,
    );
  }
}
