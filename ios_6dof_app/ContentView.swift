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
    // 現在ピンチ（つまむ）されているか
    @Published var isPinching: Bool = false
    // パススルー（背景カメラ映像）が有効か
    @Published var isPassThroughEnabled: Bool = false
    
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    private var frameCounter = 0
    private var wasPinching: Bool = false // 前回のピンチ状態（エッジ検出用）
    
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
                    let indexPoints = try observation.recognizedPoints(.indexFinger)
                    let thumbPoints = try observation.recognizedPoints(.thumb)
                    
                    if let indexTip = indexPoints[.indexTip], indexTip.confidence > 0.5,
                       let thumbTip = thumbPoints[.thumbTip], thumbTip.confidence > 0.5 {
                        
                        let tipX = Float(indexTip.location.x)
                        let tipY = Float(indexTip.location.y)
                        
                        // カメラ前方 40cm に投影
                        let localX = (tipX - 0.5) * 0.4
                        let localY = (tipY - 0.5) * 0.4
                        let localPos = simd_make_float4(localX, localY, -0.4, 1.0)
                        
                        // 世界座標に変換
                        let worldPos = transform * localPos
                        
                        // ピンチ判定
                        let distance = simd_distance(
                            simd_make_float2(Float(indexTip.location.x), Float(indexTip.location.y)),
                            simd_make_float2(Float(thumbTip.location.x), Float(thumbTip.location.y))
                        )
                        let pinchDetected = distance < 0.08
                        
                        DispatchQueue.main.async {
                            self.handPosition = simd_make_float3(worldPos.x, worldPos.y, worldPos.z)
                            self.isPinching = pinchDetected
                            
                            // つまんだ瞬間（エッジ検出）にパススルーをトグル切り替え
                            if !self.wasPinching && pinchDetected {
                                self.isPassThroughEnabled.toggle()
                            }
                            self.wasPinching = pinchDetected
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
            self.wasPinching = false
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
        // パススルーを表示できるようにカメラモードを .ar で初期化し、セッションを共有
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        arView.session = tracker.session
        
        // 1. VRChat Home風のバーチャル空間を構築
        setupVRChatHomeScene(arView: arView)
        
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
        // パススルー状態に基づいて背景の描画を切り替える
        uiView.environment.background = tracker.isPassThroughEnabled ? .cameraFeed : .color(.black)
        
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
                
                // ピンチ状態（またはパススルー有効状態）に応じて色を変更
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
    
    // VRChat Home (Cozy Cabin風) の空間をモデリング
    private func setupVRChatHomeScene(arView: ARView) {
        let anchor = AnchorEntity(world: .zero)
        
        // マテリアルの定義
        let wallMaterial = SimpleMaterial(color: UIColor(red: 0.92, green: 0.90, blue: 0.85, alpha: 1.0), isMetallic: false) // 温かみのある壁
        let woodFloorMaterial = SimpleMaterial(color: UIColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1.0), isMetallic: false) // ダークウッドの床
        let woodFurnitureMaterial = SimpleMaterial(color: UIColor(red: 0.50, green: 0.32, blue: 0.18, alpha: 1.0), isMetallic: false) // コテージ風木製家具
        let fireplaceStoneMaterial = SimpleMaterial(color: UIColor(white: 0.4, alpha: 1.0), isMetallic: false) // 暖炉の石
        let fireplaceFireMaterial = SimpleMaterial(color: UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0), isMetallic: true) // 暖炉の炎（オレンジ発光風）
        
        // 1. 部屋の構造
        // 床 (Y = -1.2m)
        let floor = ModelEntity(mesh: MeshResource.generateBox(width: 10, height: 0.1, depth: 10), materials: [woodFloorMaterial])
        floor.position = [0, -1.2, 0]
        anchor.addChild(floor)
        
        // 天井 (Y = 1.8m)
        let ceiling = ModelEntity(mesh: MeshResource.generateBox(width: 10, height: 0.1, depth: 10), materials: SimpleMaterial(color: UIColor(white: 0.85, alpha: 1.0), isMetallic: false))
        ceiling.position = [0, 1.8, 0]
        anchor.addChild(ceiling)
        
        // 奥の壁 (Z = -5m, VRChat Homeの景観用の大窓エリアを残すために左右に分割)
        let backWallLeft = ModelEntity(mesh: MeshResource.generateBox(width: 3.5, height: 3, depth: 0.1), materials: [wallMaterial])
        backWallLeft.position = [-3.25, 0.3, -5]
        anchor.addChild(backWallLeft)
        
        let backWallRight = ModelEntity(mesh: MeshResource.generateBox(width: 3.5, height: 3, depth: 0.1), materials: [wallMaterial])
        backWallRight.position = [3.25, 0.3, -5]
        anchor.addChild(backWallRight)
        
        // 窓枠（梁）
        let windowBeam = ModelEntity(mesh: MeshResource.generateBox(width: 3.0, height: 0.1, depth: 0.15), materials: [woodFurnitureMaterial])
        windowBeam.position = [0, 1.3, -5.0]
        anchor.addChild(windowBeam)
        
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
        
        // 2. VRChat Home風の要素（暖炉・家具・インテリア）
        // 暖炉 (右奥コーナー: X = 3.5m, Z = -4.0m)
        let fireplaceBase = ModelEntity(mesh: MeshResource.generateBox(width: 1.5, height: 0.3, depth: 1.5), materials: [fireplaceStoneMaterial])
        fireplaceBase.position = [3.5, -1.05, -4.0]
        anchor.addChild(fireplaceBase)
        
        let fireplaceLeftWall = ModelEntity(mesh: MeshResource.generateBox(width: 0.3, height: 1.2, depth: 1.2), materials: [fireplaceStoneMaterial])
        fireplaceLeftWall.position = [2.9, -0.3, -4.0]
        anchor.addChild(fireplaceLeftWall)
        
        let fireplaceBackWall = ModelEntity(mesh: MeshResource.generateBox(width: 1.5, height: 1.2, depth: 0.3), materials: [fireplaceStoneMaterial])
        fireplaceBackWall.position = [3.5, -0.3, -4.6]
        anchor.addChild(fireplaceBackWall)
        
        let fireplaceTop = ModelEntity(mesh: MeshResource.generateBox(width: 1.6, height: 0.2, depth: 1.6), materials: [woodFurnitureMaterial])
        fireplaceTop.position = [3.5, 0.4, -4.0]
        anchor.addChild(fireplaceTop)
        
        // 暖炉の中の炎 (オレンジに輝く球体)
        let fire = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.18), materials: [fireplaceFireMaterial])
        fire.position = [3.5, -0.8, -4.0]
        anchor.addChild(fire)
        
        // 木製ローテーブル
        let lowTable = ModelEntity(mesh: MeshResource.generateBox(width: 1.5, height: 0.08, depth: 0.9), materials: [woodFurnitureMaterial])
        lowTable.position = [-0.5, -0.85, -1.8]
        anchor.addChild(lowTable)
        
        // テーブルの脚
        let legMesh = MeshResource.generateBox(width: 0.08, height: 0.35, depth: 0.08)
        let legPositions: [SIMD3<Float>] = [
            [-1.1, -1.025, -2.15], [0.1, -1.025, -2.15],
            [-1.1, -1.025, -1.45], [0.1, -1.025, -1.45]
        ]
        for pos in legPositions {
            let leg = ModelEntity(mesh: legMesh, materials: [woodFurnitureMaterial])
            leg.position = pos
            anchor.addChild(leg)
        }
        
        // 大きなソファ (Cozyな布ソファを模したもの)
        let sofaFabricMaterial = SimpleMaterial(color: UIColor(red: 0.22, green: 0.28, blue: 0.24, alpha: 1.0), isMetallic: false) // 深緑
        let sofaSeat = ModelEntity(mesh: MeshResource.generateBox(width: 2.2, height: 0.35, depth: 0.85), materials: [sofaFabricMaterial])
        sofaSeat.position = [-0.5, -0.9, 0.4]
        anchor.addChild(sofaSeat)
        
        let sofaBack = ModelEntity(mesh: MeshResource.generateBox(width: 2.2, height: 0.7, depth: 0.18), materials: [sofaFabricMaterial])
        sofaBack.position = [-0.5, -0.55, 0.85]
        anchor.addChild(sofaBack)
        
        let armLeft = ModelEntity(mesh: MeshResource.generateBox(width: 0.18, height: 0.55, depth: 0.85), materials: [sofaFabricMaterial])
        armLeft.position = [-1.6, -0.8, 0.4]
        anchor.addChild(armLeft)
        
        let armRight = ModelEntity(mesh: MeshResource.generateBox(width: 0.18, height: 0.55, depth: 0.85), materials: [sofaFabricMaterial])
        armRight.position = [0.6, -0.8, 0.4]
        anchor.addChild(armRight)
        
        // ラグマット (テーブルの下に敷く)
        let rugMaterial = SimpleMaterial(color: UIColor(red: 0.85, green: 0.80, blue: 0.72, alpha: 1.0), isMetallic: false) // ベージュ
        let rug = ModelEntity(mesh: MeshResource.generateBox(width: 2.4, height: 0.01, depth: 1.8), materials: [rugMaterial])
        rug.position = [-0.5, -1.19, -1.8]
        anchor.addChild(rug)
        
        // 3. 窓の外の景観（星空を模したドットの配置）
        let starMaterial = SimpleMaterial(color: .white, isMetallic: true)
        let starMesh = MeshResource.generateSphere(radius: 0.04)
        let starPositions: [SIMD3<Float>] = [
            [-1.5, 1.0, -10], [0.0, 1.4, -12], [1.8, 0.8, -10],
            [-0.8, 0.5, -11], [1.2, 1.6, -11], [-2.2, 1.7, -9]
        ]
        for starPos in starPositions {
            let star = ModelEntity(mesh: starMesh, materials: [starMaterial])
            star.position = starPos
            anchor.addChild(star)
        }
        
        arView.scene.addAnchor(anchor)
    }
}

#Preview {
    ContentView()
}
