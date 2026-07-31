import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../local/local_storage.dart';
import '../local/note_file_storage.dart';
import '../models/note_model.dart';
import '../remote/firebase_service.dart';
import '../../core/services/notification_service.dart';

class NoteRepository {
  final _db = DatabaseHelper();
  final _firebase = FirebaseService();
  final _storage = LocalStorage();

  String? get _uid => _storage.userId;

  // Not hatırlatıcıları için ayrılmış bildirim ID aralığı: 30000–49999.
  // Mevcut bildirim ID'leriyle (bkz. NotificationService) çakışmaz.
  int _reminderNotifId(String noteId) =>
      30000 + (noteId.hashCode.abs() % 20000);

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
    // Silinen notun eklerini (resim/ses) ve hatırlatıcısını da temizle
    final rows = await _db.query('notes', where: 'id = ?', whereArgs: [noteId]);
    if (rows.isNotEmpty) {
      final note = NoteModel.fromMap(rows.first);
      for (final path in [...note.imagePaths, ...note.audioPaths]) {
        await NoteFileStorage.deleteIfExists(path);
      }
      await NotificationService()
          .cancelTaskNotification(_reminderNotifId(noteId));
    }
    await _db.delete('notes', where: 'id = ?', whereArgs: [noteId]);
    if (_uid != null) {
      try {
        await _firebase.deleteNote(_uid!, noteId);
      } catch (_) {}
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
        reminderAt: reminderAt,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );
}
