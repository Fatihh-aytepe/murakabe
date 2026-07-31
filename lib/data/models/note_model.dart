import 'dart:convert';

class NoteModel {
  final String id;
  final String title;
  final String
      content; // Düz metin — liste önizlemesi, arama ve eski notlarla uyumluluk için
  final String
      contentDelta; // Quill Delta JSON (zengin biçimlendirilmiş içerik). Boşsa eski/düz-metin not demektir.
  final List<String> tags; // Örn: ['ayet', 'tefsir', 'ders']
  final String
      color; // Kart rengi için önceden tanımlı anahtar (bkz. NoteColors). Boşsa varsayılan.
  final bool isPinned;
  final List<String>
      imagePaths; // Cihazda kalıcı olarak kopyalanmış resim dosya yolları
  final List<String>
      audioPaths; // Cihazda kalıcı olarak kaydedilmiş ses notu dosya yolları
  final DateTime? reminderAt; // Ayarlıysa bu tarihte bildirim planlanır
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteModel({
    required this.id,
    required this.title,
    required this.content,
    this.contentDelta = '',
    this.tags = const [],
    this.color = '',
    this.isPinned = false,
    this.imagePaths = const [],
    this.audioPaths = const [],
    this.reminderAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    List<String> parsedTags = const [];
    final rawTags = map['tags'];
    if (rawTags is String && rawTags.isNotEmpty) {
      try {
        parsedTags = List<String>.from(jsonDecode(rawTags) as List);
      } catch (_) {}
    }
    List<String> parseStringList(dynamic raw) {
      if (raw is String && raw.isNotEmpty) {
        try {
          return List<String>.from(jsonDecode(raw) as List);
        } catch (_) {}
      }
      return const [];
    }

    final rawReminder = map['reminderAt'] as String?;
    return NoteModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      contentDelta: map['contentDelta'] ?? '',
      tags: parsedTags,
      color: map['color'] ?? '',
      isPinned: (map['isPinned'] ?? 0) == 1,
      imagePaths: parseStringList(map['imagePaths']),
      audioPaths: parseStringList(map['audioPaths']),
      reminderAt: (rawReminder != null && rawReminder.isNotEmpty)
          ? DateTime.tryParse(rawReminder)
          : null,
      createdAt:
          DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      updatedAt:
          DateTime.parse(map['updatedAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'contentDelta': contentDelta,
        'tags': jsonEncode(tags),
        'color': color,
        'isPinned': isPinned ? 1 : 0,
        'imagePaths': jsonEncode(imagePaths),
        'audioPaths': jsonEncode(audioPaths),
        'reminderAt': reminderAt?.toIso8601String() ?? '',
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  NoteModel copyWith({
    String? title,
    String? content,
    String? contentDelta,
    List<String>? tags,
    String? color,
    bool? isPinned,
    List<String>? imagePaths,
    List<String>? audioPaths,
    DateTime? reminderAt,
    bool clearReminder = false,
  }) {
    return NoteModel(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      contentDelta: contentDelta ?? this.contentDelta,
      tags: tags ?? this.tags,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      imagePaths: imagePaths ?? this.imagePaths,
      audioPaths: audioPaths ?? this.audioPaths,
      reminderAt: clearReminder ? null : (reminderAt ?? this.reminderAt),
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Not kartları için önceden tanımlı renk paleti.
/// Anahtar NoteModel.color alanında saklanır, değer UI'da kullanılır.
class NoteColors {
  static const Map<String, int> palette = {
    'emerald': 0xFF1F5D4C, // Zümrüt yeşili
    'navy': 0xFF1B3A4B, // Lacivert
    'cream': 0xFFEFE6D8, // Krem
    'wood': 0xFF6B4226, // Ahşap tonu
    'gold': 0xFFC9A227, // Altın sarısı
    'plum': 0xFF4A2545, // Mor/patlıcan
  };

  static int? colorFor(String key) => palette[key];
}
