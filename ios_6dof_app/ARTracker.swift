import ARKit
import Vision
import simd

/// 検出された実世界の平面情報
struct DetectedPlane {
    let identifier: UUID
    let transform: simd_float4x4
    let center: SIMD3<Float>
    let extent: SIMD3<Float> // 幅, 高さ, 奥行き
}

/// ARKit（6DoF/平面検出）と Vision（ハンドトラッキング）および物理演算を管理するクラス
class ARTracker: NSObject, ObservableObject, ARSessionDelegate {
    let session = ARSession()

    // カメラの最新のTransform
    @Published var cameraTransform: simd_float4x4 = matrix_identity_float4x4

    // 代表的な手の3D世界座標 (掴み判定などに使用)
    @Published var handPosition: simd_float3? = nil
    // 検出されたすべての手の関節の3D世界座標（型セーフなJointNameキー）
    @Published var handJoints: [VNHumanHandPoseObservation.JointName: simd_float3]? = nil

    // 現在ピンチ（つまむ）されているか
    @Published var isPinching: Bool = false

    // パススルー（現世カメラ映像＋リアル平面物理）のON/OFF
    @Published var isPassthroughEnabled: Bool = false

    // 設定パネルのTransform・掴み移動・タッチ状態
    @Published var panelTransform: simd_float4x4 = matrix_identity_float4x4
    @Published var isGrabbingPanel: Bool = false
    @Published var isBtnPressed: Bool = false
    private var lastButtonTouchTime: Date = Date.distantPast
    private var isPanelInitialized: Bool = false

    // つまんで動かせるボールの位置と状態
    @Published var ballPosition: simd_float3 = simd_make_float3(0, -0.5, -1.8)
    @Published var isGrabbingBall: Bool = false
    var ballVelocity: simd_float3 = simd_make_float3(0, 0, 0)
    private var handPosHistory: [simd_float3] = []

    // 検出された実世界の平面（テーブル・床など）のリスト
    private var detectedPlanes: [UUID: DetectedPlane] = [:]

    private let handPoseRequest = VNDetectHumanHandPoseRequest()
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
        // 水平・垂直平面の自動検出を有効化（現世のテーブルや床を認識）
        configuration.planeDetection = [.horizontal, .vertical]
        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    // MARK: - ARSessionDelegate (平面検出)
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        updatePlanes(from: anchors)
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        updatePlanes(from: anchors)
    }

    func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                detectedPlanes.removeValue(forKey: planeAnchor.identifier)
            }
        }
    }

    private func updatePlanes(from anchors: [ARAnchor]) {
        for anchor in anchors {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                let plane = DetectedPlane(
                    identifier: planeAnchor.identifier,
                    transform: planeAnchor.transform,
                    center: SIMD3<Float>(planeAnchor.center.x, planeAnchor.center.y, planeAnchor.center.z),
                    extent: SIMD3<Float>(planeAnchor.extent.x, planeAnchor.extent.y, planeAnchor.extent.z)
                )
                detectedPlanes[planeAnchor.identifier] = plane
            }
        }
    }

    // MARK: - Frame Update
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let dt: Float = 1.0 / 60.0

        // 1. カメラ姿勢の更新
        let transform = frame.camera.transform
        DispatchQueue.main.async {
            self.cameraTransform = transform
            // パネルの初期位置（カメラ正面 60cm, 少し下）の設定
            if !self.isPanelInitialized {
                var offset = matrix_identity_float4x4
                offset.columns.3 = simd_make_float4(0, -0.1, -0.6, 1)
                self.panelTransform = transform * offset
                self.isPanelInitialized = true
            }
        }

        // 2. Visionによるハンドトラッキング（3フレームに1回）
        frameCounter += 1
        if frameCounter % 3 == 0 {
            processHandTracking(frame: frame, transform: transform, dt: dt)
        }

        // 3. ボールの物理シミュレーション
        if !isGrabbingBall {
            updateBallPhysics(dt: dt)
        }
    }

    // MARK: - Hand Tracking & Panel Interaction
    private func processHandTracking(frame: ARFrame, transform: simd_float4x4, dt: Float) {
        let pixelBuffer = frame.capturedImage
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([handPoseRequest])
            guard let observation = handPoseRequest.results?.first else {
                clearHandState(); return
            }

            var jointsDict = [VNHumanHandPoseObservation.JointName: simd_float3]()
            let allJoints: [VNHumanHandPoseObservation.JointName] = [
                .wrist,
                .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
                .indexMCP, .indexPIP, .indexDIP, .indexTip,
                .middleMCP, .middlePIP, .middleDIP, .middleTip,
                .ringMCP, .ringPIP, .ringDIP, .ringTip,
                .littleMCP, .littlePIP, .littleDIP, .littleTip
            ]

            for jointName in allJoints {
                if let pt = try? observation.recognizedPoint(jointName), pt.confidence > 0.3 {
                    let lx = (Float(pt.location.x) - 0.5) * 0.4
                    let ly = (Float(pt.location.y) - 0.5) * 0.4
                    let world = transform * simd_make_float4(lx, ly, -0.4, 1)
                    jointsDict[jointName] = simd_make_float3(world.x, world.y, world.z)
                }
            }

            guard let indexTip = jointsDict[.indexTip] ?? jointsDict[.wrist] else {
                clearHandState(); return
            }
            let thumbTip = jointsDict[.thumbTip] ?? indexTip
            let pinchDetected = simd_distance(indexTip, thumbTip) < 0.05

            DispatchQueue.main.async {
                self.handPosition = indexTip
                self.handJoints   = jointsDict
                self.isPinching   = pinchDetected

                // --- 設定パネルのインタラクション（移動 & ボタンタッチ）---
                self.processPanelInteractions(indexTip: indexTip, isPinching: pinchDetected)

                // --- ボールの掴み・投げ処理 ---
                let distToBall = simd_distance(indexTip, self.ballPosition)
                if pinchDetected && !self.isGrabbingPanel {
                    if distToBall < 0.15 || self.isGrabbingBall {
                        self.isGrabbingBall = true
                        self.ballPosition = indexTip
                        self.handPosHistory.append(indexTip)
                        if self.handPosHistory.count > 5 { self.handPosHistory.removeFirst() }
                        self.ballVelocity = .zero
                    }
                } else if self.isGrabbingBall {
                    self.isGrabbingBall = false
                    if self.handPosHistory.count >= 2 {
                        let first = self.handPosHistory.first!
                        let last  = self.handPosHistory.last!
                        self.ballVelocity = (last - first) / (Float(self.handPosHistory.count) * dt * 3.0)
                    }
                    self.handPosHistory.removeAll()
                }
            }
        } catch {
            print("Hand tracking error: \(error)")
            clearHandState()
        }
    }

    /// 設定パネルの掴み移動およびボタン押下判定
    private func processPanelInteractions(indexTip: simd_float3, isPinching: Bool) {
        let panelPos = simd_make_float3(panelTransform.columns.3.x, panelTransform.columns.3.y, panelTransform.columns.3.z)
        
        // ヘッダー部分（パネルの上部 9cm 付近）
        let headerPos = panelPos + simd_make_float3(0, 0.09, 0)
        let distToHeader = simd_distance(indexTip, headerPos)

        // 1. パネルの掴み移動
        if isPinching {
            if distToHeader < 0.12 || isGrabbingPanel {
                isGrabbingPanel = true
                var newTransform = panelTransform
                newTransform.columns.3 = simd_make_float4(indexTip.x, indexTip.y - 0.09, indexTip.z, 1.0)
                panelTransform = newTransform
            }
        } else {
            isGrabbingPanel = false
        }

        // 2. パススルー切り替えボタンのタッチ（押し込み）検出
        let buttonPos = panelPos + simd_make_float3(0, -0.02, 0.01)
        let distToButton = simd_distance(indexTip, buttonPos)

        if distToButton < 0.05 {
            isBtnPressed = true
            let now = Date()
            if now.timeIntervalSince(lastButtonTouchTime) > 0.6 {
                isPassthroughEnabled.toggle()
                lastButtonTouchTime = now
            }
        } else {
            isBtnPressed = false
        }
    }

    // MARK: - Ball Physics (VRモード & 現世パススルーリアル平面)
    private func updateBallPhysics(dt: Float) {
        let g: Float = -9.8
        let restitution: Float = 0.65

        ballVelocity.y += g * dt
        ballVelocity   *= 0.99
        var next = ballPosition + ballVelocity * dt

        if isPassthroughEnabled {
            // --- 現世（パススルー）モード: ARKitが検出した実世界の平面（テーブル・床）と衝突 ---
            var hasCollided = false
            for plane in detectedPlanes.values {
                let planeWorldY = plane.transform.columns.3.y + plane.center.y
                let planeWorldX = plane.transform.columns.3.x + plane.center.x
                let planeWorldZ = plane.transform.columns.3.z + plane.center.z
                
                let halfExtentX = max(plane.extent.x * 0.5, 0.3)
                let halfExtentZ = max(plane.extent.z * 0.5, 0.3)
                
                let ballRadius: Float = 0.08
                let planeTopY = planeWorldY + ballRadius
                
                // 平面の高さ制限および水平領域内にあるかチェック
                if next.y < planeTopY && next.y > planeTopY - 0.18 {
                    if abs(next.x - planeWorldX) <= halfExtentX && abs(next.z - planeWorldZ) <= halfExtentZ {
                        if ballVelocity.y < 0 {
                            next.y = planeTopY
                            ballVelocity.y = -ballVelocity.y * restitution
                            ballVelocity.x *= 0.90
                            ballVelocity.z *= 0.90
                            hasCollided = true
                            break
                        }
                    }
                }
            }
            
            // 実世界で平面が未検出の場合のセーフティ底面（地面 -1.2m）
            if !hasCollided {
                let floorY: Float = -1.2 + 0.08
                if next.y < floorY {
                    next.y = floorY
                    ballVelocity.y = -ballVelocity.y * restitution
                    ballVelocity.x *= 0.92
                    ballVelocity.z *= 0.92
                }
            }
        } else {
            // --- VRモード: バーチャルな家（VRChat Home）の床やテーブルと衝突 ---
            let floorY: Float = -1.2 + 0.08
            if next.y < floorY {
                next.y = floorY
                ballVelocity.y = -ballVelocity.y * restitution
                ballVelocity.x *= 0.92
                ballVelocity.z *= 0.92
            }
            
            let tableY: Float = -0.85 + 0.04 + 0.08
            if next.y < tableY && next.y > tableY - 0.15 &&
               next.x >= -1.26 && next.x <= 0.26 &&
               next.z >= -2.26 && next.z <= -1.34 &&
               ballVelocity.y < 0 {
                next.y = tableY
                ballVelocity.y = -ballVelocity.y * restitution
                ballVelocity.x *= 0.92
                ballVelocity.z *= 0.92
            }
        }

        DispatchQueue.main.async { self.ballPosition = next }
    }

    func clearHandState() {
        DispatchQueue.main.async {
            self.handPosition = nil
            self.handJoints   = nil
            self.isPinching   = false
            self.isGrabbingPanel = false
            self.isBtnPressed = false
            if self.isGrabbingBall {
                self.isGrabbingBall = false
                self.handPosHistory.removeAll()
            }
        }
    }
}
