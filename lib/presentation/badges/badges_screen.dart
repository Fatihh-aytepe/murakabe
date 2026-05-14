import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/badge_definitions.dart';
import '../../data/local/local_storage.dart';
import '../../data/models/badge_model.dart';
import '../../data/repositories/badge_repository.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final _repo = BadgeRepository();
  final _storage = LocalStorage();

  List<BadgeModel> _earnedBadges = [];
  String? _displayedBadgeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  Future<void> _loadBadges() async {
    final badges = await _repo.getAllBadges();
    if (mounted) {
      setState(() {
        _earnedBadges = badges;
        _displayedBadgeId = _storage.displayedBadgeId;
        _loading = false;
      });
    }
  }

  bool _isEarned(String badgeId) =>
      _earnedBadges.any((b) => b.badgeId == badgeId);

  Future<void> _toggleDisplay(BadgeDef def) async {
    if (_displayedBadgeId == def.id) {
      await _repo.clearDisplayedBadge();
      if (!mounted) return;
      setState(() => _displayedBadgeId = null);
    } else {
      await _repo.setDisplayedBadge(def.id);
      if (!mounted) return;
      setState(() => _displayedBadgeId = def.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF5F5F5);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1A2035) : Colors.white,
        elevation: 0,
        title: Text(
          'Rozetlerim',
          style: GoogleFonts.playfairDisplay(
            color: AppColors.gold,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new,
              color: isDark ? Colors.white70 : AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    final earnedCount = kTumRozetler
        .where((def) => _isEarned(def.id))
        .length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              children: [
                _StatChip(
                  label: 'Kazanılan',
                  value: '$earnedCount',
                  color: AppColors.gold,
                ),
                const SizedBox(width: 12),
                _StatChip(
                  label: 'Toplam',
                  value: '${kTumRozetler.length}',
                  color: Colors.grey,
                ),
                const Spacer(),
                if (_displayedBadgeId != null)
                  _ActiveBadgeChip(badgeId: _displayedBadgeId!),
              ],
            ),
          ),
        ),

        // Kategoriler
        ..._buildCategorySections(isDark),
      ],
    );
  }

  List<Widget> _buildCategorySections(bool isDark) {
    final sections = [
      _BadgeSection(
        title: 'Kur\'ân Serileri',
        icon: '📖',
        badges: [
          kBadgeKuranAy1,
          kBadgeKuranAy3,
          kBadgeKuranAy6,
          kBadgeKuranYil1,
        ],
      ),
      _BadgeSection(
        title: 'Esmâ-ül Hüsnâ Serileri',
        icon: '✨',
        badges: [
          kBadgeEsmaAy1,
          kBadgeEsmaAy3,
          kBadgeEsmaAy6,
          kBadgeEsmaYil1,
        ],
      ),
      _BadgeSection(
        title: 'Hadis Serileri',
        icon: '📜',
        badges: [
          kBadgeHadisAy1,
          kBadgeHadisAy3,
          kBadgeHadisAy6,
          kBadgeHadisYil1,
        ],
      ),
      _BadgeSection(
        title: 'Kombine Okuma',
        icon: '🌟',
        badges: [
          kBadgeKombineAy1,
          kBadgeKombineAy3,
          kBadgeKombineAy6,
          kBadgeKombineYil1,
        ],
      ),
      _BadgeSection(
        title: 'Teheccüd',
        icon: '🌙',
        badges: [
          kBadgeTahajjud3,
          kBadgeTahajjud10,
          kBadgeTahajjud30,
          kBadgeTahajjud50,
          kBadgeTahajjud99,
        ],
      ),
      _BadgeSection(
        title: 'Özel',
        icon: '🎖️',
        badges: [kBadgeVeteran1Yil],
      ),
    ];

    return sections.map((section) {
      return SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                children: [
                  Text(section.icon, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Text(
                    section.title,
                    style: GoogleFonts.notoSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white70 : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              childAspectRatio: 1.1,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: section.badges
                  .map((def) => _BadgeCard(
                        def: def,
                        earned: _isEarned(def.id),
                        isDisplayed: _displayedBadgeId == def.id,
                        earnedAt: _earnedBadges
                            .where((b) => b.badgeId == def.id)
                            .map((b) => b.earnedAt)
                            .firstOrNull,
                        onToggleDisplay: () => _toggleDisplay(def),
                        isDark: isDark,
                      ))
                  .toList(),
            ),
          ],
        ),
      );
    }).toList();
  }
}

// ─── Yardımcı widget'lar ─────────────────────────────────────────────────────

class _BadgeSection {
  final String title;
  final String icon;
  final List<BadgeDef> badges;
  const _BadgeSection({
    required this.title,
    required this.icon,
    required this.badges,
  });
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: value,
              style: GoogleFonts.notoSans(
                  fontWeight: FontWeight.bold, color: color, fontSize: 14),
            ),
            TextSpan(
              text: ' $label',
              style: GoogleFonts.notoSans(color: color, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveBadgeChip extends StatelessWidget {
  final String badgeId;
  const _ActiveBadgeChip({required this.badgeId});

  @override
  Widget build(BuildContext context) {
    final def = badgeDefById(badgeId);
    if (def == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: def.gradient),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(def.emoji.characters.first,
              style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            'Profilde gösteriliyor',
            style:
                GoogleFonts.notoSans(color: Colors.white, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final BadgeDef def;
  final bool earned;
  final bool isDisplayed;
  final DateTime? earnedAt;
  final Future<void> Function() onToggleDisplay;
  final bool isDark;

  const _BadgeCard({
    required this.def,
    required this.earned,
    required this.isDisplayed,
    required this.earnedAt,
    required this.onToggleDisplay,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: earned
          ? () => _showDetail(context)
          : () => _showLockedInfo(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: earned
              ? LinearGradient(
                  colors: [
                    def.primaryColor.withValues(alpha: 0.9),
                    def.secondaryColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.grey.shade800.withValues(alpha: 0.4),
                    Colors.grey.shade700.withValues(alpha: 0.3),
                  ],
                ),
          border: Border.all(
            color: isDisplayed
                ? AppColors.gold
                : earned
                    ? def.secondaryColor.withValues(alpha: 0.6)
                    : Colors.grey.withValues(alpha: 0.2),
            width: isDisplayed ? 2 : 1,
          ),
          boxShadow: earned
              ? [
                  BoxShadow(
                    color: def.primaryColor.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Emoji + kilit
              Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    def.emoji.characters.first,
                    style: TextStyle(
                      fontSize: 36,
                      color: earned ? null : Colors.transparent,
                    ),
                  ),
                  if (!earned)
                    const Icon(Icons.lock, color: Colors.white38, size: 32),
                  if (earned && !isDisplayed)
                    Text(def.emoji.characters.first,
                        style: const TextStyle(fontSize: 36)),
                ],
              ),
              const SizedBox(height: 6),

              // Rozet adı
              Text(
                def.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.notoSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: earned ? Colors.white : Colors.white38,
                ),
              ),

              const SizedBox(height: 4),

              // Tier etiketi veya kazanım tarihi
              if (earned && earnedAt != null)
                Text(
                  _formatDate(earnedAt!),
                  style: GoogleFonts.notoSans(
                      fontSize: 9, color: Colors.white60),
                )
              else
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: earned
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    def.tierLabel,
                    style: GoogleFonts.notoSans(
                      fontSize: 9,
                      color: earned ? Colors.white70 : Colors.white24,
                    ),
                  ),
                ),

              // Profilde göster butonu
              if (earned) ...[
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => onToggleDisplay(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDisplayed
                          ? AppColors.gold.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: isDisplayed
                          ? Border.all(
                              color: AppColors.gold.withValues(alpha: 0.7))
                          : null,
                    ),
                    child: Text(
                      isDisplayed ? '✓ Profilde' : 'Profilde Göster',
                      style: GoogleFonts.notoSans(
                        fontSize: 9,
                        color: isDisplayed
                            ? AppColors.gold
                            : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _BadgeDetailSheet(
        def: def,
        earnedAt: earnedAt,
        isDisplayed: isDisplayed,
        onToggleDisplay: onToggleDisplay,
      ),
    );
  }

  void _showLockedInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF1A2035),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock, color: Colors.white38, size: 40),
            const SizedBox(height: 12),
            Text(
              def.name,
              textAlign: TextAlign.center,
              style: GoogleFonts.playfairDisplay(
                  color: Colors.white60,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              def.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                  color: Colors.white38, fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      '',
      'Oca',
      'Şub',
      'Mar',
      'Nis',
      'May',
      'Haz',
      'Tem',
      'Ağu',
      'Eyl',
      'Eki',
      'Kas',
      'Ara',
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

class _BadgeDetailSheet extends StatelessWidget {
  final BadgeDef def;
  final DateTime? earnedAt;
  final bool isDisplayed;
  final Future<void> Function() onToggleDisplay;

  const _BadgeDetailSheet({
    required this.def,
    required this.earnedAt,
    required this.isDisplayed,
    required this.onToggleDisplay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            def.primaryColor.withValues(alpha: 0.95),
            def.secondaryColor.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            def.emoji.characters.first,
            style: const TextStyle(fontSize: 60),
          ),
          const SizedBox(height: 12),
          Text(
            def.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.playfairDisplay(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              def.tierLabel,
              style: GoogleFonts.notoSans(
                  color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            def.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.notoSans(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
              height: 1.7,
            ),
          ),
          if (earnedAt != null) ...[
            const SizedBox(height: 12),
            Text(
              '${earnedAt!.day}.${earnedAt!.month}.${earnedAt!.year} tarihinde kazanıldı',
              style: GoogleFonts.notoSans(
                  color: Colors.white60, fontSize: 12),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                await onToggleDisplay();
                if (context.mounted) Navigator.pop(context);
              },
              icon: Icon(
                isDisplayed ? Icons.check_circle : Icons.person_pin,
                color: def.primaryColor,
              ),
              label: Text(
                isDisplayed ? 'Profilden Kaldır' : 'Profilde Göster',
                style: GoogleFonts.notoSans(
                  fontWeight: FontWeight.bold,
                  color: def.primaryColor,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
