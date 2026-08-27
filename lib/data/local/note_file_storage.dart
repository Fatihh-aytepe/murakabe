import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// image_picker ve record paketleri geçici (cache) dizinlere dosya yazar —
/// uygulama yeniden başlatıldığında bu dosyalar silinebilir. Bu sınıf,
/// seçilen/kaydedilen dosyayı uygulamanın kalıcı belgeler dizinine kopyalar
/// ve oradaki yeni yolu döner. Notlar bu kalıcı yolu saklar.
class NoteFileStorage {
  static const _imagesDir = 'note_images';
  static const _audioDir = 'note_audio';

  static Future<Directory> _ensureDir(String subDir) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, subDir));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Seçilen bir resmi kalıcı dizine kopyalar, yeni dosya yolunu döner.
  static Future<String> persistImage(String sourcePath) async {
    final dir = await _ensureDir(_imagesDir);
    final ext =
        p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final newPath = p.join(dir.path, '${const Uuid().v4()}$ext');
    await File(sourcePath).copy(newPath);
    return newPath;
  }

  /// Kaydedilmiş bir ses dosyasını kalıcı dizine kopyalar, yeni yolu döner.
  static Future<String> persistAudio(String sourcePath) async {
    final dir = await _ensureDir(_audioDir);
    final ext =
        p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.m4a';
    final newPath = p.join(dir.path, '${const Uuid().v4()}$ext');
    await File(sourcePath).copy(newPath);
    return newPath;
  }

  /// Ses kaydının doğrudan kalıcı dizine yazılması için hedef bir yol üretir
  /// (record paketi kayda başlarken bir hedef path ister).
  static Future<String> newAudioTargetPath() async {
    final dir = await _ensureDir(_audioDir);
    return p.join(dir.path, '${const Uuid().v4()}.m4a');
  }

  static Future<void> deleteIfExists(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// Hesap silinirken çağrılır: yerel `note_images/` ve `note_audio/`
  /// dizinlerinin TAMAMINI kaldırır. DÜZELTME: `UserRepository.
  /// deleteAccountPermanently` önceden yalnızca SQLite satırlarını
  /// (`wipeAllTables`) siliyordu — notlara eklenen resim/ses dosyaları
  /// (bu sınıfın `persistImage`/`persistAudio`/`newAudioTargetPath` ile
  /// kopyaladığı gerçek dosyalar) diskte öksüz olarak kalıcı biçimde
  /// birikmeye devam ediyordu. Firebase Storage'daki bulut kopyaları zaten
  /// `FirebaseService._deleteStorageFolder('notes/\$uid')` ile siliniyor;
  /// bu metod yalnızca CİHAZDAKİ kopyaları temizler. Best-effort — hata
  /// hesap silme akışını engellemez.
  static Future<void> deleteAllLocalFiles() async {
    try {
      final base = await getApplicationDocumentsDirectory();
      for (final subDir in [_imagesDir, _audioDir]) {
        final dir = Directory(p.join(base.path, subDir));
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      }
    } catch (_) {}
  }

  // ── Firebase Storage yedekleme ──────────────────────────────────────────
  // Notlara eklenen resim/ses dosyaları sadece cihazda tutulduğu için
  // uygulama silinip yeniden yüklendiğinde kaybolur. Bu metodlar dosyayı
  // Storage'a yükler / oradan geri indirir, böylece Firestore'daki not
  // metniyle birlikte ekler de geri gelir.

  static Reference _ref(
          String uid, String noteId, String subDir, String fileName) =>
      FirebaseStorage.instance.ref('notes/$uid/$noteId/$subDir/$fileName');

  /// Yerel dosyayı Storage'a yükler ve indirme URL'ini döner.
  /// Ağ/izin hatalarında null döner — yükleme başarısızsa not yine de
  /// yerelde kalmaya devam eder, bir sonraki kayışta tekrar denenir.
  static Future<String?> uploadToStorage({
    required String uid,
    required String noteId,
    required String localPath,
    required bool isImage,
  }) async {
    try {
      final file = File(localPath);
      if (!await file.exists()) return null;
      final subDir = isImage ? _imagesDir : _audioDir;
      final ref = _ref(uid, noteId, subDir, p.basename(localPath));
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  static Future<void> deleteFromStorage({
    required String uid,
    required String noteId,
    required String fileName,
    required bool isImage,
  }) async {
    try {
      final subDir = isImage ? _imagesDir : _audioDir;
      await _ref(uid, noteId, subDir, fileName).delete();
    } catch (_) {}
  }

  /// Tüm notun Storage klasörünü (resim + ses) siler.
  static Future<void> deleteNoteFolder(String uid, String noteId) async {
    for (final subDir in [_imagesDir, _audioDir]) {
      try {
        final dirRef =
            FirebaseStorage.instance.ref('notes/$uid/$noteId/$subDir');
        final list = await dirRef.listAll();
        for (final item in list.items) {
          try {
            await item.delete();
          } catch (_) {}
        }
      } catch (_) {}
    }
  }

  /// Storage URL'inden dosyayı indirip kalıcı yerel dizine kaydeder,
  /// yeni yerel path'i döner. İndirme başarısızsa null döner.
  static Future<String?> downloadFromUrl({
    required String url,
    required bool isImage,
  }) async {
    try {
      final dir = await _ensureDir(isImage ? _imagesDir : _audioDir);
      final ref = FirebaseStorage.instance.refFromURL(url);
      final fileName = p.basename(ref.fullPath);
      final targetPath = p.join(dir.path, fileName);
      final file = File(targetPath);
      if (await file.exists()) return targetPath; // zaten indirilmiş
      await ref.writeToFile(file);
      return targetPath;
    } catch (_) {
      return null;
    }
  }
}
