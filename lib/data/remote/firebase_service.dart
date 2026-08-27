import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show debugPrint;
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

  /// Şifre ile yeniden kimlik doğrula — hesap silme gibi hassas işlemlerden
  /// hemen önce Firebase'in zorunlu tuttuğu "recent login" kontrolü için.
  Future<void> reauthenticateWithPassword(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Oturum bulunamadı.');
    }
    final credential =
        EmailAuthProvider.credential(email: user.email!, password: password);
    await user.reauthenticateWithCredential(credential);
  }

  /// Firebase Auth kullanıcısını kalıcı olarak siler. Çağrılmadan önce
  /// [reauthenticateWithPassword] ile yeniden kimlik doğrulanmalı, aksi
  /// halde Firebase 'requires-recent-login' hatası fırlatır.
  Future<void> deleteAuthUser() async {
    await _auth.currentUser?.delete();
  }

  // ─── USER ─────────────────────────────────────────────────────────────────
  Future<void> saveUser(UserModel user) async {
    await _userCol().doc(user.id).set(user.toFirestoreMap(), SetOptions(merge: true));
  }

  /// Yalnızca `email` alanını günceller — bkz. UserRepository.
  /// syncEmailFromAuth. Tüm UserModel'i yeniden yazmak yerine tek alanlık
  /// bir merge ile, o anda elde olmayabilecek diğer alanları riske atmadan
  /// günceller.
  Future<void> updateUserEmail(String uid, String newEmail) async {
    await _userCol().doc(uid).set({'email': newEmail}, SetOptions(merge: true));
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

  Future<void> deleteTaskCompletion(String uid, String completionId) async {
    await _sub(uid, 'taskCompletions').doc(completionId).delete();
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

  /// Play Store hesap silme politikası (bkz. Kullanıcı Verileri Politikası —
  /// "Account Deletion") gereği: kullanıcının Firestore'daki TÜM verilerini
  /// (ana doküman + alt koleksiyonlar) kalıcı olarak siler. Auth kullanıcısı
  /// ayrıca [deleteAuthUser] ile silinmelidir.
  Future<void> deleteAccountData(String uid) async {
    const subcollections = [
      'notes',
      'saved',
      'tasks',
      'taskCompletions',
      'rewards',
      'quranTracking',
      'tahajjudTracking',
      'badges',
      'reminders',
      // quranProgress: QuranRepository.saveProgress/loadProgress tarafından
      // kullanılan, "kaldığın yer" tek dokümanlık ilerleme kaydı. Önceden bu
      // listede yoktu — hesap silindikten sonra Firestore'da kalıcı olarak
      // kalıyordu.
      'quranProgress',
    ];
    for (final col in subcollections) {
      await _deleteAllDocsIn(_sub(uid, col));
    }
    await _userCol().doc(uid).delete();
    await _deleteStorageFolder('notes/$uid');
  }

  /// Hesap silinirken çağrılır: kullanıcı admin veya owner ise `roles`
  /// koleksiyonundaki kaydını da temizler. DÜZELTME: önceden bu hiç
  /// yapılmıyordu. Bir admin hesabını silince `roles/{uid}` belgesi kalıcı
  /// bir "hayalet" kayıt olarak kalıyordu (zararsız ama gereksiz); daha
  /// önemlisi OWNER hesabını silerse `roles/owner` belgesi ARTIK VAR
  /// OLMAYAN bir UID'yi göstermeye devam ediyordu — bu da
  /// RoleService.isOwnerConfigured() sonsuza dek `true` döndüğünden,
  /// hiç kimsenin bir daha asla sahipliği talep edememesine yol açardı
  /// (bkz. login_screen.dart'taki owner ilk kurulum kilidi düzeltmesi).
  /// Best-effort — hata hesap silme akışını engellemez.
  Future<void> deleteRoleRecordIfAny(String uid) async {
    try {
      final ownerRef = _db.collection('roles').doc('owner');
      final ownerDoc = await ownerRef.get();
      if (ownerDoc.exists && ownerDoc.data()?['uid'] == uid) {
        await ownerRef.delete();
        return; // owner belgesi silindiyse ayrıca bir admin belgesi olamaz
      }
    } catch (e) {
      debugPrint('[FirebaseService] roles/owner silinemedi: $e');
    }
    try {
      await _db.collection('roles').doc(uid).delete();
    } catch (e) {
      debugPrint('[FirebaseService] roles/$uid silinemedi: $e');
    }
  }

  /// `users/{uid}` alt koleksiyonlarının DIŞINDA kalan, kullanıcıyla
  /// ilişkili kişisel kayıtları temizler: admin başvurusu ve gönderdiği/
  /// aldığı bildirimler (bkz. firestore.rules — bu iki koleksiyonda artık
  /// kullanıcının kendi adına/kendisine ait kayıtları silmesine izin
  /// veriliyor). Best-effort — hata hesap silme akışını engellemez.
  /// Not: topluluk üyelikleri RoleService.leaveCommunity ile, mesaj geçmişi
  /// ise ayrı bir sunucu taraflı (Cloud Functions) temizlik gerektirdiğinden
  /// burada kapsam dışıdır.
  Future<void> deletePersonalRecordsOutsideUserDoc(String uid) async {
    try {
      await _db.collection('adminRequests').doc(uid).delete();
    } catch (_) {}
    try {
      final asTarget = await _db
          .collection('notifications')
          .where('targetUid', isEqualTo: uid)
          .get();
      final asSender = await _db
          .collection('notifications')
          .where('fromUid', isEqualTo: uid)
          .get();
      final seenIds = <String>{};
      final batch = _db.batch();
      for (final doc in [...asTarget.docs, ...asSender.docs]) {
        if (!seenIds.add(doc.id)) continue;
        batch.delete(doc.reference);
      }
      if (seenIds.isNotEmpty) await batch.commit();
    } catch (_) {}
  }

  /// Storage'daki bir klasörü (ör. kullanıcının not eklerini) en iyi çaba
  /// (best-effort) ile siler. Hata olursa hesap silme işlemini engellemez,
  /// ama en azından debug loguna düşer (önceden tamamen sessizdi — bir
  /// yükleme/izin hatası fark edilmeden kalıyordu).
  Future<void> _deleteStorageFolder(String path) async {
    try {
      final ref = FirebaseStorage.instance.ref(path);
      final result = await ref.listAll();
      for (final item in result.items) {
        try {
          await item.delete();
        } catch (e) {
          debugPrint('[FirebaseService] Storage dosyası silinemedi ($path): $e');
        }
      }
      for (final prefix in result.prefixes) {
        await _deleteStorageFolder(prefix.fullPath);
      }
    } catch (e) {
      debugPrint('[FirebaseService] Storage klasörü silinemedi ($path): $e');
    }
  }

  Future<void> _deleteAllDocsIn(CollectionReference col) async {
    // Büyük koleksiyonlarda tek seferde silmemek için sayfalı siliyoruz.
    while (true) {
      final snap = await col.limit(200).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < 200) break;
    }
  }

  /// Bir kullanıcı dokümanının Firestore'da GERÇEKTEN var olup olmadığını,
  /// ağ/izin hatasıyla karıştırmadan sorgular.
  /// DÜZELTME: getUserForSQLite (ve dolayısıyla restoreFromFirestore) hem
  /// "belge yok" hem de "sorgu hata verdi" durumlarında aynı şekilde
  /// null/false dönüyordu. login_screen.dart bu ikisini ayırt edemediği
  /// için, geçici bir ağ hatasında bile gerçek/mevcut bir kullanıcıyı
  /// "tamamen yeni kullanıcı" sayıp ProfileSetupScreen'e yönlendiriyor,
  /// bu da Firestore'daki mevcut profille çakışan/onu ezen ikinci bir
  /// kurulum akışına yol açabiliyordu. Dönüş: true/false = kesin sonuç,
  /// null = sorgu başarısız oldu (durum bilinmiyor).
  Future<bool?> userDocExists(String uid) async {
    try {
      final doc = await _userCol().doc(uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('[FirebaseService] userDocExists hata: $e');
      return null;
    }
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
