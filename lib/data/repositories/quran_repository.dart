import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../data/local/local_storage.dart';

// ─── Modeller ─────────────────────────────────────────────────────────────────

class QuranAyah {
  final int number; // sure içi ayet no
  final int globalNumber; // 1-6236
  final String arabic;
  final String turkish;
  final int page;
  final int surahNumber;
  final String surahName;

  const QuranAyah({
    required this.number,
    required this.globalNumber,
    required this.arabic,
    required this.turkish,
    required this.page,
    required this.surahNumber,
    required this.surahName,
  });
}

class QuranSurah {
  final int number;
  final String nameArabic;
  final String nameTurkish;
  final String nameTransliteration;
  final int ayahCount;
  final String revelationType; // Mekki / Medeni

  const QuranSurah({
    required this.number,
    required this.nameArabic,
    required this.nameTurkish,
    required this.nameTransliteration,
    required this.ayahCount,
    required this.revelationType,
  });
}

class QuranProgress {
  final int lastPage;
  final int lastSurah;
  final int lastAyah;
  final DateTime updatedAt;

  const QuranProgress({
    required this.lastPage,
    required this.lastSurah,
    required this.lastAyah,
    required this.updatedAt,
  });

  factory QuranProgress.initial() => QuranProgress(
        lastPage: 1,
        lastSurah: 1,
        lastAyah: 1,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'lastPage': lastPage,
        'lastSurah': lastSurah,
        'lastAyah': lastAyah,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory QuranProgress.fromMap(Map<String, dynamic> m) => QuranProgress(
        lastPage: m['lastPage'] ?? 1,
        lastSurah: m['lastSurah'] ?? 1,
        lastAyah: m['lastAyah'] ?? 1,
        updatedAt: DateTime.tryParse(m['updatedAt'] ?? '') ?? DateTime.now(),
      );
}

// ─── Kariler ──────────────────────────────────────────────────────────────────

class Qari {
  final String id;
  final String name;
  final String identifier; // EveryAyah CDN klasör adı

  const Qari({required this.id, required this.name, required this.identifier});
}

const List<Qari> kQariler = [
  Qari(id: 'sudais', name: 'Abdurrahman es-Sudais', identifier: '05'),
  Qari(id: 'ghamdi', name: 'Said el-Ghamdi', identifier: '10'),
  Qari(id: 'husary', name: 'Mahmud Halil el-Husary', identifier: '04'),
];

// ─── Repository ───────────────────────────────────────────────────────────────

class QuranRepository {
  static final QuranRepository _instance = QuranRepository._();
  factory QuranRepository() => _instance;
  QuranRepository._();

  static const String _baseUrl = 'https://api.quran.com/api/v4';
  // Türkçe meal: Diyanet (translation_id=77)
  static const int _turkishTranslationId = 77;

  final _storage = LocalStorage();
  final _firestore = FirebaseFirestore.instance;

  // ── Sure listesi ────────────────────────────────────────────────────────────

  Future<List<QuranSurah>> getSurahs() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/chapters?language=tr'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final chapters = data['chapters'] as List;

      return chapters.map((c) {
        return QuranSurah(
          number: c['id'],
          nameArabic: c['name_arabic'] ?? '',
          nameTurkish: c['translated_name']?['name'] ?? '',
          nameTransliteration: c['name_simple'] ?? '',
          ayahCount: c['verses_count'] ?? 0,
          revelationType:
              c['revelation_place'] == 'makkah' ? 'Mekki' : 'Medeni',
        );
      }).toList();
    } catch (e) {
      debugPrint('QuranRepository.getSurahs: $e');
      return [];
    }
  }

  // ── Sayfa bazlı ayet yükleme ────────────────────────────────────────────────

  Future<List<QuranAyah>> getAyahsByPage(int page) async {
    try {
      final res = await http.get(
        Uri.parse(
          '$_baseUrl/verses/by_page/$page'
          '?translations=$_turkishTranslationId'
          '&fields=text_uthmani,page_number,verse_key'
          '&per_page=50',
        ),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];
      return _parseVerses(jsonDecode(res.body)['verses'] as List);
    } catch (e) {
      debugPrint('QuranRepository.getAyahsByPage: $e');
      return [];
    }
  }

  // ── Sure bazlı ayet yükleme ─────────────────────────────────────────────────

  Future<List<QuranAyah>> getAyahsBySurah(int surahNumber) async {
    try {
      final res = await http.get(
        Uri.parse(
          '$_baseUrl/verses/by_chapter/$surahNumber'
          '?translations=$_turkishTranslationId'
          '&fields=text_uthmani,page_number,verse_key'
          '&per_page=300',
        ),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return [];
      return _parseVerses(jsonDecode(res.body)['verses'] as List);
    } catch (e) {
      debugPrint('QuranRepository.getAyahsBySurah: $e');
      return [];
    }
  }

  List<QuranAyah> _parseVerses(List verses) {
    return verses.map((v) {
      final key = v['verse_key'] as String; // örn: "2:255"
      final parts = key.split(':');
      final surahNo = int.tryParse(parts[0]) ?? 1;
      final ayahNo = int.tryParse(parts[1]) ?? 1;
      final translation = (v['translations'] as List?)?.firstOrNull;

      return QuranAyah(
        number: ayahNo,
        globalNumber: v['id'] ?? 0,
        arabic: v['text_uthmani'] ?? '',
        turkish: translation?['text'] ?? '',
        page: v['page_number'] ?? 1,
        surahNumber: surahNo,
        surahName: '',
      );
    }).toList();
  }

  // ── Ses URL ─────────────────────────────────────────────────────────────────
  // EveryAyah CDN: https://everyayah.com/data/{identifier}/{padded_global_number}.mp3
  String getAudioUrl(int globalAyahNumber, Qari qari) {
    final padded = globalAyahNumber.toString().padLeft(6, '0');
    return 'https://everyayah.com/data/${qari.identifier}/$padded.mp3';
  }

  // ── İlerleme kaydet ─────────────────────────────────────────────────────────

  Future<void> saveProgress({
    required int page,
    required int surah,
    required int ayah,
  }) async {
    final uid = _storage.userId;
    if (uid == null) return;

    final progress = QuranProgress(
      lastPage: page,
      lastSurah: surah,
      lastAyah: ayah,
      updatedAt: DateTime.now(),
    );

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('quranProgress')
          .doc('current')
          .set(progress.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('QuranRepository.saveProgress: $e');
    }
  }

  // ── İlerleme yükle ──────────────────────────────────────────────────────────

  Future<QuranProgress> loadProgress() async {
    final uid = _storage.userId;
    if (uid == null) return QuranProgress.initial();

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .collection('quranProgress')
          .doc('current')
          .get();

      if (doc.exists && doc.data() != null) {
        return QuranProgress.fromMap(doc.data()!);
      }
    } catch (e) {
      debugPrint('QuranRepository.loadProgress: $e');
    }
    return QuranProgress.initial();
  }
}
