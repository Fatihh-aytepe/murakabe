import 'package:flutter/material.dart';

class BadgeDef {
  final String id;
  final String emoji;
  final String name;
  final String description;
  final Color primaryColor;
  final Color secondaryColor;
  final int tier; // 1=bronz, 2=gümüş, 3=altın, 4=efsane

  const BadgeDef({
    required this.id,
    required this.emoji,
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.secondaryColor,
    required this.tier,
  });

  String get tierLabel {
    switch (tier) {
      case 1:
        return 'Bronz';
      case 2:
        return 'Gümüş';
      case 3:
        return 'Altın';
      case 4:
        return 'Efsane';
      default:
        return '';
    }
  }

  List<Color> get gradient => [primaryColor, secondaryColor];
}

// ─── Kuran Serileri ───────────────────────────────────────────────────────────

const BadgeDef kBadgeKuranAy1 = BadgeDef(
  id: 'kuran_ay_1',
  emoji: '📖',
  name: '1 Aylık Kur\'ân Sadığı',
  description: '30 gün kesintisiz Kur\'ân okudun.',
  primaryColor: Color(0xFF1565C0),
  secondaryColor: Color(0xFF42A5F5),
  tier: 2,
);

const BadgeDef kBadgeKuranAy3 = BadgeDef(
  id: 'kuran_ay_3',
  emoji: '📖⭐',
  name: '3 Aylık Kur\'ân Yolcusu',
  description: '90 gün kesintisiz Kur\'ân okudun.',
  primaryColor: Color(0xFF0D47A1),
  secondaryColor: Color(0xFF1E88E5),
  tier: 3,
);

const BadgeDef kBadgeKuranAy6 = BadgeDef(
  id: 'kuran_ay_6',
  emoji: '📖💎',
  name: '6 Aylık Kur\'ân Dostu',
  description: '180 gün kesintisiz Kur\'ân okudun.',
  primaryColor: Color(0xFF006064),
  secondaryColor: Color(0xFF00ACC1),
  tier: 3,
);

const BadgeDef kBadgeKuranYil1 = BadgeDef(
  id: 'kuran_yil_1',
  emoji: '📖👑',
  name: '1 Yıllık Kur\'ân Hâfızı',
  description: '365 gün kesintisiz Kur\'ân okudun. Sonsuz tebrikler!',
  primaryColor: Color(0xFF4A148C),
  secondaryColor: Color(0xFFAB47BC),
  tier: 4,
);

// ─── Esmâ-ül Hüsnâ Serileri ───────────────────────────────────────────────────

const BadgeDef kBadgeEsmaAy1 = BadgeDef(
  id: 'esma_ay_1',
  emoji: '✨',
  name: '1 Aylık Esmâ Zâkiri',
  description: '30 gün kesintisiz Esmâ-ül Hüsnâ okudun.',
  primaryColor: Color(0xFF6A1B9A),
  secondaryColor: Color(0xFFCE93D8),
  tier: 2,
);

const BadgeDef kBadgeEsmaAy3 = BadgeDef(
  id: 'esma_ay_3',
  emoji: '✨⭐',
  name: '3 Aylık Esmâ Sadığı',
  description: '90 gün kesintisiz Esmâ-ül Hüsnâ okudun.',
  primaryColor: Color(0xFF4A148C),
  secondaryColor: Color(0xFF9C27B0),
  tier: 3,
);

const BadgeDef kBadgeEsmaAy6 = BadgeDef(
  id: 'esma_ay_6',
  emoji: '✨💎',
  name: '6 Aylık Esmâ Dostu',
  description: '180 gün kesintisiz Esmâ-ül Hüsnâ okudun.',
  primaryColor: Color(0xFF311B92),
  secondaryColor: Color(0xFF7E57C2),
  tier: 3,
);

const BadgeDef kBadgeEsmaYil1 = BadgeDef(
  id: 'esma_yil_1',
  emoji: '✨👑',
  name: '1 Yıllık Esmâ Hâfızı',
  description: '365 gün kesintisiz Esmâ-ül Hüsnâ okudun. Mâşallah!',
  primaryColor: Color(0xFF880E4F),
  secondaryColor: Color(0xFFF48FB1),
  tier: 4,
);

// ─── Hadis Serileri ───────────────────────────────────────────────────────────

const BadgeDef kBadgeHadisAy1 = BadgeDef(
  id: 'hadis_ay_1',
  emoji: '📜',
  name: '1 Aylık Sünnet Takipçisi',
  description: '30 gün kesintisiz hadis okudun.',
  primaryColor: Color(0xFF1B5E20),
  secondaryColor: Color(0xFF66BB6A),
  tier: 2,
);

const BadgeDef kBadgeHadisAy3 = BadgeDef(
  id: 'hadis_ay_3',
  emoji: '📜⭐',
  name: '3 Aylık Sünnet Yolcusu',
  description: '90 gün kesintisiz hadis okudun.',
  primaryColor: Color(0xFF33691E),
  secondaryColor: Color(0xFF8BC34A),
  tier: 3,
);

const BadgeDef kBadgeHadisAy6 = BadgeDef(
  id: 'hadis_ay_6',
  emoji: '📜💎',
  name: '6 Aylık Hadis Dostu',
  description: '180 gün kesintisiz hadis okudun.',
  primaryColor: Color(0xFF004D40),
  secondaryColor: Color(0xFF26A69A),
  tier: 3,
);

const BadgeDef kBadgeHadisYil1 = BadgeDef(
  id: 'hadis_yil_1',
  emoji: '📜👑',
  name: '1 Yıllık Sünnet Ustası',
  description: '365 gün kesintisiz hadis okudun. Mâşallah!',
  primaryColor: Color(0xFF01579B),
  secondaryColor: Color(0xFF4FC3F7),
  tier: 4,
);

// ─── Kombine Okuma (Kur\'ân + Esmâ + Hadis) ──────────────────────────────────

const BadgeDef kBadgeKombineAy1 = BadgeDef(
  id: 'kombine_ay_1',
  emoji: '🌟',
  name: 'Tam Donanımlı Mü\'min',
  description: '30 gün Kur\'ân, Esmâ ve Hadis\'i birlikte okudun.',
  primaryColor: Color(0xFFF57F17),
  secondaryColor: Color(0xFFFFD54F),
  tier: 3,
);

const BadgeDef kBadgeKombineAy3 = BadgeDef(
  id: 'kombine_ay_3',
  emoji: '🌟⭐',
  name: 'Ruhânî Yolculuk',
  description: '90 gün Kur\'ân, Esmâ ve Hadis\'i birlikte okudun.',
  primaryColor: Color(0xFFE65100),
  secondaryColor: Color(0xFFFF9800),
  tier: 4,
);

const BadgeDef kBadgeKombineAy6 = BadgeDef(
  id: 'kombine_ay_6',
  emoji: '🌟💎',
  name: 'Mâneviyat Ustası',
  description: '180 gün Kur\'ân, Esmâ ve Hadis\'i birlikte okudun.',
  primaryColor: Color(0xFFBF360C),
  secondaryColor: Color(0xFFFF7043),
  tier: 4,
);

const BadgeDef kBadgeKombineYil1 = BadgeDef(
  id: 'kombine_yil_1',
  emoji: '🌟👑',
  name: 'Yılın Mü\'min Kahramanı',
  description: '365 gün tüm kategorilerde kesintisiz okudun. Olağanüstü!',
  primaryColor: Color(0xFF4A148C),
  secondaryColor: Color(0xFFD4AF37),
  tier: 4,
);

// ─── Teheccüd Rozetleri ───────────────────────────────────────────────────────

const BadgeDef kBadgeTahajjud3 = BadgeDef(
  id: 'tahajjud_3',
  emoji: '🌙✨',
  name: 'Gecenin İlk Habercisi',
  description: 'Toplam 3 gece teheccüd namazı kıldın. Bu nadir bir güzellik.',
  primaryColor: Color(0xFF263238),
  secondaryColor: Color(0xFF90A4AE),
  tier: 4,
);

const BadgeDef kBadgeTahajjud10 = BadgeDef(
  id: 'tahajjud_10',
  emoji: '🌙🔟',
  name: 'Gece Sadığı',
  description: 'Toplam 10 gece teheccüd namazı kıldın.',
  primaryColor: Color(0xFF0D1B2A),
  secondaryColor: Color(0xFF1565C0),
  tier: 3,
);

const BadgeDef kBadgeTahajjud30 = BadgeDef(
  id: 'tahajjud_30',
  emoji: '🌙⭐',
  name: 'Gece Yolcusu',
  description: 'Toplam 30 gece teheccüd namazı kıldın.',
  primaryColor: Color(0xFF1A237E),
  secondaryColor: Color(0xFF3949AB),
  tier: 4,
);

const BadgeDef kBadgeTahajjud50 = BadgeDef(
  id: 'tahajjud_50',
  emoji: '🌙💎',
  name: 'Gece Ustası',
  description: 'Toplam 50 gece teheccüd namazı kıldın. Benzersiz bir sadakat.',
  primaryColor: Color(0xFF006064),
  secondaryColor: Color(0xFF00E5FF),
  tier: 4,
);

const BadgeDef kBadgeTahajjud99 = BadgeDef(
  id: 'tahajjud_99',
  emoji: '🌙👑',
  name: 'Teheccüd Kahramanı',
  description: 'Toplam 99 gece teheccüd namazı kıldın. Subhânallah!',
  primaryColor: Color(0xFF37003C),
  secondaryColor: Color(0xFFD4AF37),
  tier: 4,
);

// ─── Veteran Rozeti ───────────────────────────────────────────────────────────

const BadgeDef kBadgeVeteran1Yil = BadgeDef(
  id: 'veteran_1_yil',
  emoji: '🎖️',
  name: '1 Yıllık Murâkabe Yolcusu',
  description: 'Murakabe ile tam 1 yıldır birliktesin. Tüm kalbimizle tebrik ederiz!',
  primaryColor: Color(0xFF78002E),
  secondaryColor: Color(0xFFD4AF37),
  tier: 4,
);

// ─── Tam liste ────────────────────────────────────────────────────────────────

const List<BadgeDef> kTumRozetler = [
  kBadgeKuranAy1,
  kBadgeKuranAy3,
  kBadgeKuranAy6,
  kBadgeKuranYil1,
  kBadgeEsmaAy1,
  kBadgeEsmaAy3,
  kBadgeEsmaAy6,
  kBadgeEsmaYil1,
  kBadgeHadisAy1,
  kBadgeHadisAy3,
  kBadgeHadisAy6,
  kBadgeHadisYil1,
  kBadgeKombineAy1,
  kBadgeKombineAy3,
  kBadgeKombineAy6,
  kBadgeKombineYil1,
  kBadgeTahajjud3,
  kBadgeTahajjud10,
  kBadgeTahajjud30,
  kBadgeTahajjud50,
  kBadgeTahajjud99,
  kBadgeVeteran1Yil,
];

BadgeDef? badgeDefById(String id) {
  try {
    return kTumRozetler.firstWhere((b) => b.id == id);
  } catch (_) {
    return null;
  }
}
