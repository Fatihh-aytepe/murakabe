class EsmaModel {
  final int id;
  final String arabic;
  final String turkish;
  final String meaning;
  final String dua;

  EsmaModel({
    required this.id,
    required this.arabic,
    required this.turkish,
    required this.meaning,
    required this.dua,
  });

  factory EsmaModel.fromMap(Map<String, dynamic> map) {
    return EsmaModel(
      id: map['id'] ?? 0,
      arabic: map['arabic'] ?? '',
      turkish: map['turkish'] ?? '',
      meaning: map['meaning'] ?? '',
      dua: map['dua'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'arabic': arabic,
        'turkish': turkish,
        'meaning': meaning,
        'dua': dua,
      };
}
