import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';

class ContentCard extends StatefulWidget {
  final String type;
  final String title;
  final String subtitle;
  final String tag;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onRemind;

  const ContentCard({
    super.key,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.color,
    required this.onTap,
    required this.onSave,
    required this.onRemind,
  });

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  bool _isSaved = false;
  bool _isRead = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A2035) : Colors.white;
    final subColor = isDark ? Colors.white54 : AppColors.textSecondary;

    return GestureDetector(
      onTap: widget.onTap,
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
                          onTap: () {
                            setState(() => _isRead = true);
                          },
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
                          onTap: () {
                            setState(() => _isSaved = !_isSaved);
                            widget.onSave();
                          },
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
