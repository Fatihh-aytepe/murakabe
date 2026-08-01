import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

class CommunityActivityPreview extends StatelessWidget {
  final String communityId;
  final String communityName;
  final VoidCallback? onTap;

  const CommunityActivityPreview({
    super.key,
    required this.communityId,
    required this.communityName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLatestMessage(),
        _buildLatestAnnouncement(),
      ],
    );
  }

  Widget _buildLatestMessage() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        final data = docs.first.data() as Map<String, dynamic>;
        final text = data['text'] as String? ?? '';
        final sender = data['senderName'] as String? ?? '';
        final ts = (data['sentAt'] as Timestamp?)?.toDate();
        if (text.isEmpty) return const SizedBox.shrink();
        return _PreviewRow(
          icon: Icons.chat_bubble_outline,
          color: AppColors.turquoise,
          title: 'Yeni mesaj — $communityName',
          subtitle: sender.isNotEmpty ? '$sender: $text' : text,
          time: _formatTime(ts),
          onTap: onTap,
        );
      },
    );
  }

  Widget _buildLatestAnnouncement() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('announcements')
          .orderBy('sentAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();
        final data = docs.first.data() as Map<String, dynamic>;
        final message = data['message'] as String? ?? '';
        final isWarning = data['isWarning'] == true;
        final ts = (data['sentAt'] as Timestamp?)?.toDate();
        if (message.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: _PreviewRow(
            icon: Icons.campaign_outlined,
            color: isWarning ? const Color(0xFFFF6B35) : AppColors.gold,
            title: 'Yeni duyuru — $communityName',
            subtitle: message,
            time: _formatTime(ts),
            onTap: onTap,
          ),
        );
      },
    );
  }

  String _formatTime(DateTime? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'şimdi';
    if (diff.inMinutes < 60) return '${diff.inMinutes}dk';
    if (diff.inHours < 24) return '${diff.inHours}sa';
    return '${diff.inDays}g';
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String time;
  final VoidCallback? onTap;

  const _PreviewRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.time,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.notoSans(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSans(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text(
              time,
              style: GoogleFonts.notoSans(color: Colors.white24, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
