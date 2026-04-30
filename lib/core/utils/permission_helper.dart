import 'package:permission_handler/permission_handler.dart';
import '../services/notification_service.dart';

class PermissionHelper {
  static Future<void> requestAllPermissions() async {
    await [
      Permission.notification,
      Permission.scheduleExactAlarm,
      Permission.camera,
      Permission.photos,
    ].request();

    // Android 12+ exact alarm
    await NotificationService().requestExactAlarmPermission();
  }
}
