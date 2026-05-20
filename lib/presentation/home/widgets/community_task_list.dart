import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/local/local_storage.dart';

class CommunityTaskList extends StatelessWidget {
  final String communityId;
  final String communityName;
  const CommunityTaskList({
    super.key,
    required this.communityId,
    required this.communityName,
  });

  @override
  Widget build(BuildContext context) {
    final uid = LocalStorage().userId;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('tasks')
          .orderBy('deadline')
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        final pending = docs.where((d) {
          final completions =
              Map<String, dynamic>.from(d['completions'] as Map? ?? {});
          return !completions.containsKey(uid);
        }).toList();

        if (pending.isEmpty) return const SizedBox.shrink();

        return Column(
          children: pending.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final taskId = doc.id;
            final title = data['title'] as String? ?? '';
            final desc = data['description'] as String? ?? '';
            final deadline = (data['deadline'] as Timestamp?)?.toDate();
            final isOverdue =
                deadline != null && deadline.isBefore(DateTime.now());

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A2035),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isOverdue
                      ? Colors.red.withValues(alpha: 0.4)
                      : AppColors.turquoise.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (communityName.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  AppColors.turquoise.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: AppColors.turquoise
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              communityName,
                              style: GoogleFonts.notoSans(
                                color: AppColors.turquoiseLight,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Text(
                          title,
                          style: GoogleFonts.notoSans(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(desc,
                              style: GoogleFonts.notoSans(
                                  color: Colors.white54, fontSize: 12)),
                        ],
                        if (deadline != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 11,
                                  color: isOverdue
                                      ? Colors.red
                                      : Colors.white38),
                              const SizedBox(width: 4),
                              Text(
                                'Son: ${deadline.day}.${deadline.month}.${deadline.year}',
                                style: GoogleFonts.notoSans(
                                  color: isOverdue
                                      ? Colors.red
                                      : Colors.white38,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      if (uid == null) return;
                      await FirebaseFirestore.instance
                          .collection('communities')
                          .doc(communityId)
                          .collection('tasks')
                          .doc(taskId)
                          .update({
                        'completions.$uid': FieldValue.serverTimestamp(),
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.turquoise.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color:
                                AppColors.turquoise.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'Tamamladım',
                        style: GoogleFonts.notoSans(
                          color: AppColors.turquoiseLight,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
