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
          // orderBy yok — composite index gerektirmesin; sıralama client-side
          .snapshots(),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: AppColors.turquoise, strokeWidth: 2),
              ),
            ),
          );
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const SizedBox.shrink();

        final pending = <QueryDocumentSnapshot>[];
        final done = <QueryDocumentSnapshot>[];

        for (final doc in docs) {
          final completions = Map<String, dynamic>.from(
              (doc.data() as Map<String, dynamic>)['completions'] as Map? ?? {});
          if (completions.containsKey(uid)) {
            done.add(doc);
          } else {
            pending.add(doc);
          }
        }

        int byDeadline(QueryDocumentSnapshot a, QueryDocumentSnapshot b) {
          final aD =
              ((a.data() as Map)['deadline'] as Timestamp?)?.toDate();
          final bD =
              ((b.data() as Map)['deadline'] as Timestamp?)?.toDate();
          if (aD == null && bD == null) return 0;
          if (aD == null) return 1;
          if (bD == null) return -1;
          return aD.compareTo(bD);
        }

        pending.sort(byDeadline);
        done.sort(byDeadline);

        final allDocs = [...pending, ...done];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 2),
              child: Row(
                children: [
                  const Icon(Icons.group_outlined,
                      color: AppColors.turquoise, size: 13),
                  const SizedBox(width: 5),
                  Text(
                    communityName.toUpperCase(),
                    style: GoogleFonts.notoSans(
                      color: AppColors.turquoise,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${pending.length} bekliyor · ${done.length} tamamlandı',
                    style: GoogleFonts.notoSans(
                        color: Colors.white24, fontSize: 10),
                  ),
                ],
              ),
            ),
            ...allDocs.map((doc) => _TaskTile(
                  doc: doc,
                  communityId: communityId,
                  uid: uid ?? '',
                )),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

// ── Tek görev satırı ─────────────────────────────────────────────────────────

class _TaskTile extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final String communityId;
  final String uid;

  const _TaskTile({
    required this.doc,
    required this.communityId,
    required this.uid,
  });

  @override
  State<_TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<_TaskTile>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  late AnimationController _checkAnim;
  late Animation<double> _checkScale;

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _checkScale =
        CurvedAnimation(parent: _checkAnim, curve: Curves.elasticOut);
  }

  @override
  void dispose() {
    _checkAnim.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool isCompleted) async {
    if (_loading || widget.uid.isEmpty) return;
    setState(() => _loading = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('communities')
          .doc(widget.communityId)
          .collection('tasks')
          .doc(widget.doc.id);

      if (isCompleted) {
        await ref
            .update({'completions.${widget.uid}': FieldValue.delete()});
        _checkAnim.reverse();
      } else {
        await ref.update({
          'completions.${widget.uid}': FieldValue.serverTimestamp(),
        });
        _checkAnim.forward();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Hata: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? '';
    final desc = data['description'] as String? ?? '';
    final deadline = (data['deadline'] as Timestamp?)?.toDate();
    final completions =
        Map<String, dynamic>.from(data['completions'] as Map? ?? {});
    final isCompleted = completions.containsKey(widget.uid);
    final isOverdue = deadline != null &&
        deadline.isBefore(DateTime.now()) &&
        !isCompleted;

    if (isCompleted && _checkAnim.value == 0) _checkAnim.value = 1.0;
    if (!isCompleted && _checkAnim.value == 1.0) _checkAnim.value = 0.0;

    final borderColor = isCompleted
        ? AppColors.turquoise.withValues(alpha: 0.3)
        : isOverdue
            ? Colors.red.withValues(alpha: 0.4)
            : AppColors.gold.withValues(alpha: 0.2);

    final deadlineStr = deadline != null
        ? '${deadline.day}.${deadline.month}.${deadline.year}'
        : null;

    return GestureDetector(
      onTap: () => _toggle(isCompleted),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isCompleted ? 0.65 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isCompleted
                ? const Color(0xFF111827)
                : const Color(0xFF1A2035),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: AppColors.turquoise, strokeWidth: 2),
                      )
                    : ScaleTransition(
                        scale: _checkScale,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? AppColors.turquoise
                                : Colors.transparent,
                            border: Border.all(
                              color: isCompleted
                                  ? AppColors.turquoise
                                  : isOverdue
                                      ? Colors.red
                                      : Colors.white38,
                              width: 1.5,
                            ),
                          ),
                          child: isCompleted
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14)
                              : null,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.notoSans(
                        color: isCompleted ? Colors.white54 : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration:
                            isCompleted ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.white38,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        desc,
                        style: GoogleFonts.notoSans(
                          color: Colors.white38,
                          fontSize: 11,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (deadlineStr != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            isOverdue
                                ? Icons.warning_amber_rounded
                                : Icons.schedule_rounded,
                            size: 11,
                            color: isOverdue ? Colors.red : Colors.white24,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isOverdue
                                ? 'Süresi geçti · $deadlineStr'
                                : 'Son: $deadlineStr',
                            style: GoogleFonts.notoSans(
                              color:
                                  isOverdue ? Colors.red : Colors.white24,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
