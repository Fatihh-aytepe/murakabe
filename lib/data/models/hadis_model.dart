class HadisModel {
  final int id;
  final String text;
  final String source;
  final String arabic;

  HadisModel({
    required this.id,
    required this.text,
    required this.source,
    this.arabic = '',
  });

  factory HadisModel.fromMap(Map<String, dynamic> map) {
    return HadisModel(
      id: map['id'] ?? 0,
      text: map['text'] ?? '',
      source: map['source'] ?? '',
      arabic: map['arabic'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'source': source,
        'arabic': arabic,
      };
}
