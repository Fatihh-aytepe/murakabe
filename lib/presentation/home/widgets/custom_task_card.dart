import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/custom_task_model.dart';

class CustomTaskCard extends StatefulWidget {
  final CustomTaskModel task;
  final VoidCallback onCompleted;

  const CustomTaskCard({
    super.key,
    required this.task,
    required this.onCompleted,
  });

  @override
  State<CustomTaskCard> createState() => _CustomTaskCardState();
}

class _CustomTaskCardState extends State<CustomTaskCard> {
  late bool _isDone;

  @override
  void initState() {
    super.initState();
    _isDone = widget.task.completedToday;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1A2035) : Colors.white;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final subColor = isDark ? Colors.white54 : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (_isDone ? AppColors.success : AppColors.gold)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.task.emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.task.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    decoration: _isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (widget.task.description.isNotEmpty)
                  Text(
                    widget.task.description,
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      color: subColor,
                    ),
                  ),
                if (widget.task.notificationTime.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.alarm_outlined,
                          size: 12, color: AppColors.turquoise),
                      const SizedBox(width: 4),
                      Text(
                        widget.task.notificationTime,
                        style: GoogleFonts.notoSans(
                          fontSize: 11,
                          color: AppColors.turquoise,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              if (!_isDone) {
                setState(() => _isDone = true);
                widget.onCompleted();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isDone
                    ? AppColors.success
                    : AppColors.success.withValues(alpha: 0.1),
                border: Border.all(
                  color: _isDone
                      ? AppColors.success
                      : AppColors.success.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.check,
                color: _isDone ? Colors.white : AppColors.success,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
