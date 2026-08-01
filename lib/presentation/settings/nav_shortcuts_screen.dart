import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/nav_shortcuts.dart';
import '../../data/local/local_storage.dart';

class NavShortcutsScreen extends StatefulWidget {
  const NavShortcutsScreen({super.key});

  @override
  State<NavShortcutsScreen> createState() => _NavShortcutsScreenState();
}

class _NavShortcutsScreenState extends State<NavShortcutsScreen> {
  late List<String?> _slots;

  @override
  void initState() {
    super.initState();
    final saved = LocalStorage().navShortcutIds;
    _slots =
        List<String?>.generate(3, (i) => i < saved.length ? saved[i] : null);
  }

  Future<void> _persist() async {
    final ids = _slots.whereType<String>().toList();
    await LocalStorage().setNavShortcutIds(ids);
  }

  void _assign(int slotIndex, String id) {
    setState(() {
      // Aynı kısayol başka bir kutuda zaten varsa oradan kaldır — sürükleme
      // "taşıma" gibi hissettirsin, kopya oluşmasın.
      for (int i = 0; i < _slots.length; i++) {
        if (_slots[i] == id) _slots[i] = null;
      }
      _slots[slotIndex] = id;
    });
    _persist();
  }

  void _clear(int slotIndex) {
    setState(() => _slots[slotIndex] = null);
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    final usedIds = _slots.whereType<String>().toSet();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B), Color(0xFF0D2233)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon:
                          const Icon(Icons.arrow_back_ios, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      'Kısayolları Düzenle',
                      style: GoogleFonts.playfairDisplay(
                        color: AppColors.gold,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'ALT MENÜN',
                    style: GoogleFonts.notoSans(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildFixedHomeBox()),
                    const SizedBox(width: 8),
                    for (int i = 0; i < 3; i++) ...[
                      Expanded(child: _buildSlot(i)),
                      if (i < 2) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'TÜM ÖZELLİKLER',
                    style: GoogleFonts.notoSans(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1,
                  children: kNavShortcutCatalog
                      .map((s) => _buildCatalogItem(s, usedIds.contains(s.id)))
                      .toList(),
                ),
                const SizedBox(height: 20),
                Text(
                  'Bir öğeyi kutulardan birine sürükle. En fazla 3 kısayol seçebilirsin.',
                  textAlign: TextAlign.center,
                  style:
                      GoogleFonts.notoSans(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFixedHomeBox() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.home_outlined, color: AppColors.gold, size: 22),
              Positioned(
                top: -4,
                right: -8,
                child: Icon(Icons.lock,
                    color: Colors.white.withValues(alpha: 0.4), size: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Ana Sayfa',
              style: GoogleFonts.notoSans(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildSlot(int index) {
    final id = _slots[index];
    final def = id != null ? findNavShortcut(id) : null;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) => _assign(index, details.data),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isHovering
                ? AppColors.gold.withValues(alpha: 0.18)
                : AppColors.gold.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.gold.withValues(alpha: isHovering ? 0.7 : 0.35),
            ),
          ),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(def?.icon ?? Icons.add, color: AppColors.gold, size: 22),
                  if (def != null)
                    Positioned(
                      top: -6,
                      right: -10,
                      child: GestureDetector(
                        onTap: () => _clear(index),
                        child: const Icon(Icons.cancel,
                            color: Colors.white38, size: 14),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(def?.label ?? 'Boş',
                  style: GoogleFonts.notoSans(
                      color: Colors.white54, fontSize: 10)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCatalogItem(NavShortcutDef def, bool isUsed) {
    return Opacity(
      opacity: isUsed ? 0.35 : 1.0,
      child: Draggable<String>(
        data: def.id,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: 90,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1B3A4B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold),
            ),
            child: Column(
              children: [
                Icon(def.icon, color: AppColors.gold, size: 20),
                const SizedBox(height: 4),
                Text(def.label,
                    style: GoogleFonts.notoSans(
                        color: Colors.white, fontSize: 10)),
              ],
            ),
          ),
        ),
        childWhenDragging: _catalogBox(def, dimmed: true),
        child: _catalogBox(def, dimmed: false),
      ),
    );
  }

  Widget _catalogBox(NavShortcutDef def, {required bool dimmed}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: dimmed ? 0.02 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(def.icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(def.label,
              style: GoogleFonts.notoSans(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }
}
