import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/local/local_storage.dart';

// ─── Yetki seviyeleri ─────────────────────────────────────────────────────────
enum UserRole { owner, admin, user }

class RoleService {
  static final RoleService _instance = RoleService._();
  factory RoleService() => _instance;
  RoleService._();

  final _db = FirebaseFirestore.instance;
  final _storage = LocalStorage();

  String? get _uid => _storage.userId;

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
      await _db.collection('notifications').add({
        'type': 'admin_request',
        'fromUid': _uid,
        'fromName': name,
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

    final ref = await _db.collection('communities').add({
      'name': name,
      'description': description,
      'adminUid': _uid,
      'memberCount': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'inviteCode': _generateCode(),
    });

    // Admini üye olarak ekle
    await ref.collection('members').doc(_uid).set({
      'uid': _uid,
      'role': 'admin',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  // ── Admin: Üye davet linki oluştur ───────────────────────────────────────
  Future<String> getInviteCode(String communityId) async {
    final doc = await _db.collection('communities').doc(communityId).get();
    return doc.data()?['inviteCode'] ?? '';
  }

  // ── Kullanıcı: Davet koduyla topluluğa katıl ─────────────────────────────
  Future<void> joinCommunity(String inviteCode) async {
    if (_uid == null) return;

    final query = await _db
        .collection('communities')
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) throw Exception('Geçersiz davet kodu');

    final communityDoc = query.docs.first;
    final communityId = communityDoc.id;

    // Zaten üye mi?
    final memberDoc = await _db
        .collection('communities')
        .doc(communityId)
        .collection('members')
        .doc(_uid)
        .get();
    if (memberDoc.exists) throw Exception('Zaten bu topluluğun üyesiniz');

    final batch = _db.batch();

    // Üye olarak ekle
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
      },
    );

    // Üye sayısını artır
    batch.update(_db.collection('communities').doc(communityId), {
      'memberCount': FieldValue.increment(1),
    });

    await batch.commit();
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
  }

  // ── Admin: Duyuru gönder ──────────────────────────────────────────────────
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
  Stream<QuerySnapshot> getUserCommunities() {
    return _db
        .collectionGroup('members')
        .where('uid', isEqualTo: _uid)
        .snapshots();
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

  // ── Yardımcı: Davet kodu üret ─────────────────────────────────────────────
  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final buffer = StringBuffer();
    final now = DateTime.now().millisecondsSinceEpoch;
    for (int i = 0; i < 8; i++) {
      buffer.write(chars[(now + i * 7) % chars.length]);
    }
    return buffer.toString();
  }
}
