class RewardModel {
  final String id;
  final String type; // 'tahajjud', 'streak', 'quran'
  final String title;
  final String message;
  final DateTime earnedAt;

  RewardModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.earnedAt,
  });

  factory RewardModel.fromMap(Map<String, dynamic> map) => RewardModel(
        id: map['id'] ?? '',
        type: map['type'] ?? '',
        title: map['title'] ?? '',
        message: map['message'] ?? '',
        earnedAt:
            DateTime.parse(map['earnedAt'] ?? DateTime.now().toIso8601String()),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'title': title,
        'message': message,
        'earnedAt': earnedAt.toIso8601String(),
      };
}
