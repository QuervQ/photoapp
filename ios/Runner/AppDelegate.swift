import Flutter
import UIKit
import ImageIO

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let methodChannelName = "com.QuervQ.photoapp/swift"
    var imagePath : String?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        GeneratedPluginRegistrant.register(with: self)

        // Flutter の rootViewController を取得
        guard let flutterVC = window?.rootViewController as? FlutterViewController else {
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        let methodChannel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: flutterVC.binaryMessenger
        )

        // Flutter 側から呼ばれた時の処理
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "switchArMode",let args = call.arguments as? [String: Any],
            let path = args["path"]as? String{
                self?.showAR(withImagePath: path, from: flutterVC)
                result(nil)
            }
            else if call.method == "getExif",
                    let args = call.arguments as? [String: Any],
                    let path = args ["path"] as? String {
                
            }
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func showAR(withImagePath path:String, from vc: UIViewController) {
        let arVC = ARViewController()
        arVC.imagePath = path
        vc.present(arVC, animated: true)
    }
}

