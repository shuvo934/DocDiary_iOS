import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    // BEGIN DOCDIARY DYNAMIC PREVIEW
    if let previewRegistrar = registrar(forPlugin: "DocDiaryDynamicPreviewPlugin") {
      DocDiaryDynamicPreviewPlugin.register(with: previewRegistrar)
    }
    // END DOCDIARY DYNAMIC PREVIEW
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
