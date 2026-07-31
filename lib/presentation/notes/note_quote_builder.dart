import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Ayet/Hadis/Esma gibi dini içerikleri, Notlar ekranındaki zengin metin
/// editöründe "alıntı kutusu" (blockquote) olarak görünecek bir Quill
/// dokümanına çevirir. Arapça metin (varsa) + meal/anlam + kaynak satırı
/// blockquote içine yazılır, altına kullanıcının kendi notunu ekleyebileceği
/// boş bir paragraf bırakılır ve imleç oraya konumlanır.
quill.Document buildQuoteDocument({
  String? arabic,
  required String meal,
  required String source,
}) {
  final ops = <Map<String, dynamic>>[];

  if (arabic != null && arabic.isNotEmpty) {
    ops.add({'insert': arabic});
    ops.add({
      'insert': '\n',
      'attributes': {'blockquote': true},
    });
  }

  ops.add({'insert': meal});
  ops.add({
    'insert': '\n',
    'attributes': {'blockquote': true},
  });

  ops.add({
    'insert': '— $source',
    'attributes': {'italic': true},
  });
  ops.add({
    'insert': '\n',
    'attributes': {'blockquote': true},
  });

  // Kullanıcının kendi düşüncesini yazacağı boş satır
  ops.add({'insert': '\n'});

  return quill.Document.fromJson(ops);
}
