import 'dart:convert';
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

  /// Firebase Auth ile kullanıcı oluşturur; UID'yi Firestore + SQLite'a yazar.
  /// [password] yalnızca Auth kaydı için kullanılır, SQLite'a yazılmaz.
  Future<UserModel> createUser({
    required String nameSurname,
    required String phone,
    required String email,
    required String password,
  }) async {
    // 1. Firebase Auth kaydı + doğrulama maili
    final authUser = await _firebase.registerWithEmail(
      email: email,
      password: password,
    );

    // Auth UID'sini kullan — UUID yerine
    final user = UserModel(
      id: authUser.uid,
      nameSurname: nameSurname,
      phone: phone,
      email: email,
      createdAt: DateTime.now(),
      isEmailVerified: false,
    );

    final map = user.toMap();
    map['missedQuranDays'] = jsonEncode(user.missedQuranDays);
    map['tahajjudAlarmTimes'] = jsonEncode(
        user.tahajjudAlarmTimes.map((e) => e.toIso8601String()).toList());

    // 2. SQLite'a yaz
    await _db.insert('users', map);
    await _storage.setUserId(user.id);
    await _storage.setUserRegistered(true);

    // 3. Firestore'a yaz (hata olursa sessizce geç — offline senaryosu)
    try {
      await _firebase.saveUser(user);
    } catch (_) {}

    return user;
  }

  /// Uygulama yeniden yüklendiğinde Firestore'dan SQLite'a kullanıcıyı geri yükler.
  /// Ana kullanıcı dokümanının yanı sıra tüm subcollection'lar da geri yüklenir.
  Future<bool> restoreFromFirestore(String uid) async {
    try {
      final map = await _firebase.getUserForSQLite(uid);
      if (map == null) return false;
      final existing =
          await _db.query('users', where: 'id = ?', whereArgs: [uid]);
      if (existing.isNotEmpty) {
        await _db.update('users', map, where: 'id = ?', whereArgs: [uid]);
      } else {
        await _db.insert('users', map);
      }
      await _restoreSubcollections(uid);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _restoreSubcollections(String uid) async {
    // Notlar
    final notes = await _firebase.getSubcollection(uid, 'notes');
    for (final n in notes) {
      try {
        await _db.insert('notes', n..remove('_docId'));
      } catch (_) {}
    }

    // Kaydedilenler (heybe)
    final saved = await _firebase.getSubcollection(uid, 'saved');
    for (final s in saved) {
      try {
        await _db.insert('saved_content', s..remove('_docId'));
      } catch (_) {}
    }

    // Kişisel görevler
    final tasks = await _firebase.getSubcollection(uid, 'tasks');
    for (final t in tasks) {
      try {
        await _db.insert('custom_tasks', t..remove('_docId'));
      } catch (_) {}
    }

    // Görev tamamlamaları
    final completions =
        await _firebase.getSubcollection(uid, 'taskCompletions');
    for (final c in completions) {
      try {
        await _db.insert('custom_task_completions', c..remove('_docId'));
      } catch (_) {}
    }

    // Ödüller
    final rewards = await _firebase.getSubcollection(uid, 'rewards');
    for (final r in rewards) {
      try {
        await _db.insert('rewards', r..remove('_docId'));
      } catch (_) {}
    }

    // Kur'ân okuma takibi (Firestore doc ID = tarih string'i)
    final quranDocs = await _firebase.getSubcollection(uid, 'quranTracking');
    for (final q in quranDocs) {
      try {
        final date = q['_docId'] as String?;
        if (date == null) continue;
        await _db.insert('quran_tracking', {
          'date': date,
          'isRead': q['isRead'] == true ? 1 : 0,
          'readAt':
              q['readAt']?.toString() ?? DateTime.now().toIso8601String(),
        });
      } catch (_) {}
    }

    // Rozetler
    final badges = await _firebase.getSubcollection(uid, 'badges');
    for (final b in badges) {
      try {
        final row = Map<String, dynamic>.from(b)..remove('_docId');
        row.putIfAbsent('isDisplayed', () => 0);
        await _db.insert('badges', row);
      } catch (_) {}
    }

    // Hatırlatıcılar
    final reminders = await _firebase.getSubcollection(uid, 'reminders');
    for (final r in reminders) {
      try {
        await _db.insert('reminders', r..remove('_docId'));
      } catch (_) {}
    }
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

  /// E-posta doğrulama durumunu Firebase'den sorgulayıp SQLite'ı günceller.
  Future<bool> syncEmailVerified() async {
    final verified = await _firebase.reloadAndCheckVerified();
    final user = await getCurrentUser();
    if (user != null && verified && !user.isEmailVerified) {
      await updateUser(user.copyWith(isEmailVerified: true));
    }
    return verified;
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

    // Streak verisini Firestore'a yedekle (yeniden yükleme koruması)
    final uid = _storage.userId;
    if (uid != null) {
      _firebase.saveUserPrefs(uid, _storage.toSyncMap());
    }
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
