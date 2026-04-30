import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../local/local_storage.dart';
import '../models/user_model.dart';
import '../remote/firebase_service.dart';

class UserRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final LocalStorage _storage = LocalStorage();
  final FirebaseService _firebase = FirebaseService();

  Future<UserModel?> getCurrentUser() async {
    final userId = _storage.userId;
    if (userId == null) return null;

    final results =
        await _db.query('users', where: 'id = ?', whereArgs: [userId]);
    if (results.isEmpty) return null;

    final map = Map<String, dynamic>.from(results.first);
    map['missedQuranDays'] = jsonDecode(map['missedQuranDays'] ?? '[]');
    map['tahajjudAlarmTimes'] = jsonDecode(map['tahajjudAlarmTimes'] ?? '[]');
    return UserModel.fromMap(map);
  }

  Future<UserModel> createUser({
    required String nameSurname,
    required String phone,
    required String email,
  }) async {
    final user = UserModel(
      id: const Uuid().v4(),
      nameSurname: nameSurname,
      phone: phone,
      email: email,
      createdAt: DateTime.now(),
    );

    final map = user.toMap();
    map['missedQuranDays'] = jsonEncode(user.missedQuranDays);
    map['tahajjudAlarmTimes'] = jsonEncode(
        user.tahajjudAlarmTimes.map((e) => e.toIso8601String()).toList());

    await _db.insert('users', map);
    await _storage.setUserId(user.id);
    await _storage.setUserRegistered(true);

    try {
      await _firebase.saveUser(user);
    } catch (_) {}

    return user;
  }

  Future<void> updateUser(UserModel user) async {
    final map = user.toMap();
    map['missedQuranDays'] = jsonEncode(user.missedQuranDays);
    map['tahajjudAlarmTimes'] = jsonEncode(
        user.tahajjudAlarmTimes.map((e) => e.toIso8601String()).toList());

    await _db.update('users', map, where: 'id = ?', whereArgs: [user.id]);

    try {
      await _firebase.saveUser(user);
    } catch (_) {}
  }

  Future<void> markQuranRead(String date) async {
    await _db.insert('quran_tracking', {
      'date': date,
      'isRead': 1,
      'readAt': DateTime.now().toIso8601String(),
    });

    final user = await getCurrentUser();
    if (user != null) {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final newStreak =
          user.lastStreakDate == _yesterday() ? user.streakDays + 1 : 1;

      await updateUser(user.copyWith(
        quranReadDays: user.quranReadDays + 1,
        streakDays: newStreak,
        lastStreakDate: today,
        mercyDaysUsed: 0,
      ));
    }

    try {
      await _firebase.markQuranRead(_storage.userId!, date);
    } catch (_) {}
  }

  String _yesterday() {
    return DateTime.now()
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
  }

  Future<bool> isQuranReadToday() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final results = await _db.query(
      'quran_tracking',
      where: 'date = ? AND isRead = 1',
      whereArgs: [today],
    );
    return results.isNotEmpty;
  }

  Future<List<String>> getMissedDays() async {
    final user = await getCurrentUser();
    return user?.missedQuranDays ?? [];
  }
}
