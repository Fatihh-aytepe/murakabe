import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../local/local_storage.dart';
import '../models/note_model.dart';
import '../remote/firebase_service.dart';

class NoteRepository {
  final _db = DatabaseHelper();
  final _firebase = FirebaseService();
  final _storage = LocalStorage();

  String? get _uid => _storage.userId;

  Future<List<NoteModel>> getNotes() async {
    final rows = await _db.query('notes', orderBy: 'updatedAt DESC');
    return rows.map((r) => NoteModel.fromMap(r)).toList();
  }

  Future<NoteModel> addNote({
    required String title,
    required String content,
  }) async {
    final now = DateTime.now();
    final note = NoteModel(
      id: const Uuid().v4(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    await _db.insert('notes', note.toMap());
    if (_uid != null) {
      try {
        await _firebase.saveNote(_uid!, note.toMap());
      } catch (_) {}
    }
    return note;
  }

  Future<void> updateNote(NoteModel note) async {
    final updated = NoteModel(
      id: note.id,
      title: note.title,
      content: note.content,
      createdAt: note.createdAt,
      updatedAt: DateTime.now(),
    );
    await _db.update('notes', updated.toMap(),
        where: 'id = ?', whereArgs: [note.id]);
    if (_uid != null) {
      try {
        await _firebase.saveNote(_uid!, updated.toMap());
      } catch (_) {}
    }
  }

  Future<void> deleteNote(String noteId) async {
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
  }) async {
    return addNote(title: prefillTitle, content: content);
  }
}
