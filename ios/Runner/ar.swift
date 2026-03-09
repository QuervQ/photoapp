import UIKit
import RealityKit
import ARKit
import Flutter

@MainActor
class ARViewController: UIViewController, ARSessionDelegate {
    var imagePath: String?
    var roomId: String?
    var methodChannel: FlutterMethodChannel?
    var arView: ARView!

    /// 初期WorldMapデータ（Flutter側からセットされる）
    var initialWorldMapData: Data?

    /// リローカライゼーション状態
    private var isRelocalized = false

    /// トラッキングが一度でも .normal に達したか（ステータス表示の制御用）
    private var hasReachedNormal = false

    /// ステータスラベル
    private var statusLabel: UILabel!

    /// 閉じるボタン
    private var closeButton: UIButton!

    /// WorldMap保存ボタン
    private var saveMapButton: UIButton!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        MainActor.assumeIsolated {
            setupArView()
            setupUI()
            startSession()
        }
    }

    private func setupArView() {
        arView = ARView(frame: view.bounds)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        arView.automaticallyConfigureSession = false
        view.addSubview(arView)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tapGesture)

        arView.session.delegate = self

        // LiDARメッシュによるオクルージョンを有効化（物の裏に回ると画像が隠れる）
        arView.environment.sceneUnderstanding.options.insert(.occlusion)

        #if DEBUG
        arView.debugOptions = [
            .showAnchorOrigins
        ]
        #endif
    }

    private func setupUI() {
        // ステータスラベル（上部）
        statusLabel = UILabel()
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        statusLabel.textColor = .white
        statusLabel.textAlignment = .center
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.numberOfLines = 2
        statusLabel.layer.cornerRadius = 8
        statusLabel.clipsToBounds = true
        view.addSubview(statusLabel)

        // 閉じるボタン（左上）
        closeButton = UIButton(type: .system)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setTitle("✕ 閉じる", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.backgroundColor = UIColor.red.withAlphaComponent(0.7)
        closeButton.layer.cornerRadius = 8
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        // WorldMap保存ボタン（右上）
        saveMapButton = UIButton(type: .system)
        saveMapButton.translatesAutoresizingMaskIntoConstraints = false
        saveMapButton.setTitle("📍 マップ保存", for: .normal)
        saveMapButton.setTitleColor(.white, for: .normal)
        saveMapButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.7)
        saveMapButton.layer.cornerRadius = 8
        saveMapButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        saveMapButton.addTarget(self, action: #selector(saveWorldMapTapped), for: .touchUpInside)
        view.addSubview(saveMapButton)

        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),

            closeButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),

            saveMapButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 8),
            saveMapButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

        updateStatus("壁をスキャン中...")
    }

    private func startSession() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.vertical]

        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
        }
        configuration.environmentTexturing = .automatic

        // 既存のWorldMapがあればセッションに読み込む（リローカライゼーション）
        if let mapData = initialWorldMapData {
            do {
                let worldMap = try NSKeyedUnarchiver.unarchivedObject(
                    ofClass: ARWorldMap.self, from: mapData
                )
                if let worldMap = worldMap {
                    configuration.initialWorldMap = worldMap
                    updateStatus("リローカライゼーション中...\nデバイスをゆっくり動かしてください")
                    print("🗺️ WorldMapを読み込みました（アンカー数: \(worldMap.anchors.count)）")
                }
            } catch {
                print("⚠️ WorldMap読み込み失敗: \(error)")
                updateStatus("壁をスキャン中...")
            }
        }

        arView.session.run(configuration)
    }

    // MARK: - ARSessionDelegate

    /// 毎フレーム呼ばれるデリゲート — ここでトラッキング状態とマッピング状態の両方を処理
    /// cameraDidChangeTrackingState は ARView では発火しないケースがあるため、
    /// didUpdate frame: 内で frame.camera.trackingState を直接チェックする。
    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            // --- トラッキング状態（リローカライゼーション検出） ---
            let tracking = frame.camera.trackingState
            switch tracking {
            case .normal:
                if !hasReachedNormal {
                    hasReachedNormal = true
                    if initialWorldMapData != nil && !isRelocalized {
                        isRelocalized = true
                        updateStatus("✅ リローカライゼーション成功！\n壁をタップで画像を配置")
                        methodChannel?.invokeMethod("onRelocalized", arguments: nil)
                        print("✅ リローカライゼーション成功: 同じ部屋を検出")
                    } else if initialWorldMapData == nil {
                        updateStatus("✅ 壁をタップで画像を配置")
                    }
                }
            case .limited(let reason):
                if !hasReachedNormal {
                    switch reason {
                    case .relocalizing:
                        updateStatus("🔍 リローカライゼーション中...\n元の部屋でデバイスをゆっくり動かしてください")
                    case .initializing:
                        updateStatus("初期化中...\nデバイスをゆっくり動かしてください")
                    case .excessiveMotion:
                        updateStatus("⚠️ デバイスの動きが速すぎます")
                    case .insufficientFeatures:
                        updateStatus("⚠️ 特徴点不足\nもう少し明るい場所で動かしてください")
                    @unknown default:
                        updateStatus("スキャン中...")
                    }
                }
            case .notAvailable:
                break
            }

            // --- マッピング状態（保存ボタンの有効化のみ） ---
            let mapping = frame.worldMappingStatus
            switch mapping {
            case .mapped, .extending:
                saveMapButton.isEnabled = true
            default:
                saveMapButton.isEnabled = false
            }
        }
    }

    // MARK: - Tap to Place

    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        // WorldMapを読み込んでいるがまだリローカライゼーション未完了の場合はブロック
        if initialWorldMapData != nil && !isRelocalized {
            showAlert(message: "リローカライゼーション中です。\n元の部屋と同じ場所でデバイスをゆっくり動かしてください。")
            return
        }

        let location = sender.location(in: arView)

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

        let anchor = AnchorEntity(world: result.worldTransform)

        let aspectRatio = Float(texture.width) / Float(texture.height)
        let width: Float = 0.6
        let height: Float = width / aspectRatio

        let plane = createImagePlane(texture: texture, width: width, height: height)
        anchor.addChild(plane)
        arView.scene.anchors.append(anchor)

        // サーバーに送信
        if let channel = methodChannel, roomId != nil {
            let t = result.worldTransform
            let transformArray: [Double] = [
                Double(t.columns.0.x), Double(t.columns.0.y), Double(t.columns.0.z), Double(t.columns.0.w),
                Double(t.columns.1.x), Double(t.columns.1.y), Double(t.columns.1.z), Double(t.columns.1.w),
                Double(t.columns.2.x), Double(t.columns.2.y), Double(t.columns.2.z), Double(t.columns.2.w),
                Double(t.columns.3.x), Double(t.columns.3.y), Double(t.columns.3.z), Double(t.columns.3.w),
            ]
            channel.invokeMethod("onPlacementCreated", arguments: [
                "transform": transformArray,
                "width_m": Double(width),
                "height_m": Double(height),
            ])
        }

        print("✅ 配置完了 - サイズ: \(width)m x \(height)m")
    }

    // MARK: - Remote Placement (他ユーザーの配置 / 永続化復元)

    /// リモート配置を追加する
    /// data: { "transform": [16 doubles], "width_m": double, "height_m": double, "image_path": String }
    func addRemotePlacement(_ data: [String: Any]) {
        guard let transformArr = data["transform"] as? [Double], transformArr.count == 16,
              let widthM = data["width_m"] as? Double,
              let heightM = data["height_m"] as? Double,
              let localImagePath = data["image_path"] as? String else {
            print("⚠️ リモート配置データが不正: \(data)")
            return
        }

        let fileURL = URL(fileURLWithPath: localImagePath)
        guard let texture = try? TextureResource.load(contentsOf: fileURL) else {
            print("⚠️ リモート配置の画像読み込み失敗: \(localImagePath)")
            return
        }

        // 4x4 matrixを再構築
        let matrix = simd_float4x4(
            SIMD4<Float>(Float(transformArr[0]), Float(transformArr[1]), Float(transformArr[2]), Float(transformArr[3])),
            SIMD4<Float>(Float(transformArr[4]), Float(transformArr[5]), Float(transformArr[6]), Float(transformArr[7])),
            SIMD4<Float>(Float(transformArr[8]), Float(transformArr[9]), Float(transformArr[10]), Float(transformArr[11])),
            SIMD4<Float>(Float(transformArr[12]), Float(transformArr[13]), Float(transformArr[14]), Float(transformArr[15]))
        )

        let anchor = AnchorEntity(world: matrix)

        let plane = createImagePlane(
            texture: texture,
            width: Float(widthM),
            height: Float(heightM)
        )
        anchor.addChild(plane)
        arView.scene.anchors.append(anchor)

        print("📨 リモート配置を描画: \(widthM)m x \(heightM)m")
    }

    // MARK: - WorldMap Save

    @objc func saveWorldMapTapped() {
        saveMapButton.isEnabled = false
        updateStatus("マップ保存中...")

        arView.session.getCurrentWorldMap { [weak self] worldMap, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.saveMapButton.isEnabled = true

                guard let worldMap = worldMap else {
                    self.updateStatus("⚠️ マップ取得に失敗")
                    print("WorldMap取得失敗: \(error?.localizedDescription ?? "unknown")")
                    return
                }

                do {
                    let data = try NSKeyedArchiver.archivedData(
                        withRootObject: worldMap,
                        requiringSecureCoding: true
                    )
                    // Flutterに送信（Flutterがサーバーにアップロード）
                    self.methodChannel?.invokeMethod("onWorldMapCaptured", arguments: [
                        "data": FlutterStandardTypedData(bytes: data),
                        "anchor_count": worldMap.anchors.count,
                    ])
                    self.updateStatus("✅ マップ保存完了（アンカー: \(worldMap.anchors.count)）")
                    print("🗺️ WorldMap保存: \(data.count) bytes, アンカー: \(worldMap.anchors.count)")
                } catch {
                    self.updateStatus("⚠️ マップ保存エラー")
                    print("WorldMapアーカイブ失敗: \(error)")
                }
            }
        }
    }

    // MARK: - Close

    @objc func closeTapped() {
        dismiss(animated: true)
    }

    // MARK: - Helpers

    private func createImagePlane(texture: TextureResource, width: Float, height: Float) -> ModelEntity {
        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))

        let plane = ModelEntity(
            mesh: .generatePlane(width: width, height: height),
            materials: [material]
        )

        // X軸-90度 + Z軸-90度で壁面に平行に配置
        let rotationX = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(1, 0, 0))
        let rotationZ = simd_quatf(angle: -.pi / 2, axis: SIMD3<Float>(0, 0, 1))
        plane.transform.rotation = rotationX * rotationZ

        // 壁から3cm手前（LiDARメッシュに隠されない距離）
        plane.position.z = 0.03

        plane.generateCollisionShapes(recursive: false)

        return plane
    }

    private func updateStatus(_ text: String) {
        statusLabel.text = "  \(text)  "
    }

    private func showAlert(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Lifecycle

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard let arView = arView else { return }
        arView.session.pause()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isBeingDismissed {
            methodChannel?.invokeMethod("onArDismissed", arguments: nil)
        }
    }
}
