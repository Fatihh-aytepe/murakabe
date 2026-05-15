import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../local/local_storage.dart';
import '../models/badge_model.dart';
import '../remote/firebase_service.dart';

class BadgeRepository {
  static final BadgeRepository _instance = BadgeRepository._();
  factory BadgeRepository() => _instance;
  BadgeRepository._();

  final _db = DatabaseHelper();
  final _storage = LocalStorage();
  final _firebase = FirebaseService();

  Future<BadgeModel> saveBadge(String badgeId) async {
    final badge = BadgeModel(
      id: const Uuid().v4(),
      badgeId: badgeId,
      earnedAt: DateTime.now(),
    );
    await _db.insert('badges', badge.toMap());
    final uid = _storage.userId;
    if (uid != null) {
      try {
        await _firebase.saveBadgeRecord(uid, badge.toMap());
      } catch (_) {}
    }
    return badge;
  }

  Future<List<BadgeModel>> getAllBadges() async {
    final rows = await _db.query('badges', orderBy: 'earnedAt DESC');
    return rows.map((r) => BadgeModel.fromMap(r)).toList();
  }

  Future<bool> hasBadge(String badgeId) async {
    final rows = await _db.query(
      'badges',
      where: 'badgeId = ?',
      whereArgs: [badgeId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  // Teheccüd toplam gece sayısını rewards tablosundan hesaplar
  Future<int> getTahajjudTotalNights() async {
    final db = await _db.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM rewards WHERE type = 'tahajjud'",
    );
    return (result.first['cnt'] as int? ?? 0);
  }

  // Belirli ay içindeki teheccüd gece sayısı (format: "YYYY-MM")
  Future<int> getTahajjudNightsInMonth(String yearMonth) async {
    final db = await _db.database;
    final result = await db.rawQuery(
      "SELECT COUNT(*) as cnt FROM rewards WHERE type = 'tahajjud' AND earnedAt LIKE ?",
      ['$yearMonth%'],
    );
    return (result.first['cnt'] as int? ?? 0);
  }

  Future<void> setDisplayedBadge(String badgeId) async {
    final db = await _db.database;
    await db.execute("UPDATE badges SET isDisplayed = 0");
    await db.execute(
      "UPDATE badges SET isDisplayed = 1 WHERE badgeId = ?",
      [badgeId],
    );
    await _storage.setDisplayedBadgeId(badgeId);
  }

  Future<void> clearDisplayedBadge() async {
    final db = await _db.database;
    await db.execute("UPDATE badges SET isDisplayed = 0");
    await _storage.clearDisplayedBadgeId();
  }
}
