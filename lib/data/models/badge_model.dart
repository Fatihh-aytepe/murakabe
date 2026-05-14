class BadgeModel {
  final String id;
  final String badgeId;
  final DateTime earnedAt;
  final bool isDisplayed;

  const BadgeModel({
    required this.id,
    required this.badgeId,
    required this.earnedAt,
    this.isDisplayed = false,
  });

  factory BadgeModel.fromMap(Map<String, dynamic> map) => BadgeModel(
        id: map['id'] ?? '',
        badgeId: map['badgeId'] ?? '',
        earnedAt:
            DateTime.parse(map['earnedAt'] ?? DateTime.now().toIso8601String()),
        isDisplayed: (map['isDisplayed'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'badgeId': badgeId,
        'earnedAt': earnedAt.toIso8601String(),
        'isDisplayed': isDisplayed ? 1 : 0,
      };
}
