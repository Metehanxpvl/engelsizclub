import Flutter
import UIKit
import UserNotifications

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let response = connectionOptions.notificationResponse {
      PushLaunchBridge.persist(response.notification.request.content.userInfo)
    }
    UIApplication.shared.registerForRemoteNotifications()
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    UNUserNotificationCenter.current().delegate =
      UIApplication.shared.delegate as? UNUserNotificationCenterDelegate
    UIApplication.shared.registerForRemoteNotifications()
  }
}
