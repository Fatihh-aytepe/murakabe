import 'package:uuid/uuid.dart';
import '../local/database_helper.dart';
import '../local/local_storage.dart';
import '../models/custom_task_model.dart';
import '../remote/firebase_service.dart';
import '../../core/services/notification_service.dart';

class CustomTaskRepository {
  final _db = DatabaseHelper();
  final _firebase = FirebaseService();
  final _storage = LocalStorage();

  String? get _uid => _storage.userId;

  Future<List<CustomTaskModel>> getAllTasks() async {
    final rows =
        await _db.query('custom_tasks', where: null, orderBy: 'createdAt ASC');
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final completions = await _db.query('custom_task_completions',
        where: 'completedDate = ?', whereArgs: [today]);
    final completedIds =
        completions.map((r) => r['taskId'] as String).toSet();

    return rows.map((r) {
      final task = CustomTaskModel.fromMap(r);
      task.completedToday = completedIds.contains(task.id);
      return task;
    }).toList();
  }

  Future<List<CustomTaskModel>> getActiveTasks() async {
    final all = await getAllTasks();
    return all.where((t) => t.isActive).toList();
  }

  Future<void> addTask(CustomTaskModel task) async {
    await _db.insert('custom_tasks', task.toMap());
    if (_uid != null) {
      try {
        await _firebase.saveTask(_uid!, task.toMap());
      } catch (_) {}
    }
    if (task.notificationTime.isNotEmpty) {
      await _scheduleTaskNotification(task);
    }
  }

  Future<void> updateTask(CustomTaskModel task) async {
    await _db.update('custom_tasks', task.toMap(),
        where: 'id = ?', whereArgs: [task.id]);
    if (_uid != null) {
      try {
        await _firebase.saveTask(_uid!, task.toMap());
      } catch (_) {}
    }
    await NotificationService().cancelNotification(_taskNotifId(task.id));
    if (task.isActive && task.notificationTime.isNotEmpty) {
      await _scheduleTaskNotification(task);
    }
  }

  Future<void> deleteTask(String taskId) async {
    await _db.delete('custom_tasks', where: 'id = ?', whereArgs: [taskId]);
    await _db.delete('custom_task_completions',
        where: 'taskId = ?', whereArgs: [taskId]);
    if (_uid != null) {
      try {
        await _firebase.deleteTask(_uid!, taskId);
      } catch (_) {}
    }
    await NotificationService().cancelNotification(_taskNotifId(taskId));
  }

  Future<void> markTaskCompleted(String taskId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final existing = await _db.query(
      'custom_task_completions',
      where: 'taskId = ? AND completedDate = ?',
      whereArgs: [taskId, today],
    );
    if (existing.isEmpty) {
      final completion = {
        'id': const Uuid().v4(),
        'taskId': taskId,
        'completedDate': today,
        'completedAt': DateTime.now().toIso8601String(),
      };
      await _db.insert('custom_task_completions', completion);
      if (_uid != null) {
        try {
          await _firebase.saveTaskCompletion(_uid!, completion);
        } catch (_) {}
      }
    }
  }

  Future<void> unmarkTaskCompleted(String taskId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _db.delete('custom_task_completions',
        where: 'taskId = ? AND completedDate = ?', whereArgs: [taskId, today]);
  }

  Future<void> _scheduleTaskNotification(CustomTaskModel task) async {
    final parts = task.notificationTime.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]) ?? 9;
    final minute = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }
    await NotificationService().scheduleCustomReminder(
      _taskNotifId(task.id),
      '${task.emoji} ${task.title}',
      task.description.isNotEmpty
          ? task.description
          : 'Gunluk gorev seni bekliyor',
      scheduledTime,
    );
  }

  int _taskNotifId(String taskId) => 2000 + taskId.hashCode.abs() % 1000;
}
