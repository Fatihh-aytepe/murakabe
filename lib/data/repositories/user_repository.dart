import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../local/database_helper.dart';
import '../local/local_storage.dart';
import '../local/note_file_storage.dart';
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

    // Auth displayName'i set et — sonraki girişlerde isim doğru görünsün
    try {
      await _firebase.updateDisplayName(nameSurname);
    } catch (_) {}

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

    // 3. Firestore'a yaz — başarısız olursa kayıt tamamlanmış sayılmaz
    await _firebase.saveUser(user);

    return user;
  }

  /// Uygulama yeniden yüklendiğinde Firestore'dan SQLite'a kullanıcıyı geri yükler.
  /// Ana kullanıcı dokümanının yanı sıra tüm subcollection'lar da geri yüklenir.
  Future<bool> restoreFromFirestore(String uid) async {
    try {
      final raw = await _firebase.getUserForSQLite(uid);
      if (raw == null) {
        debugPrint('[UserRepo] Firestore kullanıcı dokümanı bulunamadı: $uid');
        return false;
      }
      // Sadece UserModel alanlarını SQLite'a yaz; bilinmeyen Firestore alanları
      // (lastRewardedEsmaBadge, isDarkMode vb.) kolon yoksa insert'i patlatır.
      final user = UserModel.fromMap(raw);
      final map = user.toMap();
      map['missedQuranDays'] = raw['missedQuranDays'] is String
          ? raw['missedQuranDays']
          : jsonEncode(user.missedQuranDays);
      map['tahajjudAlarmTimes'] = raw['tahajjudAlarmTimes'] is String
          ? raw['tahajjudAlarmTimes']
          : jsonEncode(
              user.tahajjudAlarmTimes.map((e) => e.toIso8601String()).toList());

      final existing =
          await _db.query('users', where: 'id = ?', whereArgs: [uid]);
      if (existing.isNotEmpty) {
        await _db.update('users', map, where: 'id = ?', whereArgs: [uid]);
      } else {
        await _db.insert('users', map);
      }
      try {
        await _restoreSubcollections(uid);
      } catch (e) {
        debugPrint('[UserRepo] Subcollection restore hatası: $e');
      }
      debugPrint('[UserRepo] Firestore restore başarılı: $uid');
      return true;
    } catch (e) {
      debugPrint('[UserRepo] restoreFromFirestore hatası: $e');
      return false;
    }
  }

  Future<void> _restoreSubcollections(String uid) async {
    // Notlar
    final notes = await _firebase.getSubcollection(uid, 'notes');
    for (final n in notes) {
      try {
        final row = Map<String, dynamic>.from(n)..remove('_docId');
        await _db.insert('notes', row);
        await _restoreNoteAttachments(row);
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
        final taskMap = Map<String, dynamic>.from(t)..remove('_docId');
        taskMap['userId'] = uid;
        await _db.insert('custom_tasks', taskMap);
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

  /// Firestore'dan geri yüklenen bir not satırındaki resim/ses dosyaları
  /// cihazda yoksa (uygulama yeni yüklendiyse), Storage URL'lerinden tekrar
  /// indirir ve yerel path listesini günceller. URL yoksa (eski notlar,
  /// yükleme hiç yapılmamışsa) ek sessizce atlanır — not metni yine de kalır.
  Future<void> _restoreNoteAttachments(Map<String, dynamic> row) async {
    List<String> parseList(dynamic raw) {
      if (raw is String && raw.isNotEmpty) {
        try {
          return List<String>.from(jsonDecode(raw) as List);
        } catch (_) {}
      }
      return const [];
    }

    final noteId = row['id'] as String?;
    if (noteId == null) return;

    final imagePaths = parseList(row['imagePaths']);
    final imageUrls = parseList(row['imageUrls']);
    final audioPaths = parseList(row['audioPaths']);
    final audioUrls = parseList(row['audioUrls']);

    Future<List<String>> resolve(
        List<String> paths, List<String> urls, bool isImage) async {
      final result = List<String>.from(paths);
      for (var i = 0; i < result.length; i++) {
        final exists =
            result[i].isNotEmpty && await File(result[i]).exists();
        if (exists) continue;
        if (i >= urls.length || urls[i].isEmpty) continue;
        final downloaded = await NoteFileStorage.downloadFromUrl(
          url: urls[i],
          isImage: isImage,
        );
        if (downloaded != null) result[i] = downloaded;
      }
      return result;
    }

    final newImagePaths = await resolve(imagePaths, imageUrls, true);
    final newAudioPaths = await resolve(audioPaths, audioUrls, false);

    if (newImagePaths.join() != imagePaths.join() ||
        newAudioPaths.join() != audioPaths.join()) {
      await _db.update(
        'notes',
        {
          'imagePaths': jsonEncode(newImagePaths),
          'audioPaths': jsonEncode(newAudioPaths),
        },
        where: 'id = ?',
        whereArgs: [noteId],
      );
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
    } catch (e) {
      debugPrint('[UserRepo] Firestore saveUser hatası: $e');
    }
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

  /// Hesabı ve tüm verilerini KALICI olarak siler (Play Store hesap silme
  /// politikası — Kullanıcı Verileri Politikası "Hesap Silme" gereksinimi):
  /// 1) Şifre ile yeniden kimlik doğrulama (Firebase 'recent login' şartı)
  /// 2) Firestore: ana kullanıcı dokümanı + tüm alt koleksiyonlar
  /// 3) Firebase Storage: kullanıcının yüklediği dosyalar (not ekleri)
  /// 4) Firebase Auth kullanıcısı
  /// 5) Cihazdaki tüm yerel veri (SQLite + SharedPreferences)
  ///
  /// Sıra önemli: Auth kullanıcısı en son silinir, çünkü Firestore/Storage
  /// silme işlemleri güvenlik kurallarında `request.auth.uid == userId`
  /// kontrolüne dayanıyor — önce Auth'u silersek geri kalan adımlar
  /// yetkisiz kalır.
  Future<void> deleteAccountPermanently(String password) async {
    final uid = _storage.userId;
    if (uid == null || uid.isEmpty) {
      throw Exception('Aktif oturum bulunamadı.');
    }

    // 1. Yeniden kimlik doğrulama
    await _firebase.reauthenticateWithPassword(password);

    // 2 + 3. Firestore + Storage verisi
    await _firebase.deleteAccountData(uid);

    // 4. Auth kullanıcısı
    await _firebase.deleteAuthUser();

    // 5. Yerel veri
    await _db.wipeAllTables();
    await _storage.clearAllForAccountDeletion();
  }
}
