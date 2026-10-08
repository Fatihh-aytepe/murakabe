import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../core/services/role_service.dart';
import '../local/database_helper.dart';
import '../local/local_storage.dart';
import '../local/note_file_storage.dart';
import '../models/user_model.dart';
import '../remote/firebase_service.dart';

class UserRepository {
  final DatabaseHelper _db = DatabaseHelper();
  final LocalStorage _storage = LocalStorage();
  final FirebaseService _firebase = FirebaseService();

  /// Kimlik doğrulaması BAŞARILI OLDUKTAN sonra, yeni hesabın verisini
  /// yerelde okumadan/yazmadan ÖNCE çağrılmalıdır (bkz. login_screen.dart
  /// normal giriş + hesap değiştirme akışları, ve createUser aşağıda).
  ///
  /// Neden gerekli: notes, saved_content, quran_tracking, tahajjud_tracking,
  /// reminders, daily_index, rewards, badges gibi yerel SQLite tabloları
  /// `userId` kolonu TAŞIMAZ — cihaz tek seferde tek bir aktif hesabın
  /// verisini tutacak şekilde tasarlanmıştır. Bu yüzden aynı cihazda B
  /// hesabına geçilirken A hesabının satırları temizlenmezse, B'nin
  /// ekranları (ör. not listesi — bkz. NoteRepository.getAllNotes, hiçbir
  /// WHERE/userId filtresi yok) A'nın notlarını/ödüllerini/rozetlerini de
  /// gösterir, hatta B bunları düzenleyip silebilir.
  ///
  /// [uid] az önce giriş yapılan/oluşturulan Firebase Auth kullanıcısının
  /// UID'sidir. Yereldeki önceki aktif hesap farklıysa (ve boş değilse) tüm
  /// SQLite tabloları ve SharedPreferences (kayıtlı hesap listesi hariç)
  /// temizlenir — tıpkı hesap silmede olduğu gibi, ama hesap listesi kalır.
  Future<void> prepareLocalDataForUid(String uid) async {
    final previousUid = _storage.userId;
    if (previousUid == null || previousUid.isEmpty || previousUid == uid) {
      return;
    }
    // Henüz Firestore'a yansımamış olabilecek streak/rozet/tercih verisini
    // kaybetmemek için son bir senkron denemesi yapılır (best-effort).
    try {
      await _firebase.saveUserPrefs(previousUid, _storage.toSyncMap());
    } catch (_) {}
    await _db.wipeAllTables();
    await _storage.clearForAccountSwitch();
  }

  /// E-posta değişikliğini Firebase Auth ile senkronize eder.
  ///
  /// NEDEN: FirebaseService.updateEmail, `verifyBeforeUpdateEmail` kullanır
  /// — bu, Auth'taki e-postayı HEMEN değiştirmez; kullanıcı yeni adresine
  /// gelen doğrulama linkine tıkladığında (uygulama kapalıyken bile
  /// olabilir, dakikalar/günler sonra) Firebase tarafında arka planda
  /// gerçekleşir. Önceden bu değişikliği hiçbir yer izlemiyordu: SQLite'taki
  /// `users` satırı, Firestore kullanıcı belgesi ve `savedAccounts`
  /// listesindeki kayıtlı hesap kartı hep ESKİ e-postada kalıyordu — kayıtlı
  /// hesap kartına dokunup tekrar giriş denemek artık geçersiz olan eski
  /// e-postayla başarısız oluyordu.
  ///
  /// Sunucu taraflı bir tetikleyici (Cloud Function) olmadığı için tam
  /// gerçek-zamanlı bir çözüm yok; bunun yerine `reload()` sonrası Auth'taki
  /// güncel e-posta ile yereldeki kaydı KARŞILAŞTIRIP farklıysa üç yeri de
  /// (SQLite, Firestore, savedAccounts) senkronize ediyoruz. Uygulama her
  /// açılışında/öne döndüğünde çağrılmalı (bkz. HomeScreen).
  Future<void> syncEmailFromAuth() async {
    try {
      await _firebase.reloadAndCheckVerified();
      final authEmail = _firebase.currentAuthUser?.email;
      final uid = _storage.userId;
      if (authEmail == null || authEmail.isEmpty || uid == null) return;

      final local = await getCurrentUser();
      if (local == null || local.email == authEmail) return;

      await _db.update(
        'users',
        {'email': authEmail},
        where: 'id = ?',
        whereArgs: [uid],
      );
      try {
        await _firebase.updateUserEmail(uid, authEmail);
      } catch (_) {}
      try {
        await _storage.updateAccountEmail(uid, authEmail);
      } catch (_) {}
    } catch (_) {
      // En kötü ihtimalle bir sonraki açılışta/resume'da tekrar denenir —
      // uygulama akışını asla engellemesin.
    }
  }

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

    // Cihazda başka bir hesabın verisi kalmışsa (ör. düzgün çıkış yapılmadan
    // yeni hesap oluşturulduysa) yeni hesabın önceki hesabın yerel verisini
    // miras almaması için temizle.
    await prepareLocalDataForUid(authUser.uid);

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
  ///
  /// DÜZELTME: önceden `_restoreSubcollections` içindeki HERHANGİ bir hata
  /// (ör. tek bir alt koleksiyonun `getSubcollection` çağrısı ağ hatasıyla
  /// patlarsa) tek bir dıştaki try/catch'e düşüyor, o noktadan SONRAKİ TÜM
  /// alt koleksiyonların denenmesini engelliyor, ve yine de bu fonksiyon
  /// `true` (başarılı) dönüyordu — kullanıcı profili yüklenmiş ama notları/
  /// görevleri/ödülleri hiç gelmemiş olabiliyordu, hem de bir daha
  /// denenmeden. Şimdi her alt koleksiyon KENDİ try/catch'i içinde
  /// deneniyor (biri patlarsa diğerleri yine de denenir) ve tümü başarılı
  /// olmazsa `LocalStorage`'a bir "yeniden dene" bayrağı bırakılıyor —
  /// bkz. retryPendingSubcollectionRestore, HomeScreen'den best-effort
  /// çağrılır.
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

      final allSubcollectionsOk = await _restoreSubcollections(uid);
      if (allSubcollectionsOk) {
        await _storage.clearPendingSubcollectionRestore();
        debugPrint('[UserRepo] Firestore restore başarılı: $uid');
      } else {
        await _storage.setPendingSubcollectionRestore(uid);
        debugPrint(
            '[UserRepo] Firestore restore KISMEN başarılı (bazı koleksiyonlar başarısız): $uid');
      }
      // Profil dokümanı başarıyla yüklendiği için true dönüyoruz — eksik
      // kalan alt koleksiyonlar retryPendingSubcollectionRestore ile ayrıca
      // tamamlanmaya çalışılacak; çağıran kod bunu ayrı bir sinyal
      // (getPendingSubcollectionRestoreUid) ile ayırt edebilir.
      return true;
    } catch (e) {
      debugPrint('[UserRepo] restoreFromFirestore hatası: $e');
      return false;
    }
  }

  /// HomeScreen açılışında best-effort çağrılmalı: önceki bir restore'da
  /// eksik kalan alt koleksiyonları varsa yeniden dener. Buradaki insert'ler
  /// zaten kendi try/catch'leri içinde olduğundan, önceden başarıyla
  /// eklenmiş satırların yeniden denenmesi (UNIQUE ihlali) sessizce yutulur
  /// — yani bu işlem doğal olarak tekrar çalıştırmaya (idempotent) güvenlidir.
  Future<void> retryPendingSubcollectionRestore() async {
    final uid = _storage.pendingSubcollectionRestoreUid;
    if (uid == null || uid.isEmpty || uid != _storage.userId) return;
    final ok = await _restoreSubcollections(uid);
    if (ok) await _storage.clearPendingSubcollectionRestore();
  }

  /// Her alt koleksiyonu KENDİ try/catch'i içinde dener — biri (ör. ağ
  /// hatasıyla) başarısız olsa da diğerleri yine de denenir. Tümü
  /// başarılıysa true döner.
  Future<bool> _restoreSubcollections(String uid) async {
    var allOk = true;

    // Notlar
    try {
      final notes = await _firebase.getSubcollection(uid, 'notes');
      for (final n in notes) {
        try {
          final row = Map<String, dynamic>.from(n)..remove('_docId');
          await _db.insert('notes', row);
          await _restoreNoteAttachments(row);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[UserRepo] notes restore hatası: $e');
      allOk = false;
    }

    // Kaydedilenler (heybe)
    try {
      final saved = await _firebase.getSubcollection(uid, 'saved');
      for (final s in saved) {
        try {
          await _db.insert('saved_content', s..remove('_docId'));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[UserRepo] saved restore hatası: $e');
      allOk = false;
    }

    // Kişisel görevler
    try {
      final tasks = await _firebase.getSubcollection(uid, 'tasks');
      for (final t in tasks) {
        try {
          final taskMap = Map<String, dynamic>.from(t)..remove('_docId');
          taskMap['userId'] = uid;
          await _db.insert('custom_tasks', taskMap);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[UserRepo] tasks restore hatası: $e');
      allOk = false;
    }

    // Görev tamamlamaları
    try {
      final completions =
          await _firebase.getSubcollection(uid, 'taskCompletions');
      for (final c in completions) {
        try {
          await _db.insert('custom_task_completions', c..remove('_docId'));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[UserRepo] taskCompletions restore hatası: $e');
      allOk = false;
    }

    // Ödüller
    try {
      final rewards = await _firebase.getSubcollection(uid, 'rewards');
      for (final r in rewards) {
        try {
          await _db.insert('rewards', r..remove('_docId'));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[UserRepo] rewards restore hatası: $e');
      allOk = false;
    }

    // Kur'ân okuma takibi (Firestore doc ID = tarih string'i)
    try {
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
    } catch (e) {
      debugPrint('[UserRepo] quranTracking restore hatası: $e');
      allOk = false;
    }

    // Rozetler
    try {
      final badges = await _firebase.getSubcollection(uid, 'badges');
      for (final b in badges) {
        try {
          final row = Map<String, dynamic>.from(b)..remove('_docId');
          row.putIfAbsent('isDisplayed', () => 0);
          await _db.insert('badges', row);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[UserRepo] badges restore hatası: $e');
      allOk = false;
    }

    // Hatırlatıcılar
    try {
      final reminders = await _firebase.getSubcollection(uid, 'reminders');
      for (final r in reminders) {
        try {
          await _db.insert('reminders', r..remove('_docId'));
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[UserRepo] reminders restore hatası: $e');
      allOk = false;
    }

    return allOk;
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
    // İdempotent olmalı: aynı [date] için ikinci kez çağrılırsa (ör. hızlı
    // çift dokunma — bkz. home_screen.dart QuranTrackerCard.onRead; buton
    // yalnızca `isRead` state'i güncellendikten SONRA gizleniyor, aradaki
    // pencerede ikinci bir çağrı mümkün) toplam okuma günü SAYISI tekrar
    // artmamalı ve seri (streak) SIFIRLANMAMALI. Önceden korumasız ikinci
    // çağrıda `lastStreakDate` zaten "bugün" olduğundan _yesterday() ile
    // eşleşmiyor ve seri yanlışlıkla 1'e düşüyordu.
    final already = await _db.query(
      'quran_tracking',
      where: 'date = ? AND isRead = 1',
      whereArgs: [date],
    );
    if (already.isNotEmpty) return;

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

    // Firestore yazımı BEKLENMEZ — sunucu onayını beklemek "Okudum"
    // butonunu geciktiriyordu.
    final readUid = _storage.userId;
    if (readUid != null) {
      unawaited(_firebase.markQuranRead(readUid, date).catchError((_) {}));
    }

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
  /// 2) Topluluk üyelikleri + admin/owner rol kaydı (varsa)
  /// 3) Firestore: ana kullanıcı dokümanı + tüm alt koleksiyonlar
  /// 4) Firebase Storage: kullanıcının yüklediği dosyalar (not ekleri)
  /// 5) Firebase Auth kullanıcısı
  /// 6) Cihazdaki tüm yerel veri (SQLite + SharedPreferences + not
  ///    resim/ses dosyaları)
  ///
  /// Sıra önemli: Auth kullanıcısı en son silinir, çünkü Firestore/Storage
  /// silme işlemleri (rol kaydı dahil) güvenlik kurallarında
  /// `request.auth.uid == userId` kontrolüne dayanıyor — önce Auth'u
  /// silersek geri kalan adımlar yetkisiz kalır.
  Future<void> deleteAccountPermanently(String password) async {
    final uid = _storage.userId;
    if (uid == null || uid.isEmpty) {
      throw Exception('Aktif oturum bulunamadı.');
    }

    // 1. Yeniden kimlik doğrulama
    await _firebase.reauthenticateWithPassword(password);

    // 2. Topluluk üyeliklerinden ayrıl — Auth silinmeden ÖNCE yapılmalı,
    // çünkü hem üyelik hem sayaç güncellemesi request.auth.uid'ye dayanıyor.
    // Önceden bu adım hiç yoktu: hesap silindikten sonra topluluk üye
    // listelerinde kullanıcıya ait "hayalet" bir kayıt sonsuza dek kalıyordu.
    try {
      final communityIds = await RoleService().getUserCommunityIds();
      for (final communityId in communityIds) {
        // Önce kullanıcının bu topluluktaki mesaj geçmişi silinir (üyelik
        // hâlâ varken — listeleme için gerekli). Önceden mesajlar (UID, ad,
        // metin) hesap silindikten sonra da toplulukta kalıyordu.
        try {
          await RoleService().deleteOwnMessagesIn(communityId);
        } catch (e) {
          debugPrint('[UserRepo] Topluluk mesajları silinemedi ($communityId): $e');
        }
        await RoleService().leaveCommunity(communityId);
      }
    } catch (e) {
      debugPrint('[UserRepo] Topluluk üyelikleri temizlenemedi: $e');
    }

    // 3. users/{uid} dışındaki kişisel kayıtlar (admin başvurusu, gönderdiği/
    // aldığı bildirimler) — bkz. FirebaseService.deletePersonalRecordsOutsideUserDoc.
    await _firebase.deletePersonalRecordsOutsideUserDoc(uid);

    // 3b. Admin/owner rol kaydı varsa temizle (bkz. FirebaseService.
    // deleteRoleRecordIfAny — önceden bu hiç yapılmıyordu, owner hesabını
    // silen kimse kalırsa roles/owner sonsuza dek ele geçirilemez kalırdı).
    try {
      await _firebase.deleteRoleRecordIfAny(uid);
    } catch (e) {
      debugPrint('[UserRepo] Rol kaydı temizlenemedi: $e');
    }

    // 4a. Not eklerini NOT BAZINDA sil (notes/{uid}/{noteId}/...). Bu
    // seviyedeki listeleme mevcut Storage kurallarıyla da izinli; böylece
    // yeni storage.rules henüz yayınlanmamış olsa bile ekler silinir.
    // (deleteAccountData içindeki üst klasör temizliği ek güvence olarak
    // kalıyor.)
    try {
      final noteRows = await _db.query('notes');
      for (final row in noteRows) {
        final noteId = row['id'] as String?;
        if (noteId == null || noteId.isEmpty) continue;
        await NoteFileStorage.deleteNoteFolder(uid, noteId);
      }
    } catch (e) {
      debugPrint('[UserRepo] Not ekleri silinemedi: $e');
    }

    // 4 + 5. Firestore (ana doküman + alt koleksiyonlar, quranProgress dahil) + Storage verisi
    await _firebase.deleteAccountData(uid);

    // 6. Auth kullanıcısı
    await _firebase.deleteAuthUser();

    // 7. Yerel veri — yalnızca BU hesaba ait. Cihazdaki diğer kayıtlı
    // hesapların (savedAccounts — hesap değiştirme listesi) girdisi korunur;
    // yalnızca silinen hesap listeden çıkarılır (bkz. LocalStorage.clearAllForAccountDeletion).
    await _db.wipeAllTables();
    await _storage.clearAllForAccountDeletion(uid);

    // 8. Notlara eklenen yerel resim/ses dosyaları (bkz. NoteFileStorage.
    // deleteAllLocalFiles — önceden yalnızca SQLite satırları siliniyordu,
    // gerçek dosyalar diskte öksüz kalıyordu).
    await NoteFileStorage.deleteAllLocalFiles();
  }
}
