class CustomTaskModel {
  final String id;
  final String title;
  final String description;
  final String emoji;
  final bool isActive;
  final String notificationTime;
  final DateTime createdAt;
  bool completedToday;

  CustomTaskModel({
    required this.id,
    required this.title,
    this.description = '',
    this.emoji = '📝',
    this.isActive = true,
    this.notificationTime = '',
    required this.createdAt,
    this.completedToday = false,
  });

  factory CustomTaskModel.fromMap(Map<String, dynamic> map) {
    return CustomTaskModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      emoji: map['emoji'] ?? '📝',
      isActive: (map['isActive'] ?? 1) == 1,
      notificationTime: map['notificationTime'] ?? '',
      createdAt: DateTime.parse(
          map['createdAt'] ?? DateTime.now().toIso8601String()),
      completedToday: (map['completedToday'] ?? 0) == 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'emoji': emoji,
        'isActive': isActive ? 1 : 0,
        'notificationTime': notificationTime,
        'createdAt': createdAt.toIso8601String(),
      };

  CustomTaskModel copyWith({
    String? title,
    String? description,
    String? emoji,
    bool? isActive,
    String? notificationTime,
    bool? completedToday,
  }) {
    return CustomTaskModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      emoji: emoji ?? this.emoji,
      isActive: isActive ?? this.isActive,
      notificationTime: notificationTime ?? this.notificationTime,
      createdAt: createdAt,
      completedToday: completedToday ?? this.completedToday,
    );
  }
}
