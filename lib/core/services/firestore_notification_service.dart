import 'dart:async' show StreamSubscription, unawaited;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'notification_service.dart';
import '../../data/local/local_storage.dart';

class FirestoreNotificationService {
  static final FirestoreNotificationService _instance =
      FirestoreNotificationService._();
  factory FirestoreNotificationService() => _instance;
  FirestoreNotificationService._();

  StreamSubscription<QuerySnapshot>? _sub;
  final Map<String, StreamSubscription<QuerySnapshot>> _chatSubs = {};
  final Set<String> _chatInitialized = {};

  // 300–399: genel topluluk bildirimleri; 200–299: sohbet mesaj bildirimleri
  int _idCounter = 300;
  int _chatIdCounter = 200;

  // HomeScreen bottom nav badge'ini yöneten notifier
  final ValueNotifier<bool> communityBadgeNotifier = ValueNotifier(false);

  // ── Genel Firestore bildirim dinleyicisi ──────────────────────────────────
  void start() {
    final uid = LocalStorage().userId;
    if (uid == null) return;
    _sub?.cancel();
    _sub = FirebaseFirestore.instance
        .collection('notifications')
        .where('targetUid', isEqualTo: uid)
        .limit(20)
        .snapshots()
        .listen(_handle, onError: (_) {});

    unawaited(checkAndScheduleTaskReminders());
  }

  // ── Topluluk sohbet dinleyicileri ─────────────────────────────────────────
  // communityIdNameMap: {communityId: communityName}
  void startChatListeners(Map<String, String> communityIdNameMap) {
    final uid = LocalStorage().userId;
    if (uid == null) return;

    // Artık üye olunmayan toplulukların dinleyicilerini iptal et
    for (final key in _chatSubs.keys
        .where((k) => !communityIdNameMap.containsKey(k))
        .toList()) {
      _chatSubs[key]?.cancel();
      _chatSubs.remove(key);
      _chatInitialized.remove(key);
    }

    // Mevcut okunmamış bayraklarından badge başlangıç durumunu ayarla
    for (final id in communityIdNameMap.keys) {
      if (LocalStorage().hasChatUnread(id)) {
        communityBadgeNotifier.value = true;
      }
    }

    // Yeni topluluklar için dinleyici başlat
    for (final entry in communityIdNameMap.entries) {
      if (_chatSubs.containsKey(entry.key)) continue;
      _chatSubs[entry.key] = FirebaseFirestore.instance
          .collection('communities')
          .doc(entry.key)
          .collection('messages')
          .orderBy('sentAt')
          .limitToLast(1)
          .snapshots()
          .listen(
            (snap) => _handleChatMessage(entry.key, entry.value, snap),
            onError: (_) {},
          );
    }
  }

  Future<void> _handleChatMessage(
    String communityId,
    String communityName,
    QuerySnapshot snap,
  ) async {
    final uid = LocalStorage().userId;
    if (uid == null) return;

    // İlk snapshot başlatma snapshotudur — badge kontrolü yap, push atma
    final isInit = !_chatInitialized.contains(communityId);
    if (isInit) _chatInitialized.add(communityId);

    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final data = change.doc.data() as Map<String, dynamic>? ?? {};
      final senderUid = data['senderUid'] as String?;
      if (senderUid == uid) continue; // kendi mesajı, atla

      if (isInit) {
        // Başlangıç kontrolü: mesaj son okuma zamanından yeniyse badge göster
        final msgMs =
            (data['sentAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final readMs = LocalStorage().getChatReadTime(communityId);
        if (msgMs > readMs) {
          communityBadgeNotifier.value = true;
          if (!LocalStorage().hasChatUnread(communityId)) {
            await LocalStorage().setChatUnread(communityId, true);
          }
        }
        continue;
      }

      // Gerçek zamanlı yeni mesaj — badge güncelle
      communityBadgeNotifier.value = true;

      // Bu toplulukta okunmamış mesaj yoksa → ilk okunmamış → push bildirim gönder
      if (!LocalStorage().hasChatUnread(communityId)) {
        await LocalStorage().setChatUnread(communityId, true);
        final senderName = data['senderName'] as String? ?? 'Birisi';
        final text = data['text'] as String? ?? '...';
        final notifId = _chatIdCounter++;
        if (_chatIdCounter > 299) _chatIdCounter = 200;

        await NotificationService().showImmediateNotification(
          id: notifId,
          title: communityName,
          body: '$senderName: $text',
          channelId: 'community_channel',
          channelName: 'Topluluk Bildirimleri',
        );
      }
      // Zaten okunmamış varsa bildirim tekrarlanmaz (spam önleme)
    }
  }

  // CommunityScreen açıldığında çağrılır — okunmamış bayrağını sıfırlar
  Future<void> markChatRead(String communityId) async {
    await LocalStorage().setChatUnread(communityId, false);
    await LocalStorage().setChatReadTime(communityId);
  }

  // Kullanıcı Topluluk sekmesine geçtiğinde badge sıfırlanır
  void clearCommunityBadge() {
    communityBadgeNotifier.value = false;
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    for (final sub in _chatSubs.values) {
      sub.cancel();
    }
    _chatSubs.clear();
    _chatInitialized.clear();
  }

  // ── Görev hatırlatma planlaması ───────────────────────────────────────────
  Future<void> checkAndScheduleTaskReminders() async {
    final uid = LocalStorage().userId;
    if (uid == null) return;
    try {
      final memberSnap = await FirebaseFirestore.instance
          .collectionGroup('members')
          .where('uid', isEqualTo: uid)
          .get();

      bool hasPending = false;
      for (final memberDoc in memberSnap.docs) {
        final communityId = memberDoc.reference.parent.parent?.id;
        if (communityId == null) continue;
        final tasksSnap = await FirebaseFirestore.instance
            .collection('communities')
            .doc(communityId)
            .collection('tasks')
            .get();
        for (final taskDoc in tasksSnap.docs) {
          final completions =
              taskDoc.data()['completions'] as Map? ?? {};
          if (!completions.containsKey(uid)) {
            hasPending = true;
            break;
          }
        }
        if (hasPending) break;
      }

      if (hasPending) {
        await NotificationService().schedulePendingTaskReminders();
      } else {
        await NotificationService().cancelPendingTaskReminders();
      }
    } catch (_) {}
  }

  // ── Firestore bildirim işleyici ───────────────────────────────────────────
  Future<void> _handle(QuerySnapshot snapshot) async {
    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      final data = change.doc.data() as Map<String, dynamic>? ?? {};
      if (data['read'] == true) continue;
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
          body =
              '$who admin olmak için başvurdu. Topluluk panelinizden inceleyebilirsiniz.';
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
        case 'task_assigned':
          final taskTitle = data['title'] as String? ?? 'Yeni Görev';
          title = 'Yeni Görev Atandı';
          body = taskTitle;
          break;
        default:
          continue;
      }

      // Yeni bildirim geldi → badge'i aktif et
      communityBadgeNotifier.value = true;

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
