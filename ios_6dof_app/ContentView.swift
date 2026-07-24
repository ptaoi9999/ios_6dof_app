import SwiftUI
import RealityKit
import ARKit

// 左右の目を識別する列挙型
enum Eye {
    case left
    case right
}

// ARKitを利用して6DoF（位置＋回転）トラッキングを管理するクラス
class ARTracker: NSObject, ObservableObject, ARSessionDelegate {
    let session = ARSession()
    
    // カメラの最新のTransform（4x4行列）
    @Published var cameraTransform: simd_float4x4 = matrix_identity_float4x4
    
    override init() {
        super.init()
        session.delegate = self
        startSession()
    }
    
    func startSession() {
        // デバイスがARKitに対応しているか確認
        guard ARWorldTrackingConfiguration.isSupported else {
            print("ARKit is not supported on this device")
            return
        }
        
        let configuration = ARWorldTrackingConfiguration()
        // 重力と方角を基準にしてアライメントを取る
        configuration.worldAlignment = .gravityAndHeading
        
        // 不要な処理を無効にしてビルド・実行を高速化
        configuration.planeDetection = []
        
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // 端末の向き（横画面）に対応したARKitカメラのTransformを反映
        DispatchQueue.main.async {
            self.cameraTransform = frame.camera.transform
        }
    }
}

struct ContentView: View {
    // アプリ全体で共有するARKitトラッカー
    @StateObject private var tracker = ARTracker()
    
    var body: some View {
        HStack(spacing: 0) {
            // 左目用ビューポート
            VRViewContainer(eye: .left, tracker: tracker)
            
            // 中央の区切り線（ゴーグル内の仕切りに合わせる）
            Divider()
                .background(Color.black)
                .frame(width: 2)
            
            // 右目用ビューポート
            VRViewContainer(eye: .right, tracker: tracker)
        }
        .edgesIgnoringSafeArea(.all)
        .background(Color.black)
    }
}

struct VRViewContainer: UIViewRepresentable {
    let eye: Eye
    @ObservedObject var tracker: ARTracker
    
    func makeUIView(context: Context) -> ARView {
        // 非ARモードでARViewを初期化（リアカメラ映像は表示せず、VR空間のCGのみを描画）
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        
        // 1. シーンの構築 (左右それぞれ同じ空間を再現する)
        setupVRScene(arView: arView)
        
        // 2. カスタムカメラの設定
        let cameraEntity = PerspectiveCamera()
        cameraEntity.camera.fieldOfViewInDegrees = 85 // VRゴーグル向けの広視野角
        cameraEntity.name = "vrCamera"
        
        // カメラアンカーを作成して追加
        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(cameraEntity)
        arView.scene.addAnchor(cameraAnchor)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // ARKitが算出した最新の6DoF位置・回転をカメラEntityに適用
        if let camera = uiView.scene.findEntity(named: "vrCamera") {
            let baseTransform = tracker.cameraTransform
            
            // 左右の目のオフセット（瞳孔間距離 IPD: 約 6.4cm -> 左右に 3.2cm ずつずらす）
            let ipdOffset: Float = (eye == .left) ? -0.032 : 0.032
            
            // ローカル座標のX軸方向に目の幅をずらすための平行移動行列
            var eyeTranslation = matrix_identity_float4x4
            eyeTranslation.columns.3 = simd_make_float4(ipdOffset, 0, 0, 1)
            
            // 端末位置・回転（世界座標）に対して、目の幅のオフセットをローカル座標系で適用
            camera.transform.matrix = baseTransform * eyeTranslation
        }
    }
    
    // VR空間内の簡易オブジェクト配置（家のような空間を想定）
    private func setupVRScene(arView: ARView) {
        let anchor = AnchorEntity(world: .zero)
        
        // 前方 (Z = -2m): 青い立方体
        let frontBox = createColorBox(color: .blue, size: 0.8)
        frontBox.position = [0, 0, -2]
        anchor.addChild(frontBox)
        
        // 後方 (Z = 2m): 赤い立方体
        let backBox = createColorBox(color: .red, size: 0.8)
        backBox.position = [0, 0, 2]
        anchor.addChild(backBox)
        
        // 左方 (X = -2m): 緑の立方体
        let leftBox = createColorBox(color: .green, size: 0.8)
        leftBox.position = [-2, 0, 0]
        anchor.addChild(leftBox)
        
        // 右方 (X = 2m): 黄色の立方体
        let rightBox = createColorBox(color: .yellow, size: 0.8)
        rightBox.position = [2, 0, 0]
        anchor.addChild(rightBox)
        
        // 床 (Y = -1.2m): グレーの平面
        let floorMesh = MeshResource.generateBox(width: 20, height: 0.1, depth: 20)
        let floorMaterial = SimpleMaterial(color: .darkGray, isMetallic: false)
        let floorEntity = ModelEntity(mesh: floorMesh, materials: [floorMaterial])
        floorEntity.position = [0, -1.2, 0]
        anchor.addChild(floorEntity)
        
        arView.scene.addAnchor(anchor)
    }
    
    private func createColorBox(color: UIColor, size: Float) -> ModelEntity {
        let mesh = MeshResource.generateBox(size: size)
        let material = SimpleMaterial(color: color, isMetallic: true)
        return ModelEntity(mesh: mesh, materials: [material])
    }
}

#Preview {
    ContentView()
}
