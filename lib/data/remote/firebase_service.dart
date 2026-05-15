import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference _userCol() => _db.collection('users');
  CollectionReference _sub(String uid, String col) =>
      _userCol().doc(uid).collection(col);

  // ─── AUTH ─────────────────────────────────────────────────────────────────

  /// Firebase Auth ile yeni kullanıcı oluşturur ve doğrulama maili gönderir.
  /// Dönen [UserCredential.user.uid] Firestore doküman ID'si olarak kullanılır.
  Future<User> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    // Doğrulama maili gönder
    await user.sendEmailVerification();
    return user;
  }

  /// Firebase Auth ile e-posta/şifre girişi.
  Future<User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!;
  }

  /// Oturumu kapatır.
  Future<void> signOut() => _auth.signOut();

  /// Mevcut Auth kullanıcısı (null ise giriş yapılmamış).
  User? get currentAuthUser => _auth.currentUser;

  /// E-posta doğrulandı mı? (her açılışta yeniden sorgular)
  Future<bool> reloadAndCheckVerified() async {
    await _auth.currentUser?.reload();

    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Doğrulama mailini tekrar gönderir.
  Future<void> resendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Şifre sıfırlama maili gönderir.
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// E-posta değiştir: önce yeniden kimlik doğrula, sonra doğrulama maili gönder.
  Future<void> updateEmail(String newEmail, String password) async {
    final user = _auth.currentUser!;
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
    await user.verifyBeforeUpdateEmail(newEmail);
  }

  /// Auth display name güncelle.
  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name);
  }

  // ─── USER ─────────────────────────────────────────────────────────────────
  Future<void> saveUser(UserModel user) async {
    await _userCol().doc(user.id).set(user.toFirestoreMap(), SetOptions(merge: true));
  }

  // ─── NOTES ────────────────────────────────────────────────────────────────
  Future<void> saveNote(String uid, Map<String, dynamic> note) async {
    await _sub(uid, 'notes').doc(note['id'] as String).set(note);
  }

  Future<void> deleteNote(String uid, String noteId) async {
    await _sub(uid, 'notes').doc(noteId).delete();
  }

  // ─── REMINDERS ────────────────────────────────────────────────────────────
  Future<void> saveReminder(String uid, Map<String, dynamic> reminder) async {
    await _sub(uid, 'reminders').doc(reminder['id'] as String).set(reminder);
  }

  Future<void> deleteReminder(String uid, String reminderId) async {
    await _sub(uid, 'reminders').doc(reminderId).delete();
  }

  // ─── CUSTOM TASKS ─────────────────────────────────────────────────────────
  Future<void> saveTask(String uid, Map<String, dynamic> task) async {
    await _sub(uid, 'tasks').doc(task['id'] as String).set(task);
  }

  Future<void> deleteTask(String uid, String taskId) async {
    await _sub(uid, 'tasks').doc(taskId).delete();
  }

  Future<void> saveTaskCompletion(
      String uid, Map<String, dynamic> completion) async {
    await _sub(uid, 'taskCompletions')
        .doc(completion['id'] as String)
        .set(completion);
  }

  // ─── SAVED CONTENT (heybe) ────────────────────────────────────────────────
  Future<void> saveFavorite(String uid, Map<String, dynamic> content) async {
    await _sub(uid, 'saved').doc(content['id'] as String).set(content);
  }

  Future<void> deleteFavorite(String uid, String contentId) async {
    await _sub(uid, 'saved').doc(contentId).delete();
  }

  // ─── REWARDS ──────────────────────────────────────────────────────────────
  Future<void> saveReward(String uid, Map<String, dynamic> reward) async {
    await _sub(uid, 'rewards').doc(reward['id'] as String).set(reward);
  }

  // ─── QURAN TRACKING ───────────────────────────────────────────────────────
  Future<void> markQuranRead(String uid, String date) async {
    await _sub(uid, 'quranTracking').doc(date).set({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── TAHAJJUD TRACKING ────────────────────────────────────────────────────
  Future<void> markTahajjudPrayed(String uid, String date) async {
    await _sub(uid, 'tahajjudTracking').doc(date).set({
      'isPrayed': true,
      'prayedAt': FieldValue.serverTimestamp(),
    });
  }

  // ─── USER PREFS SYNC ──────────────────────────────────────────────────────
  // Streak, rozet ve tercih verilerini users/{uid} dokümanına kaydeder.
  // Uygulama silme/yeniden yüklemede bu veriler Firestore'dan geri yüklenir.
  Future<void> saveUserPrefs(String uid, Map<String, dynamic> prefs) async {
    try {
      await _userCol().doc(uid).set(prefs, SetOptions(merge: true));
    } catch (_) {}
  }

  // users/{uid} dokümanını okur; yoksa null döner.
  Future<Map<String, dynamic>?> getUserPrefs(String uid) async {
    try {
      final doc = await _userCol().doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // ─── SUBCOLLECTION RESTORE ────────────────────────────────────────────────

  // Bir subcollection'ın tüm dokümanlarını döner.
  // Timestamp alanları otomatik olarak ISO string'e çevrilir.
  // Her map'te '_docId' anahtarı altında Firestore doküman ID'si bulunur.
  Future<List<Map<String, dynamic>>> getSubcollection(
      String uid, String col) async {
    try {
      final snap = await _sub(uid, col).get();
      return snap.docs.map((d) {
        final data = _sanitize(
            Map<String, dynamic>.from(d.data() as Map<String, dynamic>));
        data['_docId'] = d.id;
        return data;
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic> _sanitize(Map<String, dynamic> map) =>
      map.map((k, v) => MapEntry(
            k,
            v is Timestamp ? v.toDate().toIso8601String() : v,
          ));

  // ─── BADGES ───────────────────────────────────────────────────────────────
  Future<void> saveBadgeRecord(String uid, Map<String, dynamic> badge) async {
    try {
      await _sub(uid, 'badges').doc(badge['badgeId'] as String).set(badge);
    } catch (_) {}
  }

  // ─── ADMIN ────────────────────────────────────────────────────────────────
  Stream<QuerySnapshot> getAllUsers() =>
      _userCol().orderBy('createdAt', descending: true).snapshots();

  Future<Map<String, dynamic>?> getUserDetails(String uid) async {
    final doc = await _userCol().doc(uid).get();
    return doc.data() as Map<String, dynamic>?;
  }

  /// Firestore'daki kullanıcıyı SQLite'a yazılabilir Map olarak döner.
  /// Timestamp → ISO string, List → JSON string dönüşümlerini yapar.
  Future<Map<String, dynamic>?> getUserForSQLite(String uid) async {
    try {
      final doc = await _userCol().doc(uid).get();
      if (!doc.exists) return null;
      final raw = doc.data() as Map<String, dynamic>;
      final map = Map<String, dynamic>.from(raw);
      map['id'] = uid;

      if (map['createdAt'] is Timestamp) {
        map['createdAt'] =
            (map['createdAt'] as Timestamp).toDate().toIso8601String();
      } else {
        map['createdAt'] ??= DateTime.now().toIso8601String();
      }

      map['missedQuranDays'] = map['missedQuranDays'] is List
          ? jsonEncode(map['missedQuranDays'])
          : (map['missedQuranDays']?.toString() ?? '[]');

      map['tahajjudAlarmTimes'] = map['tahajjudAlarmTimes'] is List
          ? jsonEncode(map['tahajjudAlarmTimes'])
          : (map['tahajjudAlarmTimes']?.toString() ?? '[]');

      return map;
    } catch (_) {
      return null;
    }
  }
}
