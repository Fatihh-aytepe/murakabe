import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../local/local_storage.dart';
import '../models/reward_model.dart';
import '../remote/firebase_service.dart';

class RewardRepository {
  final _db = DatabaseHelper();
  final _firebase = FirebaseService();
  final _storage = LocalStorage();

  String? get _uid => _storage.userId;

  Future<void> saveReward({
    required String type,
    required String title,
    required String message,
  }) async {
    final reward = RewardModel(
      id: const Uuid().v4(),
      type: type,
      title: title,
      message: message,
      earnedAt: DateTime.now(),
    );
    await _db.insert('rewards', reward.toMap());
    if (_uid != null) {
      try {
        await _firebase.saveReward(_uid!, reward.toMap());
      } catch (_) {}
    }
  }

  Future<List<RewardModel>> getAllRewards() async {
    final rows = await _db.query('rewards', orderBy: 'earnedAt DESC');
    return rows.map((r) => RewardModel.fromMap(r)).toList();
  }

  Future<bool> hasRewardForDate(String type, String date) async {
    final rows = await _db.query(
      'rewards',
      where: 'type = ? AND earnedAt LIKE ?',
      whereArgs: [type, '$date%'],
    );
    return rows.isNotEmpty;
  }

  Future<void> deleteReward(String id) async {
    await _db.delete('rewards', where: 'id = ?', whereArgs: [id]);
  }

  // ── Teheccüd takibi ───────────────────────────────────────────────────────
  // `tahajjud_tracking` tablosu önceden hiç kullanılmıyordu: ödül, kullanıcı
  // onayı olmadan yalnızca "alarm açıktı + saat 02:00-08:00 arası" koşuluyla
  // veriliyordu (bkz. RewardService.shouldPromptTahajjud). Artık asıl onay
  // bu tabloya yazılıyor — hem "bugün zaten soruldu mu" kontrolü hem de
  // Firestore'a (markTahajjudPrayed) yansıtma burada yapılıyor.

  Future<bool> tahajjudAskedToday(String date) async {
    final rows = await _db.query(
      'tahajjud_tracking',
      where: 'date = ?',
      whereArgs: [date],
    );
    return rows.isNotEmpty;
  }

  /// Kullanıcı "teheccüde kalktın mı?" sorusuna cevap verdiğinde çağrılır.
  /// Cevap ne olursa olsun (evet/hayır) o gün için bir daha sorulmaması
  /// adına kaydedilir; yalnızca [prayed]=true ise Firestore'a da yazılır.
  Future<void> recordTahajjudAnswer(String date, {required bool prayed}) async {
    await _db.insert('tahajjud_tracking', {
      'date': date,
      'isPrayed': prayed ? 1 : 0,
      'prayedAt': DateTime.now().toIso8601String(),
    });
    if (prayed && _uid != null) {
      try {
        await _firebase.markTahajjudPrayed(_uid!, date);
      } catch (_) {}
    }
  }
}
