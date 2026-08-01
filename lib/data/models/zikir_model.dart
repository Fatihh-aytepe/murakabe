class ZikirModel {
  final int id;
  final String turkish;
  final String arabic;
  final String meaning;

  ZikirModel({
    required this.id,
    required this.turkish,
    this.arabic = '',
    this.meaning = '',
  });

  factory ZikirModel.fromMap(Map<String, dynamic> map) {
    return ZikirModel(
      id: map['id'] ?? 0,
      turkish: map['turkish'] ?? '',
      arabic: map['arabic'] ?? '',
      meaning: map['meaning'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'turkish': turkish,
        'arabic': arabic,
        'meaning': meaning,
      };
}
