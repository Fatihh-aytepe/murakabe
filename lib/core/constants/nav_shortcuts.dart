import 'package:flutter/material.dart';

enum NavShortcutType { tab, push }

class NavShortcutDef {
  final String id;
  final String label;
  final IconData icon;
  final NavShortcutType type;

  const NavShortcutDef({
    required this.id,
    required this.label,
    required this.icon,
    required this.type,
  });
}

// Tüm kısayol havuzu — "Kısayolları Düzenle" ekranındaki seçenekler.
// type: tab -> IndexedStack'teki sabit bir sekmeye geçer (state korunur)
// type: push -> Navigator.push ile ayrı bir ekran olarak açılır
const List<NavShortcutDef> kNavShortcutCatalog = [
  NavShortcutDef(
      id: 'notes',
      label: 'Notlarım',
      icon: Icons.note_outlined,
      type: NavShortcutType.tab),
  NavShortcutDef(
      id: 'community',
      label: 'Topluluk',
      icon: Icons.group_outlined,
      type: NavShortcutType.tab),
  NavShortcutDef(
      id: 'profile',
      label: 'Profil',
      icon: Icons.person_outline,
      type: NavShortcutType.tab),
  NavShortcutDef(
      id: 'kible',
      label: 'Kıble',
      icon: Icons.explore_outlined,
      type: NavShortcutType.push),
  NavShortcutDef(
      id: 'kuran',
      label: 'Kuran',
      icon: Icons.menu_book,
      type: NavShortcutType.push),
  NavShortcutDef(
      id: 'zikir',
      label: 'Zikir',
      icon: Icons.spa_outlined,
      type: NavShortcutType.push),
  NavShortcutDef(
      id: 'ayarlar',
      label: 'Ayarlar',
      icon: Icons.settings_outlined,
      type: NavShortcutType.push),
];

// Sekme tipindeki kısayolların IndexedStack'teki SABİT konumu.
// Görsel sırası değişse bile (kullanıcı slotları farklı dizsin) bu eşleme
// sabit kalır — HomeScreen'in mevcut _selectedIndex mantığını bozmaz.
const Map<String, int> kTabShortcutFixedIndex = {
  'notes': 1,
  'community': 2,
  'profile': 3,
};

NavShortcutDef? findNavShortcut(String id) {
  for (final s in kNavShortcutCatalog) {
    if (s.id == id) return s;
  }
  return null;
}
