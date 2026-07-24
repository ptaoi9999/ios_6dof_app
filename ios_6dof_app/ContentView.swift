import SwiftUI
import RealityKit
import ARKit
import Vision

// 左右の目を識別する列挙型
enum Eye {
    case left
    case right
}

// ARKit（6DoF）と Vision（ハンドトラッキング）および物理演算を管理するクラス
class ARTracker: NSObject, ObservableObject, ARSessionDelegate {
    let session = ARSession()
    
    // カメラの最新のTransform
    @Published var cameraTransform: simd_float4x4 = matrix_identity_float4x4
    
    // 検出された手の3D世界座標
    @Published var handPosition: simd_float3? = nil
    // 現在ピンチ（つまむ）されているか
    @Published var isPinching: Bool = false
    
    // 現在手をグー（Fist）にしているか
    @Published var isFist: Bool = false
    // LaunchPadメニューの表示フラグ
    @Published var isMenuVisible: Bool = false
    // メニューを表示固定した際の世界座標Transform
    @Published var menuTransform: simd_float4x4 = matrix_identity_float4x4
    
    // つまんで動かせるボールの位置と状態
    @Published var ballPosition: simd_float3 = simd_make_float3(0, -0.5, -1.8) // 初期位置（テーブルの上）
    @Published var isGrabbingBall: Bool = false
    private var ballVelocity: simd_float3 = simd_make_float3(0, 0, 0)
    private var handPosHistory: [simd_float3] = []
    
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    private var frameCounter = 0
    private var wasFist: Bool = false     // 前回のグー状態（エッジ検出用）
    
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
        let dt: Float = 1.0 / 60.0 // 簡易物理シミュレーション用時間ステップ
        
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
                    let middlePoints = try observation.recognizedPoints(.middleFinger)
                    let ringPoints = try observation.recognizedPoints(.ringFinger)
                    let littlePoints = try observation.recognizedPoints(.littleFinger)
                    let thumbPoints = try observation.recognizedPoints(.thumb)
                    let wristPoints = try observation.recognizedPoints(.all)
                    
                    if let indexTip = indexPoints[.indexTip], indexTip.confidence > 0.5,
                       let indexMCP = indexPoints[.indexMCP], indexMCP.confidence > 0.5,
                       let middleTip = middlePoints[.middleTip], middleTip.confidence > 0.5,
                       let middleMCP = middlePoints[.middleMCP], middleMCP.confidence > 0.5,
                       let ringTip = ringPoints[.ringTip], ringTip.confidence > 0.5,
                       let ringMCP = ringPoints[.ringMCP], ringMCP.confidence > 0.5,
                       let littleTip = littlePoints[.littleTip], littleTip.confidence > 0.5,
                       let littleMCP = littlePoints[.littleMCP], littleMCP.confidence > 0.5,
                       let thumbTip = thumbPoints[.thumbTip], thumbTip.confidence > 0.5,
                       let wrist = wristPoints[.wrist], wrist.confidence > 0.5 {
                        
                        let tipX = Float(indexTip.location.x)
                        let tipY = Float(indexTip.location.y)
                        
                        // カメラ前方 40cm に手の球体を投影
                        let localX = (tipX - 0.5) * 0.4
                        let localY = (tipY - 0.5) * 0.4
                        let localPos = simd_make_float4(localX, localY, -0.4, 1.0)
                        let worldPos = transform * localPos
                        
                        // ピンチ判定 (親指と人差し指の距離)
                        let distance = simd_distance(
                            simd_make_float2(Float(indexTip.location.x), Float(indexTip.location.y)),
                            simd_make_float2(Float(thumbTip.location.x), Float(thumbTip.location.y))
                        )
                        let pinchDetected = distance < 0.08
                        
                        // グー（Fist）判定
                        let wristPos = simd_make_float2(Float(wrist.location.x), Float(wrist.location.y))
                        
                        let indexTipDist = simd_distance(simd_make_float2(Float(indexTip.location.x), Float(indexTip.location.y)), wristPos)
                        let indexMCPDist = simd_distance(simd_make_float2(Float(indexMCP.location.x), Float(indexMCP.location.y)), wristPos)
                        
                        let middleTipDist = simd_distance(simd_make_float2(Float(middleTip.location.x), Float(middleTip.location.y)), wristPos)
                        let middleMCPDist = simd_distance(simd_make_float2(Float(middleMCP.location.x), Float(middleMCP.location.y)), wristPos)
                        
                        let ringTipDist = simd_distance(simd_make_float2(Float(ringTip.location.x), Float(ringTip.location.y)), wristPos)
                        let ringMCPDist = simd_distance(simd_make_float2(Float(ringMCP.location.x), Float(ringMCP.location.y)), wristPos)
                        
                        let littleTipDist = simd_distance(simd_make_float2(Float(littleTip.location.x), Float(littleTip.location.y)), wristPos)
                        let littleMCPDist = simd_distance(simd_make_float2(Float(littleMCP.location.x), Float(littleMCP.location.y)), wristPos)
                        
                        let fistDetected = (indexTipDist < indexMCPDist) &&
                                           (middleTipDist < middleMCPDist) &&
                                           (ringTipDist < ringMCPDist) &&
                                           (littleTipDist < littleMCPDist)
                        
                        DispatchQueue.main.async {
                            let parsedHandPos = simd_make_float3(worldPos.x, worldPos.y, worldPos.z)
                            self.handPosition = parsedHandPos
                            self.isPinching = pinchDetected
                            self.isFist = fistDetected
                            
                            // グーのトリガーでLaunchPadメニュー切り替え
                            if !self.wasFist && fistDetected {
                                self.isMenuVisible.toggle()
                                if self.isMenuVisible {
                                    // メニュー正面 50cm に固定
                                    var offsetMatrix = matrix_identity_float4x4
                                    offsetMatrix.columns.3 = simd_make_float4(0, 0.05, -0.5, 1)
                                    self.menuTransform = self.cameraTransform * offsetMatrix
                                }
                            }
                            self.wasFist = fistDetected
                            
                            // --- ボールの掴み・投げ処理 ---
                            let distToBall = simd_distance(parsedHandPos, self.ballPosition)
                            if pinchDetected {
                                if distToBall < 0.15 || self.isGrabbingBall {
                                    self.isGrabbingBall = true
                                    self.ballPosition = parsedHandPos
                                    
                                    // 手の位置履歴を保持（速度算出用）
                                    self.handPosHistory.append(parsedHandPos)
                                    if self.handPosHistory.count > 5 {
                                        self.handPosHistory.removeFirst()
                                    }
                                    self.ballVelocity = .zero
                                }
                            } else {
                                if self.isGrabbingBall {
                                    self.isGrabbingBall = false
                                    // 離した瞬間の速度を計算してボールに与える（投げる動作）
                                    if self.handPosHistory.count >= 2 {
                                        let first = self.handPosHistory.first!
                                        let last = self.handPosHistory.last!
                                        let count = Float(self.handPosHistory.count)
                                        self.ballVelocity = (last - first) / (count * (dt * 3.0)) // 3フレーム周期のため補正
                                    }
                                    self.handPosHistory.removeAll()
                                }
                            }
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
        
        // 3. ボールの物理シミュレーション (掴まれていない場合に適用)
        if !self.isGrabbingBall {
            let g: Float = -9.8
            let restitution: Float = 0.65 // 跳ね返り係数
            
            // 重力を適用
            self.ballVelocity.y += g * dt
            
            // 空気抵抗（減衰）
            self.ballVelocity *= 0.99
            
            // 位置を更新
            var nextPos = self.ballPosition + self.ballVelocity * dt
            
            // 床との衝突判定 (床 Y = -1.2m, ボールの半径 0.08m)
            let floorLimit: Float = -1.2 + 0.08
            if nextPos.y < floorLimit {
                nextPos.y = floorLimit
                self.ballVelocity.y = -self.ballVelocity.y * restitution
                // 床との摩擦
                self.ballVelocity.x *= 0.92
                self.ballVelocity.z *= 0.92
            }
            
            // テーブルとの衝突判定 (上面 Y = -0.6m, ボールの半径 0.08m -> Y = -0.52m)
            // テーブル範囲: X ∈ [-0.8, 0.8], Z ∈ [-2.5, -1.5]
            let tableTopLimit: Float = -0.6 + 0.08
            if nextPos.y < tableTopLimit && nextPos.y > tableTopLimit - 0.15 {
                if nextPos.x >= -0.8 && nextPos.x <= 0.8 &&
                   nextPos.z >= -2.5 && nextPos.z <= -1.5 {
                    if self.ballVelocity.y < 0 {
                        nextPos.y = tableTopLimit
                        self.ballVelocity.y = -self.ballVelocity.y * restitution
                        self.ballVelocity.x *= 0.92
                        self.ballVelocity.z *= 0.92
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.ballPosition = nextPos
            }
        }
    }
    
    private func clearHandState() {
        DispatchQueue.main.async {
            self.handPosition = nil
            self.isPinching = false
            self.isFist = false
            self.wasFist = false
            if self.isGrabbingBall {
                self.isGrabbingBall = false
                self.handPosHistory.removeAll()
            }
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
        // パススルー機能を削除し、純粋な非AR（VRモード）に戻す
        let arView = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
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
        handEntity.scale = .zero
        
        let handAnchor = AnchorEntity(world: .zero)
        handAnchor.addChild(handEntity)
        arView.scene.addAnchor(handAnchor)
        
        // 4. つまんで動かせるボールEntityの追加
        let ballMesh = MeshResource.generateSphere(radius: 0.08)
        let ballMaterial = SimpleMaterial(color: .systemRed, isMetallic: true)
        let ballEntity = ModelEntity(mesh: ballMesh, materials: [ballMaterial])
        ballEntity.name = "vrBall"
        
        let ballAnchor = AnchorEntity(world: .zero)
        ballAnchor.addChild(ballEntity)
        arView.scene.addAnchor(ballAnchor)
        
        // 5. LaunchPadメニューEntityの追加
        let menuEntity = createLaunchPadEntity()
        menuEntity.name = "vrMenu"
        menuEntity.scale = .zero
        
        let menuAnchor = AnchorEntity(world: .zero)
        menuAnchor.addChild(menuEntity)
        arView.scene.addAnchor(menuAnchor)
        
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
                
                // 掴み判定またはピンチ状態で色を変更
                let color: UIColor = tracker.isGrabbingBall ? .systemGreen : (tracker.isPinching ? .systemYellow : .white)
                let material = SimpleMaterial(color: color, isMetallic: tracker.isPinching)
                if var modelComp = hand.components[ModelComponent.self] as? ModelComponent {
                    modelComp.materials = [material]
                    hand.components.set(modelComp)
                }
            } else {
                hand.scale = .zero
            }
        }
        
        // ボールの3D球体の位置更新 (trackerが計算した同期物理位置をそのまま代入)
        if let ball = uiView.scene.findEntity(named: "vrBall") {
            ball.position = tracker.ballPosition
        }
        
        // LaunchPadメニューの表示・位置同期
        if let menu = uiView.scene.findEntity(named: "vrMenu") {
            if tracker.isMenuVisible {
                menu.transform.matrix = tracker.menuTransform
                menu.scale = [1, 1, 1]
            } else {
                menu.scale = .zero
            }
        }
    }
    
    // LaunchPadメニュー (プロトタイプ) の構築
    private func createLaunchPadEntity() -> ModelEntity {
        // メインパネル
        let menuMaterial = SimpleMaterial(color: UIColor(red: 0.05, green: 0.1, blue: 0.2, alpha: 0.75), isMetallic: true)
        let menuBase = ModelEntity(mesh: MeshResource.generateBox(width: 0.4, height: 0.28, depth: 0.01), materials: [menuMaterial])
        
        // タイトルバー (LaunchPadヘッダー)
        let titleMat = SimpleMaterial(color: UIColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 0.9), isMetallic: true)
        let titleBar = ModelEntity(mesh: MeshResource.generateBox(width: 0.36, height: 0.04, depth: 0.005), materials: [titleMat])
        titleBar.position = [0, 0.1, 0.008]
        menuBase.addChild(titleBar)
        
        // ボタンA (ダミーボタン1)
        let btnMatA = SimpleMaterial(color: .systemBlue, isMetallic: false)
        let btnA = ModelEntity(mesh: MeshResource.generateBox(width: 0.15, height: 0.06, depth: 0.015), materials: [btnMatA])
        btnA.position = [-0.09, -0.02, 0.01]
        menuBase.addChild(btnA)
        
        // ボタンB (ダミーボタン2)
        let btnMatB = SimpleMaterial(color: .systemOrange, isMetallic: false)
        let btnB = ModelEntity(mesh: MeshResource.generateBox(width: 0.15, height: 0.06, depth: 0.015), materials: [btnMatB])
        btnB.position = [0.09, -0.02, 0.01]
        menuBase.addChild(btnB)
        
        return menuBase
    }
    
    // VRChat Home (Cozy Cabin風) の空間をモデリング
    private func setupVRChatHomeScene(arView: ARView) {
        let anchor = AnchorEntity(world: .zero)
        
        let wallMaterial = SimpleMaterial(color: UIColor(red: 0.92, green: 0.90, blue: 0.85, alpha: 1.0), isMetallic: false)
        let woodFloorMaterial = SimpleMaterial(color: UIColor(red: 0.35, green: 0.22, blue: 0.12, alpha: 1.0), isMetallic: false)
        let woodFurnitureMaterial = SimpleMaterial(color: UIColor(red: 0.50, green: 0.32, blue: 0.18, alpha: 1.0), isMetallic: false)
        let fireplaceStoneMaterial = SimpleMaterial(color: UIColor(white: 0.4, alpha: 1.0), isMetallic: false)
        let fireplaceFireMaterial = SimpleMaterial(color: UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1.0), isMetallic: true)
        
        // 床
        let floor = ModelEntity(mesh: MeshResource.generateBox(width: 10, height: 0.1, depth: 10), materials: [woodFloorMaterial])
        floor.position = [0, -1.2, 0]
        anchor.addChild(floor)
        
        // 天井
        let ceiling = ModelEntity(mesh: MeshResource.generateBox(width: 10, height: 0.1, depth: 10), materials: [SimpleMaterial(color: UIColor(white: 0.85, alpha: 1.0), isMetallic: false)])
        ceiling.position = [0, 1.8, 0]
        anchor.addChild(ceiling)
        
        // 奥の壁 (大窓エリアを残すため左右分割)
        let backWallLeft = ModelEntity(mesh: MeshResource.generateBox(width: 3.5, height: 3, depth: 0.1), materials: [wallMaterial])
        backWallLeft.position = [-3.25, 0.3, -5]
        anchor.addChild(backWallLeft)
        
        let backWallRight = ModelEntity(mesh: MeshResource.generateBox(width: 3.5, height: 3, depth: 0.1), materials: [wallMaterial])
        backWallRight.position = [3.25, 0.3, -5]
        anchor.addChild(backWallRight)
        
        // 窓枠
        let windowBeam = ModelEntity(mesh: MeshResource.generateBox(width: 3.0, height: 0.1, depth: 0.15), materials: [woodFurnitureMaterial])
        windowBeam.position = [0, 1.3, -5.0]
        anchor.addChild(windowBeam)
        
        // 手前の壁
        let frontWall = ModelEntity(mesh: MeshResource.generateBox(width: 10, height: 3, depth: 0.1), materials: [wallMaterial])
        frontWall.position = [0, 0.3, 5]
        anchor.addChild(frontWall)
        
        // 左の壁
        let leftWall = ModelEntity(mesh: MeshResource.generateBox(width: 0.1, height: 3, depth: 10), materials: [wallMaterial])
        leftWall.position = [-5, 0.3, 0]
        anchor.addChild(leftWall)
        
        // 右の壁
        let rightWall = ModelEntity(mesh: MeshResource.generateBox(width: 0.1, height: 3, depth: 10), materials: [wallMaterial])
        rightWall.position = [5, 0.3, 0]
        anchor.addChild(rightWall)
        
        // 暖炉 (右奥コーナー)
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
        
        let fire = ModelEntity(mesh: MeshResource.generateSphere(radius: 0.18), materials: [fireplaceFireMaterial])
        fire.position = [3.5, -0.8, -4.0]
        anchor.addChild(fire)
        
        // 木製テーブル
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
        
        // ソファ
        let sofaFabricMaterial = SimpleMaterial(color: UIColor(red: 0.22, green: 0.28, blue: 0.24, alpha: 1.0), isMetallic: false)
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
        
        // ラグマット
        let rugMaterial = SimpleMaterial(color: UIColor(red: 0.85, green: 0.80, blue: 0.72, alpha: 1.0), isMetallic: false)
        let rug = ModelEntity(mesh: MeshResource.generateBox(width: 2.4, height: 0.01, depth: 1.8), materials: [rugMaterial])
        rug.position = [-0.5, -1.19, -1.8]
        anchor.addChild(rug)
        
        // 窓の外の星
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
