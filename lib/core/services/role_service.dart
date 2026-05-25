import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
// ─── Yetki seviyeleri ─────────────────────────────────────────────────────────
enum UserRole { owner, admin, user }

class RoleService {
  static final RoleService _instance = RoleService._();
  factory RoleService() => _instance;
  RoleService._();

  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String? get currentUid => FirebaseAuth.instance.currentUser?.uid;

  // ── Mevcut kullanıcının rolünü Firestore'dan sorgula ──────────────────────
  Future<UserRole> getCurrentRole() async {
    if (_uid == null) return UserRole.user;
    try {
      // Önce sahip mi kontrol et
      final ownerDoc = await _db.collection('roles').doc('owner').get();
      if (ownerDoc.exists && ownerDoc.data()?['uid'] == _uid) {
        return UserRole.owner;
      }

      // Admin mi kontrol et
      final adminDoc = await _db.collection('roles').doc(_uid).get();
      if (adminDoc.exists && adminDoc.data()?['role'] == 'admin') {
        return UserRole.admin;
      }
    } catch (_) {}
    return UserRole.user;
  }

  // ── Sahip dokümanı var mı kontrol et ─────────────────────────────────────
  Future<bool> isOwnerConfigured() async {
    try {
      final doc = await _db.collection('roles').doc('owner').get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // ── Mevcut kullanıcı sahip mi? (Firebase Auth UID ile karşılaştırır) ──────
  Future<bool> isCurrentUserOwner() async {
    try {
      final authUid = FirebaseAuth.instance.currentUser?.uid;
      debugPrint('[SahipKontrol] Firebase Auth UID: $authUid');
      if (authUid == null) return false;
      final doc = await _db
          .collection('roles')
          .doc('owner')
          .get(const GetOptions(source: Source.server));
      if (!doc.exists) {
        debugPrint('[SahipKontrol] roles/owner belgesi YOK');
        return false;
      }
      final ownerUid = doc.data()?['uid'];
      debugPrint('[SahipKontrol] roles/owner.uid: $ownerUid');
      debugPrint('[SahipKontrol] Eşleşme: ${ownerUid == authUid}');
      return ownerUid == authUid;
    } catch (e) {
      debugPrint('[SahipKontrol] Hata: $e');
      return false;
    }
  }

  // ── İlk kurulum: mevcut kullanıcıyı sahip yap ────────────────────────────
  // Firebase Auth UID kullanılır — LocalStorage ile uyuşmazlık olmasın.
  Future<void> setupOwner() async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid == null) throw Exception('Giriş yapılmamış');
    await _db.collection('roles').doc('owner').set({
      'uid': authUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Admin başvurusu yap ───────────────────────────────────────────────────
  Future<void> applyForAdmin({
    required String name,
    required String reason,
  }) async {
    if (_uid == null) return;

    // Kullanıcının kendi dokümanını doğrudan oku (collection query yerine)
    try {
      final existing =
          await _db.collection('adminRequests').doc(_uid).get();
      if (existing.exists && existing.data()?['status'] == 'pending') {
        throw Exception('Zaten bekleyen bir başvurunuz var');
      }
    } on Exception {
      rethrow;
    } catch (_) {}

    await _db.collection('adminRequests').doc(_uid).set({
      'uid': _uid,
      'name': name,
      'reason': reason,
      'status': 'pending',
      'appliedAt': FieldValue.serverTimestamp(),
    });

    try {
      // Owner'ın UID'sini al ki bildirim ona ulaşsın
      final ownerDoc = await _db.collection('roles').doc('owner').get();
      final ownerUid = ownerDoc.data()?['uid'] as String?;
      await _db.collection('notifications').add({
        'type': 'admin_request',
        'fromUid': _uid,
        'fromName': name,
        if (ownerUid != null) 'targetUid': ownerUid,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (_) {}
  }

  // ── Sahip: admin başvurusunu onayla ──────────────────────────────────────
  Future<void> approveAdmin(String targetUid) async {
    final batch = _db.batch();

    // roles/{uid} = admin
    batch.set(_db.collection('roles').doc(targetUid), {
      'role': 'admin',
      'approvedAt': FieldValue.serverTimestamp(),
      'approvedBy': _uid,
    });

    // adminRequests güncelle
    batch.update(_db.collection('adminRequests').doc(targetUid), {
      'status': 'approved',
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    try {
      await _db.collection('notifications').add({
        'type': 'admin_approved',
        'targetUid': targetUid,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (_) {}
  }

  // ── Sahip: admin başvurusunu reddet ──────────────────────────────────────
  Future<void> rejectAdmin(String targetUid) async {
    await _db.collection('adminRequests').doc(targetUid).update({
      'status': 'rejected',
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    try {
      await _db.collection('notifications').add({
        'type': 'admin_rejected',
        'targetUid': targetUid,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (_) {}
  }

  // ── Admin: Topluluk kur ───────────────────────────────────────────────────
  Future<String> createCommunity({
    required String name,
    required String description,
  }) async {
    if (_uid == null) throw Exception('Giriş yapılmamış');

    final role = await getCurrentRole();
    if (role != UserRole.admin && role != UserRole.owner) {
      throw Exception('Bu işlem için admin yetkisi gerekli');
    }

    final code = _generateCode();

    // inviteCode artık community belgesinde değil; private/config ve inviteLookup'ta tutuluyor
    final ref = await _db.collection('communities').add({
      'name': name,
      'description': description,
      'adminUid': _uid,
      'memberCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final batch = _db.batch();

    // Davet kodunu kısıtlı alt-koleksiyona kaydet
    batch.set(ref.collection('private').doc('config'), {
      'inviteCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Arama tablosuna ekle (katılım doğrulaması için)
    batch.set(_db.collection('inviteLookup').doc(code), {
      'communityId': ref.id,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Admini üye olarak ekle
    batch.set(ref.collection('members').doc(_uid), {
      'uid': _uid,
      'role': 'admin',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();

    return ref.id;
  }

  // ── Admin: Üye davet linki oluştur ───────────────────────────────────────
  Future<String> getInviteCode(String communityId) async {
    final doc = await _db
        .collection('communities')
        .doc(communityId)
        .collection('private')
        .doc('config')
        .get();
    return doc.data()?['inviteCode'] ?? '';
  }

  // ── Kullanıcı: Davet koduyla topluluğa katıl ─────────────────────────────
  Future<void> joinCommunity(String inviteCode) async {
    if (_uid == null) return;

    // inviteLookup'tan communityId'yi çek (community koleksiyonunda where sorgusu yok artık)
    final lookupDoc = await _db.collection('inviteLookup').doc(inviteCode).get();
    if (!lookupDoc.exists) throw Exception('Geçersiz davet kodu');

    final communityId = lookupDoc.data()?['communityId'] as String?;
    if (communityId == null) throw Exception('Geçersiz davet kodu');

    // Zaten üye mi?
    final memberDoc = await _db
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .doc(_uid)
        .get();
    if (memberDoc.exists) throw Exception('Zaten bu topluluğun üyesiniz');

    // Bildirim için topluluk belgesini ayrıca çek
    final communityDoc = await _db.collection('communities').doc(communityId).get();

    final batch = _db.batch();

    // inviteCode kuralda inviteLookup üzerinden doğrulanıyor; üye belgesinde saklanıyor
    batch.set(
      _db
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(_uid),
      {
        'uid': _uid,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
        'inviteCode': inviteCode,
      },
    );

    // Üye sayısını artır
    batch.update(_db.collection('communities').doc(communityId), {
      'memberCount': FieldValue.increment(1),
    });

    await batch.commit();

    // Topluluk adminine "yeni üye" bildirimi gönder
    try {
      final communityData = communityDoc.data();
      final adminUid = communityData?['adminUid'] as String?;
      if (adminUid != null && adminUid != _uid) {
        String joinerName = 'Bir kullanıcı';
        try {
          final userDoc =
              await _db.collection('users').doc(_uid).get();
          joinerName =
              (userDoc.data()?['nameSurname'] as String?) ?? joinerName;
        } catch (_) {}

        await _db.collection('notifications').add({
          'type': 'community_joined',
          'targetUid': adminUid,
          'fromUid': _uid,
          'fromName': joinerName,
          'communityId': communityId,
          'communityName':
              communityData?['name'] as String? ?? 'Topluluk',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
    } catch (_) {}
  }

  // ── Admin: Göreve üye ata ─────────────────────────────────────────────────
  Future<void> assignTask({
    required String communityId,
    required String title,
    required String description,
    required DateTime deadline,
  }) async {
    await _db
        .collection('communities')
        .doc(communityId)
        .collection('tasks')
        .add({
      'title': title,
      'description': description,
      'deadline': Timestamp.fromDate(deadline),
      'assignedBy': _uid,
      'createdAt': FieldValue.serverTimestamp(),
      'completions': {},
    });

    // Her üyeye bildirim yaz (yöneticinin kendisi hariç)
    try {
      final members = await _db
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .get();
      final batch = _db.batch();
      for (final doc in members.docs) {
        final memberUid = doc.data()['uid'] as String?;
        if (memberUid == null || memberUid == _uid) continue;
        final ref = _db.collection('notifications').doc();
        batch.set(ref, {
          'type': 'task_assigned',
          'targetUid': memberUid,
          'title': title,
          'communityId': communityId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  // ── Admin: Duyuru gönder + tüm üyelere Firestore bildirimi yaz ───────────
  Future<void> sendAnnouncement({
    required String communityId,
    required String message,
    bool isWarning = false,
  }) async {
    await _db
        .collection('communities')
        .doc(communityId)
        .collection('announcements')
        .add({
      'message': message,
      'isWarning': isWarning,
      'sentBy': _uid,
      'sentAt': FieldValue.serverTimestamp(),
    });

    // Her üyeye bildirim yaz (adminın kendisi hariç)
    try {
      final members = await _db
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .get();
      final batch = _db.batch();
      for (final doc in members.docs) {
        final memberUid = doc.data()['uid'] as String?;
        if (memberUid == null || memberUid == _uid) continue;
        final ref = _db.collection('notifications').doc();
        batch.set(ref, {
          'type': isWarning ? 'announcement_warning' : 'announcement',
          'targetUid': memberUid,
          'message': message,
          'communityId': communityId,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  // ── Admin: Üyeyi topluluktan at ───────────────────────────────────────────
  Future<void> kickMember(String communityId, String targetUid) async {
    final batch = _db.batch();
    batch.delete(
      _db
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(targetUid),
    );
    batch.update(
      _db.collection('communities').doc(communityId),
      {'memberCount': FieldValue.increment(-1)},
    );
    await batch.commit();
  }

  // ── Admin: Belirli bir üyeye kişisel bildirim gönder ─────────────────────
  Future<void> sendPersonalNotification({
    required String targetUid,
    required String message,
    String? senderName,
  }) async {
    await _db.collection('notifications').add({
      'type': 'personal_message',
      'targetUid': targetUid,
      'message': message,
      if (senderName != null) 'fromName': senderName,
      'createdAt': FieldValue.serverTimestamp(),
      'read': false,
    });
  }

  // ── Kullanıcının üye olduğu topluluk ID'sini döndür ──────────────────────
  Future<String?> getUserCommunityId() async {
    if (_uid == null) return null;
    try {
      final snap = await _db
          .collectionGroup('members')
          .where('uid', isEqualTo: _uid)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return snap.docs.first.reference.parent.parent?.id;
    } catch (_) {
      return null;
    }
  }

  // ── Kullanıcının üye olduğu tüm topluluk ID'lerini döndür ────────────────
  Future<List<String>> getUserCommunityIds() async {
    if (_uid == null) return [];
    try {
      final snap = await _db
          .collectionGroup('members')
          .where('uid', isEqualTo: _uid)
          .get();
      return snap.docs
          .map((d) => d.reference.parent.parent?.id)
          .whereType<String>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Kullanıcının üye olduğu topluluk ID→İsim haritasını döndür ───────────
  Future<Map<String, String>> getUserCommunityIdNameMap() async {
    if (_uid == null) return {};
    try {
      final snap = await _db
          .collectionGroup('members')
          .where('uid', isEqualTo: _uid)
          .get();
      final ids = snap.docs
          .map((d) => d.reference.parent.parent?.id)
          .whereType<String>()
          .toList();
      final map = <String, String>{};
      for (final id in ids) {
        try {
          final doc = await _db.collection('communities').doc(id).get();
          map[id] = doc.data()?['name'] as String? ?? 'Topluluk';
        } catch (_) {
          map[id] = 'Topluluk';
        }
      }
      return map;
    } catch (_) {
      return {};
    }
  }

  // ── Topluluk mesajı gönder ────────────────────────────────────────────────
  Future<void> sendMessage({
    required String communityId,
    required String text,
    required String senderName,
  }) async {
    await _db
        .collection('communities')
        .doc(communityId)
        .collection('messages')
        .add({
      'text': text,
      'senderUid': _uid,
      'senderName': senderName,
      'sentAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Kullanıcının topluluklarını getir ─────────────────────────────────────
  // collectionGroup index Firebase Console'da oluşturulmamışsa PERMISSION_DENIED verir.
  Stream<QuerySnapshot> getUserCommunities() {
    return _db
        .collectionGroup('members')
        .where('uid', isEqualTo: _uid)
        .snapshots()
        .handleError((_) {});
  }

  // ── Admin'in yönettiği topluluğu getir ───────────────────────────────────
  Stream<QuerySnapshot> getAdminCommunities() {
    return _db
        .collection('communities')
        .where('adminUid', isEqualTo: _uid)
        .snapshots();
  }

  // ── Bekleyen admin başvuruları (Sahip için) ───────────────────────────────
  Stream<QuerySnapshot> getPendingAdminRequests() {
    return _db
        .collection('adminRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('appliedAt', descending: true)
        .snapshots();
  }

  // ── Admin: Davet kodunu yenile ───────────────────────────────────────────────
  // Eski kodu inviteLookup'tan siler, yeni kod üretir, private/config ve inviteLookup günceller.
  Future<String> regenerateInviteCode(String communityId) async {
    if (_uid == null) throw Exception('Giriş yapılmamış');

    final configRef = _db
        .collection('communities')
        .doc(communityId)
        .collection('private')
        .doc('config');

    final configDoc = await configRef.get();
    final oldCode = configDoc.data()?['inviteCode'] as String?;

    final newCode = _generateCode();
    final batch = _db.batch();

    if (oldCode != null && oldCode.isNotEmpty) {
      batch.delete(_db.collection('inviteLookup').doc(oldCode));
    }

    batch.set(configRef, {
      'inviteCode': newCode,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.set(_db.collection('inviteLookup').doc(newCode), {
      'communityId': communityId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return newCode;
  }

  // ── Tek seferlik migration: eski inviteCode yapısını yeni yapıya taşı ──────
  // Owner yetkisi gerekir. İdempotent — zaten migrate edilmiş toplulukları atlar.
  // Dönen kayıt: (migrated, skipped, errors)
  Future<({int migrated, int skipped, List<String> errors})>
      migrateInviteCodes() async {
    int migrated = 0;
    int skipped = 0;
    final errors = <String>[];

    final communities = await _db.collection('communities').get();

    for (final doc in communities.docs) {
      final oldCode = doc.data()['inviteCode'] as String?;
      if (oldCode == null) {
        skipped++;
        continue;
      }

      try {
        final batch = _db.batch();

        batch.set(
          doc.reference.collection('private').doc('config'),
          {'inviteCode': oldCode, 'migratedAt': FieldValue.serverTimestamp()},
        );

        batch.set(
          _db.collection('inviteLookup').doc(oldCode),
          {'communityId': doc.id, 'migratedAt': FieldValue.serverTimestamp()},
        );

        // Eski alanı topluluk belgesinden sil
        batch.update(doc.reference, {'inviteCode': FieldValue.delete()});

        await batch.commit();
        debugPrint('[Migration] OK: ${doc.id} → $oldCode');
        migrated++;
      } catch (e) {
        debugPrint('[Migration] HATA: ${doc.id} → $e');
        errors.add(doc.id);
      }
    }

    debugPrint(
        '[Migration] Bitti — migrate: $migrated, atlandı: $skipped, hata: ${errors.length}');
    return (migrated: migrated, skipped: skipped, errors: errors);
  }

  // ── Admin: Topluluğu tamamen sil ─────────────────────────────────────────
  Future<void> deleteCommunity(String communityId) async {
    if (_uid == null) return;

    final communityDoc =
        await _db.collection('communities').doc(communityId).get();
    final adminUid = communityDoc.data()?['adminUid'] as String?;
    if (adminUid != _uid) throw Exception('Bu topluluğu silme yetkiniz yok');

    // inviteLookup kaydını sil
    try {
      final configDoc = await _db
          .collection('communities')
          .doc(communityId)
          .collection('private')
          .doc('config')
          .get();
      final inviteCode = configDoc.data()?['inviteCode'] as String?;
      if (inviteCode != null) {
        await _db.collection('inviteLookup').doc(inviteCode).delete();
      }
    } catch (_) {}

    // Alt koleksiyonları toplu sil
    for (final sub in ['tasks', 'members', 'messages', 'announcements', 'private']) {
      final snap = await _db
          .collection('communities')
          .doc(communityId)
          .collection(sub)
          .get();
      const batchLimit = 490;
      for (var i = 0; i < snap.docs.length; i += batchLimit) {
        final batch = _db.batch();
        final end =
            (i + batchLimit < snap.docs.length) ? i + batchLimit : snap.docs.length;
        for (final doc in snap.docs.sublist(i, end)) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    }

    // Topluluk belgesini sil
    await _db.collection('communities').doc(communityId).delete();
  }

  // ── Yardımcı: Davet kodu üret ─────────────────────────────────────────────
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }
}
