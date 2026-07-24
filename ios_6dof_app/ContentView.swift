import SwiftUI
import RealityKit
import ARKit
import Vision

// 左右の目を識別する列挙型
enum Eye {
    case left
    case right
}

// ARKit（6DoF）と Vision（ハンドトラッキング）を管理するクラス
class ARTracker: NSObject, ObservableObject, ARSessionDelegate {
    let session = ARSession()
    
    // カメラの最新のTransform
    @Published var cameraTransform: simd_float4x4 = matrix_identity_float4x4
    
    // 検出された手の3D世界座標
    @Published var handPosition: simd_float3? = nil
    // 人差し指と親指がピンチ（つまむ）されているか
    @Published var isPinching: Bool = false
    
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    private var frameCounter = 0
    
    override init() {
        super.init()
        session.delegate = self
        handPoseRequest.maximumHandCount = 1
        startSession()
    }
    
    func startSession() {
        guard ARWorldTrackingConfiguration.isSupported else {
            print("ARKit is not supported on this device")
            return
        }
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = []
        
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // 1. カメラ姿勢の更新
        let transform = frame.camera.transform
        DispatchQueue.main.async {
            self.cameraTransform = transform
        }
        
        // 2. Visionによるハンドトラッキング（負荷軽減のため3フレームに1回処理）
        frameCounter += 1
        if frameCounter % 3 == 0 {
            let pixelBuffer = frame.capturedImage
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
            
            do {
                try handler.perform([handPoseRequest])
                if let observation = handPoseRequest.results?.first {
                    // 人差し指の先端と親指の先端、および手首のポイントを取得
                    let indexPoints = try observation.recognizedPoints(.indexFinger)
                    let thumbPoints = try observation.recognizedPoints(.thumb)
                    
                    if let indexTip = indexPoints[.indexTip], indexTip.confidence > 0.5,
                       let thumbTip = thumbPoints[.thumbTip], thumbTip.confidence > 0.5 {
                        
                        // Vision座標系（左下0,0 ~ 右上1,1）
                        let tipX = Float(indexTip.location.x)
                        let tipY = Float(indexTip.location.y)
                        
                        // カメラ前方 40cm (Z = -0.4m) の平面上に投影
                        // 画像上の位置に応じてX、Y座標をオフセット
                        let localX = (tipX - 0.5) * 0.4
                        let localY = (tipY - 0.5) * 0.4
                        let localPos = simd_make_float4(localX, localY, -0.4, 1.0)
                        
                        // 世界座標に変換
                        let worldPos = transform * localPos
                        
                        // 親指と人差し指の画像上での距離からピンチ判定
                        let distance = simd_distance(
                            simd_make_float2(Float(indexTip.location.x), Float(indexTip.location.y)),
                            simd_make_float2(Float(thumbTip.location.x), Float(thumbTip.location.y))
                        )
                        let pinchDetected = distance < 0.08
                        
                        DispatchQueue.main.async {
                            self.handPosition = simd_make_float3(worldPos.x, worldPos.y, worldPos.z)
                            self.isPinching = pinchDetected
                        }
                    } else {
                        clearHandState()
                    }
                } else {
                    clearHandState()
                }
            } catch {
                print("Hand pose tracking error: \(error)")
                clearHandState()
            }
        }
    }
    
    private func clearHandState() {
        DispatchQueue.main.async {
            self.handPosition = nil
            self.isPinching = false
        }
    }
}

struct ContentView: View {
    @StateObject private var tracker = ARTracker()
    
    var body: some View {
        HStack(spacing: 0) {
            // 左目用
            VRViewContainer(eye: .left, tracker: tracker)
            
            // 境界線
            Divider()
                .background(Color.black)
                .frame(width: 2)
            
            // 右目用
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
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        
        // 1. 家のようなバーチャル空間を構築
        setupVRHouseScene(arView: arView)
        
        // 2. カスタムカメラの設定
        let cameraEntity = PerspectiveCamera()
        cameraEntity.camera.fieldOfViewInDegrees = 85
        cameraEntity.name = "vrCamera"
        
        let cameraAnchor = AnchorEntity(world: .zero)
        cameraAnchor.addChild(cameraEntity)
        arView.scene.addAnchor(cameraAnchor)
        
        // 3. 手のEntity（球体）を設定
        let handMesh = MeshResource.generateSphere(radius: 0.03)
        let handMaterial = SimpleMaterial(color: .white, isMetallic: false)
        let handEntity = ModelEntity(mesh: handMesh, materials: [handMaterial])
        handEntity.name = "vrHand"
        handEntity.scale = .zero // 最初は非表示
        
        let handAnchor = AnchorEntity(world: .zero)
        handAnchor.addChild(handEntity)
        arView.scene.addAnchor(handAnchor)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        // カメラの位置・回転をARKitに同期
        if let camera = uiView.scene.findEntity(named: "vrCamera") {
            let baseTransform = tracker.cameraTransform
            let ipdOffset: Float = (eye == .left) ? -0.032 : 0.032
            
            var eyeTranslation = matrix_identity_float4x4
            eyeTranslation.columns.3 = simd_make_float4(ipdOffset, 0, 0, 1)
            
            camera.transform.matrix = baseTransform * eyeTranslation
        }
        
        // 手の3D球体の位置とインタラクションを更新
        if let hand = uiView.scene.findEntity(named: "vrHand") {
            if let handPos = tracker.handPosition {
                hand.position = handPos
                hand.scale = [1, 1, 1]
                
                // ピンチ時はマテリアルを緑色に変更
                let color: UIColor = tracker.isPinching ? .green : .white
                let material = SimpleMaterial(color: color, isMetallic: tracker.isPinching)
                if var modelComp = hand.components[ModelComponent.self] as? ModelComponent {
                    modelComp.materials = [material]
                    hand.components.set(modelComp)
                }
            } else {
                hand.scale = .zero
            }
        }
    }
    
    // 家のような空間をモデリング
    private func setupVRHouseScene(arView: ARView) {
        let anchor = AnchorEntity(world: .zero)
        
        // 壁のマテリアル（オフホワイト）
        let wallMaterial = SimpleMaterial(color: UIColor(white: 0.9, alpha: 1.0), isMetallic: false)
        
        // 奥の壁 (Z = -5m)
        let backWall = ModelEntity(mesh: MeshResource.generateBox(width: 10, height: 3, depth: 0.1), materials: [wallMaterial])
        backWall.position = [0, 0.3, -5]
        anchor.addChild(backWall)
        
        // 手前の壁 (Z = 5m)
        let frontWall = ModelEntity(mesh: MeshResource.generateBox(width: 10, height: 3, depth: 0.1), materials: [wallMaterial])
        frontWall.position = [0, 0.3, 5]
        anchor.addChild(frontWall)
        
        // 左の壁 (X = -5m)
        let leftWall = ModelEntity(mesh: MeshResource.generateBox(width: 0.1, height: 3, depth: 10), materials: [wallMaterial])
        leftWall.position = [-5, 0.3, 0]
        anchor.addChild(leftWall)
        
        // 右の壁 (X = 5m)
        let rightWall = ModelEntity(mesh: MeshResource.generateBox(width: 0.1, height: 3, depth: 10), materials: [wallMaterial])
        rightWall.position = [5, 0.3, 0]
        anchor.addChild(rightWall)
        
        // 天井 (Y = 1.8m)
        let ceilingMaterial = SimpleMaterial(color: UIColor(white: 0.95, alpha: 1.0), isMetallic: false)
        let ceiling = ModelEntity(mesh: MeshResource.generateBox(width: 10, height: 0.1, depth: 10), materials: [ceilingMaterial])
        ceiling.position = [0, 1.8, 0]
        anchor.addChild(ceiling)
        
        // 床 (Y = -1.2m, 木目調の茶色)
        let floorMaterial = SimpleMaterial(color: UIColor(red: 0.45, green: 0.35, blue: 0.25, alpha: 1.0), isMetallic: false)
        let floor = ModelEntity(mesh: MeshResource.generateBox(width: 10, height: 0.1, depth: 10), materials: [floorMaterial])
        floor.position = [0, -1.2, 0]
        anchor.addChild(floor)
        
        // --- 家具モデリング ---
        let woodMaterial = SimpleMaterial(color: UIColor(red: 0.55, green: 0.38, blue: 0.22, alpha: 1.0), isMetallic: false)
        
        // 中央のテーブル
        let tableTop = ModelEntity(mesh: MeshResource.generateBox(width: 1.6, height: 0.08, depth: 1.0), materials: [woodMaterial])
        tableTop.position = [0, -0.6, -2.0]
        anchor.addChild(tableTop)
        
        // テーブルの脚
        let legMesh = MeshResource.generateBox(width: 0.08, height: 0.6, depth: 0.08)
        let legPositions: [SIMD3<Float>] = [
            [-0.7, -0.9, -2.4], [0.7, -0.9, -2.4],
            [-0.7, -0.9, -1.6], [0.7, -0.9, -1.6]
        ]
        for pos in legPositions {
            let leg = ModelEntity(mesh: legMesh, materials: [woodMaterial])
            leg.position = pos
            anchor.addChild(leg)
        }
        
        // テレビボードとテレビ (奥の壁際)
        let board = ModelEntity(mesh: MeshResource.generateBox(width: 2.2, height: 0.35, depth: 0.45), materials: [woodMaterial])
        board.position = [0, -1.0, -4.5]
        anchor.addChild(board)
        
        let tvMaterial = SimpleMaterial(color: UIColor(white: 0.15, alpha: 1.0), isMetallic: true)
        let tv = ModelEntity(mesh: MeshResource.generateBox(width: 1.4, height: 0.8, depth: 0.05), materials: [tvMaterial])
        tv.position = [0, -0.4, -4.5]
        anchor.addChild(tv)
        
        // ソファ (手前側、テレビと対向)
        let sofaMaterial = SimpleMaterial(color: UIColor(red: 0.25, green: 0.35, blue: 0.45, alpha: 1.0), isMetallic: false)
        let sofaSeat = ModelEntity(mesh: MeshResource.generateBox(width: 2.0, height: 0.4, depth: 0.75), materials: [sofaMaterial])
        sofaSeat.position = [0, -0.9, 1.0]
        anchor.addChild(sofaSeat)
        
        let sofaBack = ModelEntity(mesh: MeshResource.generateBox(width: 2.0, height: 0.8, depth: 0.15), materials: [sofaMaterial])
        sofaBack.position = [0, -0.5, 1.35]
        anchor.addChild(sofaBack)
        
        // ドア (左壁面)
        let doorMaterial = SimpleMaterial(color: UIColor(red: 0.45, green: 0.22, blue: 0.08, alpha: 1.0), isMetallic: false)
        let door = ModelEntity(mesh: MeshResource.generateBox(width: 0.05, height: 2.0, depth: 0.95), materials: [doorMaterial])
        door.position = [-4.95, -0.2, -1.5]
        anchor.addChild(door)
        
        // 観葉植物 (右奥コーナー)
        let potMaterial = SimpleMaterial(color: .lightGray, isMetallic: false)
        let pot = ModelEntity(mesh: MeshResource.generateBox(width: 0.35, height: 0.45, depth: 0.35), materials: [potMaterial])
        pot.position = [4.0, -0.95, -4.0]
        anchor.addChild(pot)
        
        let leafMaterial = SimpleMaterial(color: .systemGreen, isMetallic: false)
        let leaf = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.35), materials: [leafMaterial])
        leaf.position = [4.0, -0.5, -4.0]
        anchor.addChild(leaf)
        
        arView.scene.addAnchor(anchor)
    }
}

#Preview {
    ContentView()
}
