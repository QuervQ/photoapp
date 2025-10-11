import UIKit
import RealityKit
import ARKit

class ARViewController: UIViewController {
    var imagePath :String?
    override func viewDidLoad() {
        super.viewDidLoad()
        let anchor = AnchorEntity(world: [0,-0.5,-1])
        let plane = ModelEntity(mesh: .generatePlane(width: 0.2, height: 0.3))
        let arView = ARView(frame: view.bounds)
        let configuration = ARWorldTrackingConfiguration();
        
        if let path = imagePath,
           let url = URL(string: "file://\(path)"),
           let texture = try? TextureResource.load(contentsOf: url) {
            
            var imageMaterial = UnlitMaterial()
            
            if #available(iOS 15.0, *) {
                // iOS15 以降: color の型は UnlitMaterial.ColorParameter
                imageMaterial.color = .init(tint: .white, texture: .init(texture))
            } else {
                // iOS14以前: baseColor を使う
                imageMaterial.baseColor = MaterialColorParameter.texture(texture)
            }
            
            plane.model?.materials = [imageMaterial]
        }

        // 幅0.2m、高さ0.3mの板メッシュからモデルをつくる。
        plane.transform = Transform(pitch: 0, yaw: 1, roll: 0)
        view.addSubview(arView)
        anchor.addChild(plane)
        configuration.planeDetection = [.horizontal, .vertical]
        arView.scene.anchors.append(anchor)
        arView.session.run(configuration)
    }
}

