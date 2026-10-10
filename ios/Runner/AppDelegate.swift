import Flutter
import UIKit
import GoogleMaps
import UserNotifications

enum PushLaunchBridge {
  static let prefsKey = "flutter.fcm_pending_open_v1"

  static func persist(_ userInfo: [AnyHashable: Any]) {
    var out: [String: String] = [:]
    func put(_ key: String, _ value: Any?) {
      let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
      if k.isEmpty { return }
      if let s = value as? String, !s.isEmpty {
        out[k] = s
        out[k.lowercased()] = s
      } else if let n = value as? NSNumber {
        out[k] = n.stringValue
        out[k.lowercased()] = n.stringValue
      }
    }
    for (rawKey, rawVal) in userInfo {
      let key = "\(rawKey)"
      if key == "aps" || key.hasPrefix("gcm.") || key.hasPrefix("google.") {
        continue
      }
      if key == "data", let nested = rawVal as? [AnyHashable: Any] {
        for (nk, nv) in nested { put("\(nk)", nv) }
        continue
      }
      put(key, rawVal)
    }
    if let aps = userInfo["aps"] as? [AnyHashable: Any],
       let alert = aps["alert"] as? [AnyHashable: Any] {
      if out["title"] == nil { put("title", alert["title"]) }
      if out["body"] == nil { put("body", alert["body"]) }
    }
    guard !out.isEmpty else { return }
    guard JSONSerialization.isValidJSONObject(out),
          let data = try? JSONSerialization.data(withJSONObject: out),
          let str = String(data: data, encoding: .utf8) else { return }
    UserDefaults.standard.set(str, forKey: prefsKey)
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("AIzaSyAHDu7hYJInYdPhrg8i0YdEzgfl0lL502o")
    UNUserNotificationCenter.current().delegate = self
    if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      PushLaunchBridge.persist(remote)
    }
    application.registerForRemoteNotifications()
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return ok
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    UNUserNotificationCenter.current().delegate = self
    UIApplication.shared.registerForRemoteNotifications()
  }

  override func applicationDidBecomeActive(_ application: UIApplication) {
    UNUserNotificationCenter.current().delegate = self
    super.applicationDidBecomeActive(application)
  }

  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    PushLaunchBridge.persist(response.notification.request.content.userInfo)
    super.userNotificationCenter(
      center,
      didReceive: response,
      withCompletionHandler: completionHandler
    )
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    NSLog("APNs register failed: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
