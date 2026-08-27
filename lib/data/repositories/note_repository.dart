import 'dart:async';
import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../local/local_storage.dart';
import '../local/note_file_storage.dart';
import '../models/note_model.dart';
import '../remote/firebase_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/utils/stable_hash.dart';

class NoteRepository {
  final _db = DatabaseHelper();
  final _firebase = FirebaseService();
  final _storage = LocalStorage();

  String? get _uid => _storage.userId;

  // Not hatırlatıcıları için ayrılmış bildirim ID aralığı: 30000–49999.
  // Mevcut bildirim ID'leriyle (bkz. NotificationService) çakışmaz.
  // DÜZELTME: önceden Dart'ın yerleşik String.hashCode'u kullanılıyordu —
  // bunun SDK sürümleri arasında sabit kalacağı garanti değildir (bkz.
  // stable_hash.dart'taki açıklama). stableStringHash SDK'dan bağımsız,
  // kendi uyguladığımız sabit bir algoritma kullanır.
  int _reminderNotifId(String noteId) =>
      30000 + (stableStringHash(noteId) % 20000);

  /// Bir not düzenlenirken çağrılmalı: [oldPaths]/[oldUrls] notun ÖNCEKİ
  /// (kaydedilmiş) resim/ses yol+URL listeleri, [newPaths] düzenleme
  /// ekranından çıkan güncel yerel dosya yolu listesidir. Hâlâ mevcut olan
  /// (silinmeyen) her yol için önceki Firebase Storage URL'si korunur; yeni
  /// eklenen bir yolun henüz URL'si olmadığından '' döner (bunu gören
  /// _syncAttachmentsToStorage dosyayı yükleyip URL'yi sonradan doldurur).
  ///
  /// Bu yapılmazsa (bkz. eski notes_screen.dart kodu): düzenleme ekranı yeni
  /// NoteModel'i sıfırdan kurarken imageUrls/audioUrls hiç aktarılmıyordu,
  /// yani HER düzenlemede önceki Storage yedek linkleri sıfırlanıyor,
  /// Firestore'a önce boş liste yazılıyor, arka plandaki yeniden yükleme
  /// başarısız olursa (ağ yoksa) o notun ekleri kalıcı olarak "yedeksiz"
  /// kalıyordu.
  static List<String> reconcileAttachmentUrls(
    List<String> oldPaths,
    List<String> oldUrls,
    List<String> newPaths,
  ) {
    final urlByPath = <String, String>{};
    for (var i = 0; i < oldPaths.length; i++) {
      if (i < oldUrls.length && oldUrls[i].isNotEmpty) {
        urlByPath[oldPaths[i]] = oldUrls[i];
      }
    }
    return newPaths.map((p) => urlByPath[p] ?? '').toList();
  }

  // Pinlenmiş notlar her zaman üstte, aynı grup içinde en son güncellenen önce.
  Future<List<NoteModel>> getNotes() async {
    final rows =
        await _db.query('notes', orderBy: 'isPinned DESC, updatedAt DESC');
    return rows.map((r) => NoteModel.fromMap(r)).toList();
  }

  Future<NoteModel> addNote({
    required String title,
    required String content,
    String contentDelta = '',
    List<String> tags = const [],
    String color = '',
    bool isPinned = false,
    List<String> imagePaths = const [],
    List<String> audioPaths = const [],
    DateTime? reminderAt,
  }) async {
    final now = DateTime.now();
    final note = NoteModel(
      id: const Uuid().v4(),
      title: title,
      content: content,
      contentDelta: contentDelta,
      tags: tags,
      color: color,
      isPinned: isPinned,
      imagePaths: imagePaths,
      audioPaths: audioPaths,
      reminderAt: reminderAt,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('notes', note.toMap());
    if (reminderAt != null) await _scheduleReminder(note);
    if (_uid != null) {
      try {
        await _firebase.saveNote(_uid!, note.toMap());
      } catch (_) {}
    }
    // Ekler varsa arka planda Storage'a yükle (yavaşlatmamak için beklenmeden).
    unawaited(_syncAttachmentsToStorage(note));
    return note;
  }

  Future<void> updateNote(NoteModel note) async {
    final updated = note._withUpdatedNow();
    await _db.update('notes', updated.toMap(),
        where: 'id = ?', whereArgs: [note.id]);
    if (updated.reminderAt != null) {
      await _scheduleReminder(updated);
    } else {
      await NotificationService()
          .cancelTaskNotification(_reminderNotifId(note.id));
    }
    if (_uid != null) {
      try {
        await _firebase.saveNote(_uid!, updated.toMap());
      } catch (_) {}
    }
    unawaited(_syncAttachmentsToStorage(updated));
  }

  /// Notun resim/ses eklerinden henüz Storage'a yüklenmemiş olanları
  /// (imageUrls/audioUrls listesinde karşılığı olmayanlar) yükler ve
  /// dönen URL'leri hem yerel DB'ye hem Firestore'a yazar.
  /// Ağ yoksa sessizce başarısız olur — bir sonraki kayıtta tekrar dener.
  Future<void> _syncAttachmentsToStorage(NoteModel note) async {
    if (_uid == null) return;
    try {
      final newImageUrls = List<String>.from(note.imageUrls);
      final newAudioUrls = List<String>.from(note.audioUrls);
      var changed = false;

      for (var i = 0; i < note.imagePaths.length; i++) {
        if (i < newImageUrls.length && newImageUrls[i].isNotEmpty) continue;
        final url = await NoteFileStorage.uploadToStorage(
          uid: _uid!,
          noteId: note.id,
          localPath: note.imagePaths[i],
          isImage: true,
        );
        if (url == null) continue;
        while (newImageUrls.length <= i) {
          newImageUrls.add('');
        }
        newImageUrls[i] = url;
        changed = true;
      }

      for (var i = 0; i < note.audioPaths.length; i++) {
        if (i < newAudioUrls.length && newAudioUrls[i].isNotEmpty) continue;
        final url = await NoteFileStorage.uploadToStorage(
          uid: _uid!,
          noteId: note.id,
          localPath: note.audioPaths[i],
          isImage: false,
        );
        if (url == null) continue;
        while (newAudioUrls.length <= i) {
          newAudioUrls.add('');
        }
        newAudioUrls[i] = url;
        changed = true;
      }

      if (!changed) return;
      final withUrls =
          note.copyWith(imageUrls: newImageUrls, audioUrls: newAudioUrls);
      await _db.update('notes', withUrls.toMap(),
          where: 'id = ?', whereArgs: [note.id]);
      await _firebase.saveNote(_uid!, withUrls.toMap());
    } catch (_) {}
  }

  Future<void> _scheduleReminder(NoteModel note) async {
    if (note.reminderAt == null) return;
    await NotificationService().scheduleCustomReminder(
      _reminderNotifId(note.id),
      note.title.isNotEmpty ? note.title : 'Not Hatırlatıcısı',
      note.content.isNotEmpty ? note.content : 'Notunu kontrol etmeyi unutma.',
      note.reminderAt!,
    );
  }

  Future<void> togglePin(NoteModel note) => updateNote(
        note.copyWith(isPinned: !note.isPinned),
      );

  Future<void> setColor(NoteModel note, String color) =>
      updateNote(note.copyWith(color: color));

  Future<void> setTags(NoteModel note, List<String> tags) =>
      updateNote(note.copyWith(tags: tags));

  Future<void> setReminder(NoteModel note, DateTime? time) => updateNote(
        note.copyWith(reminderAt: time, clearReminder: time == null),
      );

  Future<void> deleteNote(String noteId) async {
    // Notu silmeden önce, temizlik için eklerini/hatırlatıcı bilgisini
    // best-effort olarak okuyoruz — bu adım başarısız olsa bile asıl silme
    // işlemini ENGELLEMEMELİ.
    List<String> attachmentPaths = const [];
    try {
      final rows =
          await _db.query('notes', where: 'id = ?', whereArgs: [noteId]);
      if (rows.isNotEmpty) {
        final note = NoteModel.fromMap(rows.first);
        attachmentPaths = [...note.imagePaths, ...note.audioPaths];
      }
    } catch (_) {}

    // Asıl silme işlemi HER ZAMAN, yan etkilerden ÖNCE ve koşulsuz çalışır.
    // Eskiden bildirim iptali (cancelTaskNotification) try/catch olmadan bu
    // satırdan ÖNCE çalışıyordu — orada atılan herhangi bir hata (ör.
    // eklenti başlatılmamışsa) deleteNote'un tamamının hata fırlatıp
    // _db.delete'e hiç ulaşmamasına, yani notun aslında hiç silinmemesine
    // yol açıyordu. Bu, bildirilen "not silme çalışmıyor" hatasının
    // kök nedeniydi.
    await _db.delete('notes', where: 'id = ?', whereArgs: [noteId]);

    // Yan etkiler — hiçbiri asıl silmeyi etkilemesin diye best-effort.
    try {
      for (final path in attachmentPaths) {
        await NoteFileStorage.deleteIfExists(path);
      }
    } catch (_) {}
    try {
      await NotificationService()
          .cancelTaskNotification(_reminderNotifId(noteId));
    } catch (_) {}
    if (_uid != null) {
      try {
        await _firebase.deleteNote(_uid!, noteId);
      } catch (_) {}
      unawaited(NoteFileStorage.deleteNoteFolder(_uid!, noteId));
    }
  }

  Future<NoteModel> addNoteWithPrefill({
    required String prefillTitle,
    required String content,
    String contentDelta = '',
    List<String> tags = const [],
  }) async {
    return addNote(
      title: prefillTitle,
      content: content,
      contentDelta: contentDelta,
      tags: tags,
    );
  }
}

extension _TouchUpdatedAt on NoteModel {
  // updatedAt her zaman DateTime.now() olmalı; copyWith bunu değiştirmediği
  // için burada ayrı bir yeni NoteModel üretiyoruz.
  NoteModel _withUpdatedNow() => NoteModel(
        id: id,
        title: title,
        content: content,
        contentDelta: contentDelta,
        tags: tags,
        color: color,
        isPinned: isPinned,
        imagePaths: imagePaths,
        audioPaths: audioPaths,
        imageUrls: imageUrls,
        audioUrls: audioUrls,
        reminderAt: reminderAt,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
