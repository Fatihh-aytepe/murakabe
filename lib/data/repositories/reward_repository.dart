import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../models/reward_model.dart';

class RewardRepository {
  final DatabaseHelper _db = DatabaseHelper();

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
  }

  Future<List<RewardModel>> getAllRewards() async {
    final rows = await _db.query('rewards', orderBy: 'earnedAt DESC');
    return rows.map((r) => RewardModel.fromMap(r)).toList();
  }

  Future<List<RewardModel>> getRewardsByType(String type) async {
    final rows = await _db.query(
      'rewards',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'earnedAt DESC',
    );
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
}
