import SwiftUI
import RealityKit
import CoreMotion
import ARKit

// 左右の目を識別する列挙型
enum Eye {
    case left
    case right
}

// デバイスの姿勢を管理するクラス
class VRMotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    
    // カメラの回転情報を保持するクォータニオン
    @Published var orientation: simd_quatf = simd_quaternion(1, 0, 0, 0)
    
    init() {
        startTracking()
    }
    
    func startTracking() {
        guard motionManager.isDeviceMotionAvailable else {
            print("Device Motion is not available")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0 // 60 FPS
        motionManager.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            // CoreMotionの姿勢（態度）からクォータニオンを取得
            let attitude = motion.attitude
            let q = attitude.quaternion
            
            // RealityKitの座標系（右手系、Y上、Z手前）に変換
            // スマホが横向き（Landscape Left または Landscape Right）になるため、軸の調整が必要です。
            // ここでは標準的なLandscape Leftを想定して回転を変換します。
            let deviceOrientation = simd_quaternion(Float(q.x), Float(q.y), Float(q.z), Float(q.w))
            
            // VRゴーグル装着状態（横画面）に合わせた補正
            // iOSの縦持ち基準からLandscapeLeftへの変換
            let rotationCompensation = simd_quaternion(Float.pi / 2, simd_make_float3(1, 0, 0)) // ピッチを90度起こす
            let rotationYComp = simd_quaternion(-Float.pi / 2, simd_make_float3(0, 1, 0))     // ヨーの調整
            
            DispatchQueue.main.async {
                self.orientation = rotationYComp * rotationCompensation * deviceOrientation
            }
        }
    }
    
    deinit {
        motionManager.stopDeviceMotionUpdates()
    }
}

struct ContentView: View {
    @StateObject private var motionManager = VRMotionManager()
    
    var body: some View {
        HStack(spacing: 0) {
            // 左目用ビューポート
            VRViewContainer(eye: .left, motionManager: motionManager)
            
            // 中央の区切り線（ゴーグル内の仕切りに合わせる）
            Divider()
                .background(Color.black)
                .frame(width: 2)
            
            // 右目用ビューポート
            VRViewContainer(eye: .right, motionManager: motionManager)
        }
        .edgesIgnoringSafeArea(.all)
        .background(Color.black)
    }
}

struct VRViewContainer: UIViewRepresentable {
    let eye: Eye
    @ObservedObject var motionManager: VRMotionManager
    
    func makeUIView(context: Context) -> ARView {
        // 非ARモードでARViewを初期化
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        
        // 1. シーンの構築 (左右それぞれ同じ空間を再現する)
        setupVRScene(arView: arView)
        
        // 2. カスタムカメラの設定
        let cameraEntity = PerspectiveCamera()
        cameraEntity.camera.fieldOfViewInDegrees = 80 // VRゴーグル向けの広視野角
        
        // 瞳孔間距離 (IPD) の設定 (約 6.4cm -> 左右に 3.2cm ずつオフセット)
        let ipdOffset: Float = (eye == .left) ? -0.032 : 0.032
        cameraEntity.position = [ipdOffset, 0, 0]
        
        // カメラに一意の名前を付与して後から参照できるようにする
        cameraEntity.name = "vrCamera"
        
        // カメラアンカーを作成して追加
        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(cameraEntity)
        arView.scene.addAnchor(cameraAnchor)
        
        // アクティブなカメラに指定
        arView.activeCamera = cameraEntity
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // デバイスの姿勢をカメラの回転に適用
        if let camera = uiView.scene.findEntity(named: "vrCamera") {
            camera.orientation = motionManager.orientation
        }
    }
    
    // VR空間内の簡易オブジェクト配置
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
        
        // 床 (Y = -1.2m): グレーの平面（グリッド状の目安として立方体を薄く平らにしたもの）
        let floorMesh = MeshResource.generateBox(width: 10, height: 0.1, depth: 10)
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
