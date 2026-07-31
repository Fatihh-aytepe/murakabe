import 'dart:io';
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
}
