import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../local/database_helper.dart';
import '../local/local_storage.dart';
import '../models/esma_model.dart';
import '../models/hadis_model.dart';
import '../models/ayet_model.dart';

class ContentRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final LocalStorage _storage = LocalStorage();

  List<EsmaModel>? _esmaCache;
  List<HadisModel>? _hadisCache;
  List<AyetModel>? _ayetCache;

  // İçerik yükleme
  Future<List<EsmaModel>> getEsmas() async {
    if (_esmaCache != null) return _esmaCache!;
    final json = await rootBundle.loadString('assets/data/esmaul_husna.json');
    final list = jsonDecode(json) as List;
    _esmaCache = list.map((e) => EsmaModel.fromMap(e)).toList();
    return _esmaCache!;
  }

  Future<List<HadisModel>> getHadises() async {
    if (_hadisCache != null) return _hadisCache!;
    final json = await rootBundle.loadString('assets/data/hadisler.json');
    final list = jsonDecode(json) as List;
    _hadisCache = list.map((e) => HadisModel.fromMap(e)).toList();
    return _hadisCache!;
  }

  Future<List<AyetModel>> getAyets() async {
    if (_ayetCache != null) return _ayetCache!;
    final json = await rootBundle.loadString('assets/data/ayetler.json');
    final list = jsonDecode(json) as List;
    _ayetCache = list.map((e) => AyetModel.fromMap(e)).toList();
    return _ayetCache!;
  }

  // Günün içeriğini al ve indeksi ilerlet
  Future<EsmaModel> getTodayEsma() async {
    final esmas = await getEsmas();
    _checkAndAdvanceIndex();
    final index = _storage.todayEsmaIndex % esmas.length;
    return esmas[index];
  }

  Future<HadisModel> getTodayHadis() async {
    final hadises = await getHadises();
    final index = _storage.todayHadisIndex % hadises.length;
    return hadises[index];
  }

  Future<AyetModel> getTodayAyet() async {
    final ayets = await getAyets();
    final index = _storage.todayAyetIndex % ayets.length;
    return ayets[index];
  }

  void _checkAndAdvanceIndex() {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_storage.lastUpdateDate != today) {
      _storage.setEsmaIndex(_storage.todayEsmaIndex + 1);
      _storage.setHadisIndex(_storage.todayHadisIndex + 1);
      _storage.setAyetIndex(_storage.todayAyetIndex + 1);
      _storage.setLastUpdateDate(today);
    }
  }

  // Random içerik (detail sayfaları için)
  Future<EsmaModel> getRandomEsma() async {
    final esmas = await getEsmas();
    return esmas[Random().nextInt(esmas.length)];
  }

  Future<AyetModel> getRandomAyet() async {
    final ayets = await getAyets();
    return ayets[Random().nextInt(ayets.length)];
  }

  Future<HadisModel> getRandomHadis() async {
    final hadises = await getHadises();
    return hadises[Random().nextInt(hadises.length)];
  }

  // Kaydetme işlemleri
  Future<void> saveContent(String type, int contentId) async {
    await _db.insert('saved_content', {
      'id': '${type}_$contentId',
      'type': type,
      'contentId': contentId,
      'savedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> unsaveContent(String type, int contentId) async {
    await _db.delete(
      'saved_content',
      where: 'type = ? AND contentId = ?',
      whereArgs: [type, contentId],
    );
  }

  Future<bool> isSaved(String type, int contentId) async {
    final r = await _db.query(
      'saved_content',
      where: 'type = ? AND contentId = ?',
      whereArgs: [type, contentId],
    );
    return r.isNotEmpty;
  }

  Future<List<EsmaModel>> getSavedEsmas() async {
    final rows = await _db.query('saved_content',
        where: 'type = ?', whereArgs: ['esma'], orderBy: 'savedAt DESC');
    final esmas = await getEsmas();
    return rows
        .map((r) => esmas.firstWhere(
              (e) => e.id == r['contentId'],
              orElse: () => esmas.first,
            ))
        .toList();
  }

  Future<List<HadisModel>> getSavedHadises() async {
    final rows = await _db.query('saved_content',
        where: 'type = ?', whereArgs: ['hadis'], orderBy: 'savedAt DESC');
    final hadises = await getHadises();
    return rows
        .map((r) => hadises.firstWhere(
              (h) => h.id == r['contentId'],
              orElse: () => hadises.first,
            ))
        .toList();
  }

  Future<List<AyetModel>> getSavedAyets() async {
    final rows = await _db.query('saved_content',
        where: 'type = ?', whereArgs: ['ayet'], orderBy: 'savedAt DESC');
    final ayets = await getAyets();
    return rows
        .map((r) => ayets.firstWhere(
              (a) => a.id == r['contentId'],
              orElse: () => ayets.first,
            ))
        .toList();
  }
}
