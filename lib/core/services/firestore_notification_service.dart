import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import '../../data/local/local_storage.dart';

class FirestoreNotificationService {
  static final FirestoreNotificationService _instance =
      FirestoreNotificationService._();
  factory FirestoreNotificationService() => _instance;
  FirestoreNotificationService._();

  StreamSubscription<QuerySnapshot>? _sub;
  // 300–399 arası ID aralığı topluluk bildirimlerine ayrılmış
  int _idCounter = 300;

  void start() {
    final uid = LocalStorage().userId;
    if (uid == null) return;
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('notifications')
        .where('targetUid', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .limit(20)
        .snapshots()
        .listen(_handle);
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  Future<void> _handle(QuerySnapshot snapshot) async {
    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final data = change.doc.data() as Map<String, dynamic>? ?? {};
      final type = data['type'] as String? ?? '';

      String title;
      String body;

      switch (type) {
        case 'admin_approved':
          title = 'Admin Başvurunuz Onaylandı';
          body = 'Tebrikler! Artık topluluk yöneticisisiniz. '
              'Topluluk sekmesinden panelinize ulaşabilirsiniz.';
          break;
        case 'admin_rejected':
          title = 'Admin Başvurunuz Reddedildi';
          body = 'Başvurunuz bu sefer kabul edilmedi. '
              'Daha sonra tekrar başvurabilirsiniz.';
          break;
        case 'community_joined':
          final who = data['fromName'] as String? ?? 'Bir kullanıcı';
          final community =
              data['communityName'] as String? ?? 'topluluğunuza';
          title = 'Yeni Üye';
          body = '$who, $community katıldı.';
          break;
        case 'admin_request':
          final who = data['fromName'] as String? ?? 'Bir kullanıcı';
          title = 'Yeni Admin Başvurusu';
          body = '$who admin olmak için başvurdu. Topluluk panelinizden inceleyebilirsiniz.';
          break;
        case 'announcement':
          title = 'Topluluk Duyurusu';
          body = data['message'] as String? ?? '';
          break;
        case 'announcement_warning':
          title = 'Topluluk Uyarısı';
          body = data['message'] as String? ?? '';
          break;
        case 'personal_message':
          final from = data['fromName'] as String? ?? 'Admin';
          title = '$from size bir mesaj gönderdi';
          body = data['message'] as String? ?? '';
          break;
        default:
          continue;
      }

      final notifId = _idCounter++;
      if (_idCounter > 399) _idCounter = 300;

      await NotificationService().showImmediateNotification(
        id: notifId,
        title: title,
        body: body,
        channelId: 'community_channel',
        channelName: 'Topluluk Bildirimleri',
      );

      try {
        await change.doc.reference.update({'read': true});
      } catch (_) {}
    }
  }
}
