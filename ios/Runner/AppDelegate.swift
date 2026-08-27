import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // flutter_local_notifications'ın kendi kurulum talimatı: bu delegate
    // atanmazsa uygulama ÖN PLANDAYKEN gelen bildirimler iOS'ta hiç
    // gösterilmez (yalnızca arka planda/kapalıyken görünür). Önceden bu
    // dosyada yoktu — Android tarafında zaten çalışan namaz vakti/görev
    // bildirimleri, uygulama açıkken iOS'ta sessizce kaybolurdu.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
