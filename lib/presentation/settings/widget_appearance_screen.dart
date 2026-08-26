import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/widget_bridge_service.dart';
import '../../data/local/local_storage.dart';

/// Ana ekran widget'larının (namaz vakitleri, zikir sayacı, günlük içerik)
/// görünümünü özelleştirme ekranı: tema (imza/açık/koyu), arka plan
/// saydamlığı, vurgu rengi. Değişiklikler kaydedilince tüm widget'lar
/// [WidgetBridgeService.refreshAppearanceOnly] ile anında yeniden çizilir.
class WidgetAppearanceScreen extends StatefulWidget {
  const WidgetAppearanceScreen({super.key});

  @override
  State<WidgetAppearanceScreen> createState() =>
      _WidgetAppearanceScreenState();
}

class _WidgetAppearanceScreenState extends State<WidgetAppearanceScreen> {
  final _storage = LocalStorage();

  late String _themeMode; // 'signature' | 'light' | 'dark'
  late double _opacity; // 0-100
  late String _accentHex;
  bool _isSaving = false;
  bool _dirty = false;

  static const _accentOptions = [
    {'label': 'Altın', 'hex': 'D4AF37'},
    {'label': 'Turkuaz', 'hex': '40B4C8'},
    {'label': 'Zümrüt', 'hex': '4CAF7D'},
    {'label': 'Yakut', 'hex': 'B5473A'},
    {'label': 'Lacivert', 'hex': '4B6FA8'},
    {'label': 'Gümüş', 'hex': 'C7CDD6'},
  ];

  @override
  void initState() {
    super.initState();
    _themeMode = _storage.widgetThemeMode;
    _opacity = _storage.widgetBgOpacity.toDouble();
    _accentHex = _storage.widgetAccentHex;
  }

  Color get _accentColor => Color(int.parse('FF$_accentHex', radix: 16));

  void _markDirty() => setState(() => _dirty = true);

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await _storage.setWidgetThemeMode(_themeMode);
    await _storage.setWidgetBgOpacity(_opacity.round());
    await _storage.setWidgetAccentHex(_accentHex);
    await WidgetBridgeService().refreshAppearanceOnly();
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _dirty = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Widget görünümü güncellendi')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1B2A) : const Color(0xFFF0F2F5);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0D1B2A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios,
              color: isDark ? Colors.white : AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Widget Görünümü',
          style: GoogleFonts.playfairDisplay(
            color: isDark ? AppColors.gold : AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _preview(),
            const SizedBox(height: 24),
            _sectionTitle('TEMA', isDark),
            const SizedBox(height: 10),
            _themeSelector(isDark),
            const SizedBox(height: 24),
            _sectionTitle('ARKA PLAN SAYDAMLIĞI', isDark),
            const SizedBox(height: 10),
            _opacitySlider(isDark),
            const SizedBox(height: 24),
            _sectionTitle('VURGU RENGİ', isDark),
            const SizedBox(height: 10),
            _accentSelector(isDark),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: (_dirty && !_isSaving) ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  disabledBackgroundColor: AppColors.gold.withValues(alpha: 0.35),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2),
                      )
                    : Text(
                        _dirty ? 'Kaydet ve Widget\'ları Güncelle' : 'Güncel',
                        style: GoogleFonts.notoSans(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ana ekrandaki namaz vakitleri, zikir sayacı ve günlük içerik '
              'widget\'larının hepsi bu ayarı kullanır.',
              textAlign: TextAlign.center,
              style: GoogleFonts.notoSans(
                color: isDark ? Colors.white38 : AppColors.textLight,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text, bool isDark) => Text(
        text,
        style: GoogleFonts.notoSans(
          color: isDark ? Colors.white70 : AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      );

  // ── Canlı önizleme ─────────────────────────────────────────────────────
  Widget _preview() {
    final colors = _resolvedPreviewColors();
    return Container(
      height: 128,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _accentColor.withValues(alpha: 0.16),
              border: Border.all(color: _accentColor, width: 1.2),
            ),
            child: Icon(Icons.mosque_outlined, color: _accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('İkindi\'ye 2s 14dk',
                    style: GoogleFonts.notoSans(
                        color: colors.textDim, fontSize: 12)),
                const SizedBox(height: 6),
                Text('15:47',
                    style: GoogleFonts.playfairDisplay(
                        color: colors.text,
                        fontSize: 26,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accentColor.withValues(alpha: 0.4)),
            ),
            child: Text('Önizleme',
                style: GoogleFonts.notoSans(
                    color: _accentColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  _PreviewColors _resolvedPreviewColors() {
    final alpha = (_opacity / 100).clamp(0.0, 1.0);
    switch (_themeMode) {
      case 'light':
        return _PreviewColors(
          bg: Color.lerp(Colors.transparent, const Color(0xFFFCF9F2), alpha)!,
          border: Colors.black12,
          text: const Color(0xFF2C2C2C),
          textDim: const Color(0xFF6B665C),
        );
      case 'dark':
        return _PreviewColors(
          bg: Color.lerp(Colors.transparent, const Color(0xFF14181D), alpha)!,
          border: Colors.white12,
          text: Colors.white,
          textDim: Colors.white54,
        );
      case 'signature':
      default:
        return _PreviewColors(
          bg: Color.lerp(Colors.transparent, const Color(0xFF15263D), alpha)!,
          border: Colors.white.withValues(alpha: 0.08),
          text: Colors.white,
          textDim: Colors.white60,
        );
    }
  }

  // ── Tema seçici ────────────────────────────────────────────────────────
  Widget _themeSelector(bool isDark) {
    const options = [
      {'key': 'signature', 'label': 'İmza Tema', 'icon': Icons.auto_awesome},
      {'key': 'light', 'label': 'Açık', 'icon': Icons.light_mode_outlined},
      {'key': 'dark', 'label': 'Koyu', 'icon': Icons.dark_mode_outlined},
    ];
    return Row(
      children: options.map((o) {
        final selected = _themeMode == o['key'];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: o == options.last ? 0 : 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _themeMode = o['key'] as String);
                _markDirty();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.gold.withValues(alpha: 0.16)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : Colors.white),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected
                        ? AppColors.gold
                        : (isDark ? Colors.white12 : Colors.black12),
                    width: selected ? 1.4 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(o['icon'] as IconData,
                        color: selected
                            ? AppColors.gold
                            : (isDark ? Colors.white54 : AppColors.textLight),
                        size: 20),
                    const SizedBox(height: 6),
                    Text(
                      o['label'] as String,
                      style: GoogleFonts.notoSans(
                        fontSize: 11.5,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        color: selected
                            ? AppColors.gold
                            : (isDark ? Colors.white54 : AppColors.textLight),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Saydamlık ──────────────────────────────────────────────────────────
  Widget _opacitySlider(bool isDark) {
    return Row(
      children: [
        Icon(Icons.opacity, size: 18, color: AppColors.gold.withValues(alpha: 0.8)),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.gold,
              inactiveTrackColor:
                  isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
              thumbColor: AppColors.gold,
              overlayColor: AppColors.gold.withValues(alpha: 0.15),
            ),
            child: Slider(
              value: _opacity,
              min: 20,
              max: 100,
              divisions: 16,
              onChanged: (v) {
                setState(() => _opacity = v);
                _markDirty();
              },
            ),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text('${_opacity.round()}%',
              textAlign: TextAlign.end,
              style: GoogleFonts.notoSans(
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  // ── Vurgu rengi ────────────────────────────────────────────────────────
  Widget _accentSelector(bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _accentOptions.map((opt) {
        final hex = opt['hex']!;
        final color = Color(int.parse('FF$hex', radix: 16));
        final selected = _accentHex == hex;
        return GestureDetector(
          onTap: () {
            setState(() => _accentHex = hex);
            _markDirty();
          },
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? (isDark ? Colors.white : Colors.black87)
                        : Colors.transparent,
                    width: 2.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: selected ? 10 : 0),
                  ],
                ),
                child: selected
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
              const SizedBox(height: 4),
              Text(opt['label']!,
                  style: GoogleFonts.notoSans(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : AppColors.textLight)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PreviewColors {
  final Color bg;
  final Color border;
  final Color text;
  final Color textDim;
  _PreviewColors({
    required this.bg,
    required this.border,
    required this.text,
    required this.textDim,
  });
}
