import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserModel {
  final String id;
  final String nameSurname;
  final String phone;
  final String email;
  final DateTime createdAt;
  final int quranReadDays;
  final List<String> missedQuranDays;
  final bool tahajjudAlarmEnabled;
  final List<DateTime> tahajjudAlarmTimes;
  final int streakDays;
  final int mercyDaysUsed;
  final String lastStreakDate;

  // --- YENİ ALANLAR ---
  final String bio;
  final String gender; // 'erkek' | 'kadin' | ''
  final String photoUrl; // Firebase Storage URL (boş olabilir)
  final bool isEmailVerified;

  UserModel({
    required this.id,
    required this.nameSurname,
    required this.phone,
    required this.email,
    required this.createdAt,
    this.quranReadDays = 0,
    this.missedQuranDays = const [],
    this.tahajjudAlarmEnabled = false,
    this.tahajjudAlarmTimes = const [],
    this.streakDays = 0,
    this.mercyDaysUsed = 0,
    this.lastStreakDate = '',
    // YENİ
    this.bio = '',
    this.gender = '',
    this.photoUrl = '',
    this.isEmailVerified = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      nameSurname: map['nameSurname'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      quranReadDays: map['quranReadDays'] ?? 0,
      missedQuranDays: List<String>.from(map['missedQuranDays'] ?? []),
      tahajjudAlarmEnabled: map['tahajjudAlarmEnabled'] == true || map['tahajjudAlarmEnabled'] == 1,
      tahajjudAlarmTimes: (map['tahajjudAlarmTimes'] as List<dynamic>? ?? [])
          .map((e) => DateTime.parse(e.toString()))
          .toList(),
      streakDays: map['streakDays'] ?? 0,
      mercyDaysUsed: map['mercyDaysUsed'] ?? 0,
      lastStreakDate: map['lastStreakDate'] ?? '',
      // YENİ
      bio: map['bio'] ?? '',
      gender: map['gender'] ?? '',
      photoUrl: map['photoUrl'] ?? '',
      isEmailVerified: map['isEmailVerified'] == true || map['isEmailVerified'] == 1,
    );
  }

  // SQLite için (bool → int)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameSurname': nameSurname,
      'phone': phone,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'quranReadDays': quranReadDays,
      'missedQuranDays': missedQuranDays,
      'tahajjudAlarmEnabled': tahajjudAlarmEnabled ? 1 : 0,
      'tahajjudAlarmTimes':
          tahajjudAlarmTimes.map((e) => e.toIso8601String()).toList(),
      'streakDays': streakDays,
      'mercyDaysUsed': mercyDaysUsed,
      'lastStreakDate': lastStreakDate,
      'bio': bio,
      'gender': gender,
      'photoUrl': photoUrl,
      'isEmailVerified': isEmailVerified ? 1 : 0,
    };
  }

  // Firestore için (bool → bool, int olmadan)
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'nameSurname': nameSurname,
      'phone': phone,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'quranReadDays': quranReadDays,
      'missedQuranDays': missedQuranDays,
      'tahajjudAlarmEnabled': tahajjudAlarmEnabled,
      'tahajjudAlarmTimes':
          tahajjudAlarmTimes.map((e) => e.toIso8601String()).toList(),
      'streakDays': streakDays,
      'mercyDaysUsed': mercyDaysUsed,
      'lastStreakDate': lastStreakDate,
      'bio': bio,
      'gender': gender,
      'photoUrl': photoUrl,
      'isEmailVerified': isEmailVerified,
    };
  }

  UserModel copyWith({
    int? quranReadDays,
    List<String>? missedQuranDays,
    bool? tahajjudAlarmEnabled,
    List<DateTime>? tahajjudAlarmTimes,
    int? streakDays,
    int? mercyDaysUsed,
    String? lastStreakDate,
    // YENİ
    String? nameSurname,
    String? phone,
    String? bio,
    String? gender,
    String? photoUrl,
    bool? isEmailVerified,
  }) {
    return UserModel(
      id: id,
      nameSurname: nameSurname ?? this.nameSurname,
      phone: phone ?? this.phone,
      email: email,
      createdAt: createdAt,
      quranReadDays: quranReadDays ?? this.quranReadDays,
      missedQuranDays: missedQuranDays ?? this.missedQuranDays,
      tahajjudAlarmEnabled: tahajjudAlarmEnabled ?? this.tahajjudAlarmEnabled,
      tahajjudAlarmTimes: tahajjudAlarmTimes ?? this.tahajjudAlarmTimes,
      streakDays: streakDays ?? this.streakDays,
      mercyDaysUsed: mercyDaysUsed ?? this.mercyDaysUsed,
      lastStreakDate: lastStreakDate ?? this.lastStreakDate,
      // YENİ
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      photoUrl: photoUrl ?? this.photoUrl,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
    );
  }

  // Streak seviyesine göre kaç mercy day hakkı var
  int get allowedMercyDays {
    if (streakDays < 7) return 0;
    if (streakDays < 14) return 1;
    if (streakDays < 30) return 3;
    return 5;
  }

  // Streak rengi — seviyeye göre değişir
  static List<Color> getStreakColors(int streak) {
    if (streak >= 30) {
      return [const Color(0xFFFFD700), const Color(0xFFFFA500)];
    } else if (streak >= 14) {
      return [const Color(0xFF40B4C8), const Color(0xFF207080)];
    } else if (streak >= 7) {
      return [const Color(0xFF4CAF50), const Color(0xFF2E7D32)];
    }
    return [const Color(0xFF9E9E9E), const Color(0xFF616161)];
  }

  static String getStreakBadge(int streak) {
    if (streak >= 30) return '👑 Altın';
    if (streak >= 14) return '💎 Elmas';
    if (streak >= 7) return '🔥 Ateş';
    return '🌱 Başlangıç';
  }
}
