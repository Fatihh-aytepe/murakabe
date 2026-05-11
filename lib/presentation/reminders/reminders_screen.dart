import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../data/local/database_helper.dart';
import '../../core/services/notification_service.dart';

class ReminderModel {
  final String id;
  final String title;
  final String content;
  final DateTime reminderTime;
  final bool isActive;

  ReminderModel({
    required this.id,
    required this.title,
    required this.content,
    required this.reminderTime,
    required this.isActive,
  });

  factory ReminderModel.fromMap(Map<String, dynamic> m) => ReminderModel(
        id: m['id'],
        title: m['title'],
        content: m['content'],
        reminderTime: DateTime.parse(m['reminderTime']),
        isActive: m['isActive'] == 1,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'content': content,
        'reminderTime': reminderTime.toIso8601String(),
        'isActive': isActive ? 1 : 0,
        'createdAt': DateTime.now().toIso8601String(),
      };
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _db = DatabaseHelper();
  List<ReminderModel> _reminders = [];

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final rows = await _db.query('reminders', orderBy: 'reminderTime ASC');
    if (mounted) {
      setState(() {
        _reminders = rows.map((r) => ReminderModel.fromMap(r)).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadReminders,
        color: AppColors.gold,
        child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B)],
                ),
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              child: Text(
                'Hatırlatıcılar',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 26,
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          if (_reminders.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.alarm_outlined,
                        size: 64, color: AppColors.textLight.withValues(alpha: 0.4)),
                    const SizedBox(height: 12),
                    Text(
                      'Henüz hatırlatıcı yok',
                      style: GoogleFonts.notoSans(color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _buildReminderCard(_reminders[i]),
                  childCount: _reminders.length,
                ),
              ),
            ),
        ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddReminderSheet,
        backgroundColor: AppColors.gold,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildReminderCard(ReminderModel reminder) {
    final isPast = reminder.reminderTime.isBefore(DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.08),
            blurRadius: 10,
          ),
        ],
        border: Border(
          left: BorderSide(
            color: isPast
                ? AppColors.textLight
                : reminder.isActive
                    ? AppColors.gold
                    : AppColors.textLight,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reminder.title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isPast ? AppColors.textLight : AppColors.textPrimary,
                  ),
                ),
                if (reminder.content.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    reminder.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.notoSans(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.access_time,
                        size: 14,
                        color:
                            isPast ? AppColors.textLight : AppColors.turquoise),
                    const SizedBox(width: 4),
                    Text(
                      _formatDateTime(reminder.reminderTime),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isPast ? AppColors.textLight : AppColors.turquoise,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isPast) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.textLight.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Geçti',
                          style: TextStyle(
                              fontSize: 10, color: AppColors.textLight),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            onPressed: () => _deleteReminder(reminder),
          ),
        ],
      ),
    );
  }

  void _showAddReminderSheet() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(hours: 1));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tutamaç
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.textLight.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Text(
                  'Hatırlatıcı Ekle',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // Başlık
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Konu / Başlık',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 12),

                // İçerik
                TextField(
                  controller: contentCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'İçerik (isteğe bağlı)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.notes),
                  ),
                ),
                const SizedBox(height: 12),

                // Tarih/saat seç
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      if (!ctx.mounted) return;
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(selectedDate),
                      );
                      if (time != null) {
                        setSheetState(() {
                          selectedDate = DateTime(date.year, date.month,
                              date.day, time.hour, time.minute);
                        });
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: AppColors.textLight.withValues(alpha: 0.4)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time,
                            color: AppColors.turquoise),
                        const SizedBox(width: 10),
                        Text(
                          _formatDateTime(selectedDate),
                          style: GoogleFonts.notoSans(
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right,
                            color: AppColors.textLight),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Kaydet butonu
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      final reminder = ReminderModel(
                        id: const Uuid().v4(),
                        title: titleCtrl.text.trim(),
                        content: contentCtrl.text.trim(),
                        reminderTime: selectedDate,
                        isActive: true,
                      );
                      await _db.insert('reminders', reminder.toMap());
                      // Bildirim planla
                      await _scheduleReminderNotification(reminder);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      await _loadReminders();
                    },
                    child: const Text('Hatırlatıcı Kur'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _scheduleReminderNotification(ReminderModel reminder) async {
    final notifId = reminder.id.hashCode.abs() % 1000 + 1000;
    await NotificationService().scheduleCustomReminder(
      notifId,
      reminder.title,
      reminder.content.isNotEmpty ? reminder.content : reminder.title,
      reminder.reminderTime,
    );
  }

  Future<void> _deleteReminder(ReminderModel reminder) async {
    await _db.delete('reminders', where: 'id = ?', whereArgs: [reminder.id]);
    await _loadReminders();
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      '',
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
