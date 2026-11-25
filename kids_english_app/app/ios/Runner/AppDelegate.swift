import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerBackupChannel(engineBridge.pluginRegistry)
  }

  /// Kênh "kids_english/backup": đánh dấu thư mục (gói chủ đề tải về) KHÔNG sao lưu iCloud.
  /// Apple yêu cầu nội dung tải lại được không được nằm trong bản sao lưu (lý do hay bị từ chối khi duyệt).
  private func registerBackupChannel(_ registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "KidsEnglishBackup") else { return }
    let channel = FlutterMethodChannel(name: "kids_english/backup", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup", let path = call.arguments as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      var url = URL(fileURLWithPath: path, isDirectory: true)
      do {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        result(true)
      } catch {
        result(FlutterError(code: "backup", message: error.localizedDescription, details: nil))
      }
    }
  }
}
