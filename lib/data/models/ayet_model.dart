class AyetModel {
  final int id;
  final String arabic;
  final String turkish;
  final String surah;
  final int ayahNumber;

  AyetModel({
    required this.id,
    required this.arabic,
    required this.turkish,
    required this.surah,
    required this.ayahNumber,
  });

  factory AyetModel.fromMap(Map<String, dynamic> map) {
    return AyetModel(
      id: map['id'] ?? 0,
      arabic: map['arabic'] ?? '',
      turkish: map['turkish'] ?? '',
      surah: map['surah'] ?? '',
      ayahNumber: map['ayahNumber'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'arabic': arabic,
        'turkish': turkish,
        'surah': surah,
        'ayahNumber': ayahNumber,
      };
}
