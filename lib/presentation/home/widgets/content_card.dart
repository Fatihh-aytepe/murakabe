import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/repositories/content_repository.dart';
import '../../rewards/reward_flow.dart';

class ContentCard extends StatefulWidget {
  final String type;
  // Kayıt ve "Okudum" durumunu veritabanından okuyabilmek için içeriğin id'si.
  final int contentId;
  final String title;
  final String subtitle;
  final String tag;
  final Color color;
  // Detay ekranı kapanana kadar tamamlanmayan bir Future döner — kart,
  // detayda yapılan değişiklikleri (Kaydet / Okudum) dönüşte yeniden okur.
  final Future<void> Function() onTap;
  final VoidCallback onRemind;

  const ContentCard({
    super.key,
    required this.type,
    required this.contentId,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.color,
    required this.onTap,
    required this.onRemind,
  });

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  final _contentRepo = ContentRepository();
  bool _isSaved = false;
  bool _isRead = false;

  // ÖNCEDEN: _isSaved/_isRead yalnızca kartın kendi hafızasındaydı ve hep
  // false başlıyordu — kaydedilen içerik ekran yenilenince "kaydedilmemiş"
  // görünüyor, "Okudum" hiçbir yere yazılmıyordu. Artık açılışta ve detay
  // ekranından dönüşte gerçek durum okunuyor.
  @override
  void initState() {
    super.initState();
    // initState içinde setState çağrılamaz — "Okudum" senkron okunduğu için
    // doğrudan atanır; kayıt durumu (SQLite) asenkron yüklenir.
    _isRead = _contentRepo.isReadToday(widget.type, widget.contentId);
    _loadSaved();
  }

  @override
  void didUpdateWidget(covariant ContentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentId != widget.contentId ||
        oldWidget.type != widget.type) {
      // didUpdateWidget'tan sonra build zaten çalışır, setState gerekmez.
      _isRead = _contentRepo.isReadToday(widget.type, widget.contentId);
      _isSaved = false;
      _loadSaved();
    }
  }

  Future<void> _loadSaved() async {
    final saved = await _contentRepo.isSaved(widget.type, widget.contentId);
    if (mounted && saved != _isSaved) setState(() => _isSaved = saved);
  }

  Future<void> _openDetail() async {
    await widget.onTap();
    if (!mounted) return;
    // Detay ekranında yapılan Kaydet / Okudum değişikliklerini yansıt.
    setState(() =>
        _isRead = _contentRepo.isReadToday(widget.type, widget.contentId));
    _loadSaved();
  }

  void _markRead() {
    if (_isRead) return;
    setState(() => _isRead = true);
    _contentRepo.markReadToday(widget.type, widget.contentId);
    // Seri + tebrik + rozet kontrolü anında (bkz. RewardFlow).
    RewardFlow.afterRead(Navigator.of(context), widget.type);
  }

  // Önce ekran ANINDA güncellenir, kayıt arkadan yapılır. Hata olursa geri
  // alınır. ÖNCEDEN ikinci dokunuş görüntüde kaydı kaldırıyor ama
  // veritabanına tekrar KAYDEDİYORDU.
  Future<void> _toggleSave() async {
    final wasSaved = _isSaved;
    setState(() => _isSaved = !wasSaved);
    try {
      if (wasSaved) {
        await _contentRepo.unsaveContent(widget.type, widget.contentId);
      } else {
        await _contentRepo.saveContent(widget.type, widget.contentId);
      }
    } catch (_) {
      if (mounted) setState(() => _isSaved = wasSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A2035) : Colors.white;
    final subColor = isDark ? Colors.white54 : AppColors.textSecondary;

    return GestureDetector(
      onTap: _openDetail,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.color,
                    widget.color.withValues(alpha: 0.7)
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  _buildTypeIcon(),
                  const SizedBox(width: 8),
                  Text(
                    widget.tag,
                    style: GoogleFonts.notoSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  if (_isSaved)
                    const Icon(Icons.bookmark,
                        color: Colors.white, size: 18),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.amiri(
                      fontSize: 22,
                      color: widget.color,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSans(
                      fontSize: 13,
                      color: subColor,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: AppStrings.read,
                          icon: Icons.check_circle_outline,
                          color: AppColors.success,
                          isActive: _isRead,
                          isDark: isDark,
                          onTap: _markRead,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          label: AppStrings.remind,
                          icon: Icons.alarm_outlined,
                          color: AppColors.warning,
                          isActive: false,
                          isDark: isDark,
                          onTap: () {
                            widget.onRemind();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('3 saat sonra hatırlatılacak'),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ActionButton(
                          label: _isSaved
                              ? AppStrings.saved
                              : AppStrings.save,
                          icon: _isSaved
                              ? Icons.bookmark
                              : Icons.bookmark_outline,
                          color: widget.color,
                          isActive: _isSaved,
                          isDark: isDark,
                          onTap: _toggleSave,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeIcon() {
    final icons = {
      'esma': Icons.auto_awesome,
      'ayet': Icons.menu_book,
      'hadis': Icons.format_quote,
    };
    return Icon(icons[widget.type] ?? Icons.info,
        color: Colors.white, size: 16);
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgInactive = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : AppColors.background;
    final borderInactive = isDark
        ? Colors.white.withValues(alpha: 0.15)
        : AppColors.textLight.withValues(alpha: 0.3);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : bgInactive,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : borderInactive,
          ),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isActive ? color : AppColors.textLight, size: 16),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isActive ? color : AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
