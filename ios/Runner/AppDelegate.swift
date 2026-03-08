import Flutter
import UIKit
import ImageIO

@main
@objc class AppDelegate: FlutterAppDelegate {
    private let methodChannelName = "dev.quervq.photoapp/swift"
    private var methodChannel: FlutterMethodChannel?
    private weak var currentArVC: ARViewController?
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

        let channel = FlutterMethodChannel(
            name: methodChannelName,
            binaryMessenger: flutterVC.binaryMessenger
        )
        self.methodChannel = channel

        // Flutter 側から呼ばれた時の処理
        channel.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else {
                result(FlutterMethodNotImplemented)
                return
            }

            switch call.method {
            case "switchArMode":
                if let args = call.arguments as? [String: Any],
                   let path = args["path"] as? String {
                    self.showAR(withImagePath: path, from: flutterVC)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "path is required", details: nil))
                }

            case "openArRoom":
                if let args = call.arguments as? [String: Any],
                   let path = args["path"] as? String {
                    let roomId = args["roomId"] as? String
                    let worldMapData = (args["worldMapData"] as? FlutterStandardTypedData)?.data
                    self.showArRoom(withImagePath: path, roomId: roomId, worldMapData: worldMapData, from: flutterVC)
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGS", message: "path is required", details: nil))
                }

            case "addRemotePlacement":
                if let args = call.arguments as? [String: Any] {
                    self.currentArVC?.addRemotePlacement(args)
                }
                result(nil)

            case "dismissAr":
                if let arVC = self.currentArVC {
                    arVC.dismiss(animated: true)
                    self.currentArVC = nil
                }
                result(nil)

            case "getExifData":
                if let args = call.arguments as? [String: Any],
                   let path = args ["path"] as? String {
                    self.getExif(withImagePath: path, result: result)
                } else {
                    result(FlutterMethodNotImplemented)
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    private func showAR(withImagePath path: String, from vc: UIViewController) {
        let arVC = ARViewController()
        arVC.imagePath = path
        vc.present(arVC, animated: true)
    }

    private func showArRoom(withImagePath path: String, roomId: String?, worldMapData: Data?, from vc: UIViewController) {
        let arVC = ARViewController()
        arVC.imagePath = path
        arVC.roomId = roomId
        arVC.methodChannel = self.methodChannel
        arVC.initialWorldMapData = worldMapData
        self.currentArVC = arVC
        vc.present(arVC, animated: true)
    }

    func getExif(withImagePath path: String, result: @escaping FlutterResult) {
        let gtex = GetExif()
        gtex.imagePath = path
        let exifData = gtex.getExif()
        result(exifData)
    }
}
