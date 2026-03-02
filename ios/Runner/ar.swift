import UIKit
import RealityKit
import ARKit

@MainActor
class ARViewController: UIViewController {
    var imagePath: String?
    var arView: ARView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // ARViewの初期化（明示的にメインスレッドで実行）
        MainActor.assumeIsolated {
            arView = ARView(frame: view.bounds)
            arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            arView.automaticallyConfigureSession = false
            view.addSubview(arView)
            
            // タップジェスチャーを追加
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            arView.addGestureRecognizer(tapGesture)
            
            // AR設定
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = [.vertical]
            
            // LiDARによるシーン再構築とオクルージョン
            if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                configuration.sceneReconstruction = .mesh
            }
            
            configuration.environmentTexturing = .automatic
            
            arView.session.run(configuration)
            
            // オクルージョン（遮蔽）を有効化
            // LiDARでスキャンした物理環境が仮想オブジェクトを隠すようにする
            arView.environment.sceneUnderstanding.options.insert(.occlusion)
            
            #if DEBUG
            arView.debugOptions = [
                .showSceneUnderstanding,
                .showAnchorOrigins
            ]
            #endif
        }
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: arView)
        
        // 垂直面（壁）に対してレイキャスト
        let results = arView.raycast(
            from: location,
            allowing: .existingPlaneGeometry,
            alignment: .vertical
        )
        
        if let firstResult = results.first {
            placeImage(at: firstResult)
        } else {
            showAlert(message: "壁が検出されませんでした。デバイスをゆっくり動かして壁をスキャンしてください。")
        }
    }
    
    func placeImage(at result: ARRaycastResult) {
        guard let path = imagePath else {
            showAlert(message: "画像パスが設定されていません")
            return
        }
        
        let fileURL = URL(fileURLWithPath: path)
        
        guard let texture = try? TextureResource.load(contentsOf: fileURL) else {
            showAlert(message: "画像の読み込みに失敗しました")
            return
        }
        
        // アンカーを作成（worldTransformをそのまま使用 - 壁の向きを保持）
        let anchor = AnchorEntity(world: result.worldTransform)
        
        // デバッグ: 大きな球体を追加して位置を確認
        #if DEBUG
        let debugSphere = ModelEntity(
            mesh: .generateSphere(radius: 0.05),
            materials: [SimpleMaterial(color: .cyan, isMetallic: false)]
        )
        anchor.addChild(debugSphere)
        print("🔵 デバッグ球体を追加")
        #endif
        
        // 画像サイズを計算（大きめに）
        let aspectRatio = Float(texture.width) / Float(texture.height)
        let width: Float = 0.6  // 60cmに拡大
        let height: Float = width / aspectRatio
        
        print("📐 画像サイズ: \(width)m x \(height)m, アスペクト比: \(aspectRatio)")
        
        // 平面エンティティを作成
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        
        let plane = ModelEntity(
            mesh: .generatePlane(width: width, height: height),
            materials: [material]
        )
        
        // X軸周りに-90度回転
        let rotationX = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        // Z軸周りに-90度回転
        let rotationZ = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 0, 1))
        // 回転を合成
        plane.transform.rotation = rotationX * rotationZ
        
        // 壁から1cm手前に配置
        plane.position.z = 0.01
        
        print("🔍 X軸-90度 + Z軸-90度回転で配置")
        
        // 衝突検出を有効化（オクルージョンに必要）
        plane.generateCollisionShapes(recursive: false)
        
        anchor.addChild(plane)
        arView.scene.anchors.append(anchor)
        
        print("🛡️ オクルージョン有効 - 壁の裏では画像が隠れます")
        print("✅ 配置完了 - サイズ: \(width)m x \(height)m")
    }
    
    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let arView = arView else { return }
        arView.session.pause()
    }
}
