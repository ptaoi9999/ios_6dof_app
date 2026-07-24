import ARKit
import Vision
import simd

/// ARKit（6DoF）と Vision（ハンドトラッキング）および物理演算を管理するクラス
class ARTracker: NSObject, ObservableObject, ARSessionDelegate {
    let session = ARSession()

    // カメラの最新のTransform
    @Published var cameraTransform: simd_float4x4 = matrix_identity_float4x4

    // 代表的な手の3D世界座標 (掴み判定などに使用)
    @Published var handPosition: simd_float3? = nil
    // 検出されたすべての手の関節の3D世界座標（辞書）
    @Published var handJoints: [String: simd_float3]? = nil

    // 現在ピンチ（つまむ）されているか
    @Published var isPinching: Bool = false
    // 現在手をグー（Fist）にしているか
    @Published var isFist: Bool = false

    // LaunchPadメニューの表示フラグ
    @Published var isMenuVisible: Bool = false
    // メニューを表示固定した際の世界座標Transform
    @Published var menuTransform: simd_float4x4 = matrix_identity_float4x4

    // つまんで動かせるボールの位置と状態
    @Published var ballPosition: simd_float3 = simd_make_float3(0, -0.5, -1.8)
    @Published var isGrabbingBall: Bool = false
    var ballVelocity: simd_float3 = simd_make_float3(0, 0, 0)
    private var handPosHistory: [simd_float3] = []

    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    private var frameCounter = 0
    private var wasFist: Bool = false

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

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let dt: Float = 1.0 / 60.0

        // 1. カメラ姿勢の更新
        let transform = frame.camera.transform
        DispatchQueue.main.async { self.cameraTransform = transform }

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

    // MARK: - Hand Tracking
    private func processHandTracking(frame: ARFrame, transform: simd_float4x4, dt: Float) {
        let pixelBuffer = frame.capturedImage
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([handPoseRequest])
            guard let observation = handPoseRequest.results?.first else {
                clearHandState(); return
            }

            var jointsDict = [String: simd_float3]()
            let allGroups: [VNHumanHandPoseObservation.JointsGroupName] = [
                .thumb, .indexFinger, .middleFinger, .ringFinger, .littleFinger
            ]
            for group in allGroups {
                if let pts = try? observation.recognizedPoints(group) {
                    for (name, pt) in pts where pt.confidence > 0.3 {
                        let lx = (Float(pt.location.x) - 0.5) * 0.4
                        let ly = (Float(pt.location.y) - 0.5) * 0.4
                        let world = transform * simd_make_float4(lx, ly, -0.4, 1)
                        jointsDict[name.rawValue.rawValue] = simd_make_float3(world.x, world.y, world.z)
                    }
                }
            }
            // 手首
            if let allPts = try? observation.recognizedPoints(.all),
               let wPt = allPts[.wrist], wPt.confidence > 0.3 {
                let lx = (Float(wPt.location.x) - 0.5) * 0.4
                let ly = (Float(wPt.location.y) - 0.5) * 0.4
                let world = transform * simd_make_float4(lx, ly, -0.4, 1)
                jointsDict["wrist"] = simd_make_float3(world.x, world.y, world.z)
            }

            // 各関節キー
            let indexTipKey  = VNHumanHandPoseObservation.JointName.indexTip.rawValue.rawValue
            let indexMCPKey  = VNHumanHandPoseObservation.JointName.indexMCP.rawValue.rawValue
            let middleTipKey = VNHumanHandPoseObservation.JointName.middleTip.rawValue.rawValue
            let middleMCPKey = VNHumanHandPoseObservation.JointName.middleMCP.rawValue.rawValue
            let ringTipKey   = VNHumanHandPoseObservation.JointName.ringTip.rawValue.rawValue
            let ringMCPKey   = VNHumanHandPoseObservation.JointName.ringMCP.rawValue.rawValue
            let littleTipKey = VNHumanHandPoseObservation.JointName.littleTip.rawValue.rawValue
            let littleMCPKey = VNHumanHandPoseObservation.JointName.littleMCP.rawValue.rawValue
            let thumbTipKey  = VNHumanHandPoseObservation.JointName.thumbTip.rawValue.rawValue

            guard
                let indexTip  = jointsDict[indexTipKey],
                let indexMCP  = jointsDict[indexMCPKey],
                let middleTip = jointsDict[middleTipKey],
                let middleMCP = jointsDict[middleMCPKey],
                let ringTip   = jointsDict[ringTipKey],
                let ringMCP   = jointsDict[ringMCPKey],
                let littleTip = jointsDict[littleTipKey],
                let littleMCP = jointsDict[littleMCPKey],
                let thumbTip  = jointsDict[thumbTipKey],
                let wristPos  = jointsDict["wrist"]
            else { clearHandState(); return }

            // ピンチ判定 (3D距離 5cm)
            let pinchDetected = simd_distance(indexTip, thumbTip) < 0.05

            // グー判定: 指先が付け根より手首に近い
            let fistDetected =
                simd_distance(indexTip,  wristPos) < simd_distance(indexMCP,  wristPos) &&
                simd_distance(middleTip, wristPos) < simd_distance(middleMCP, wristPos) &&
                simd_distance(ringTip,   wristPos) < simd_distance(ringMCP,   wristPos) &&
                simd_distance(littleTip, wristPos) < simd_distance(littleMCP, wristPos)

            let parsedHandPos = indexTip

            DispatchQueue.main.async {
                self.handPosition = parsedHandPos
                self.handJoints   = jointsDict
                self.isPinching   = pinchDetected
                self.isFist       = fistDetected

                // グーのトリガーでメニュー切り替え
                if !self.wasFist && fistDetected {
                    self.isMenuVisible.toggle()
                    if self.isMenuVisible {
                        var offset = matrix_identity_float4x4
                        offset.columns.3 = simd_make_float4(0, 0.05, -0.5, 1)
                        self.menuTransform = self.cameraTransform * offset
                    }
                }
                self.wasFist = fistDetected

                // ボールの掴み・投げ処理
                let distToBall = simd_distance(parsedHandPos, self.ballPosition)
                if pinchDetected {
                    if distToBall < 0.15 || self.isGrabbingBall {
                        self.isGrabbingBall = true
                        self.ballPosition = parsedHandPos
                        self.handPosHistory.append(parsedHandPos)
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

    // MARK: - Ball Physics
    private func updateBallPhysics(dt: Float) {
        let g: Float = -9.8
        let restitution: Float = 0.65

        ballVelocity.y += g * dt
        ballVelocity   *= 0.99
        var next = ballPosition + ballVelocity * dt

        // 床
        let floorY: Float = -1.2 + 0.08
        if next.y < floorY {
            next.y = floorY
            ballVelocity.y = -ballVelocity.y * restitution
            ballVelocity.x *= 0.92
            ballVelocity.z *= 0.92
        }
        // テーブル上面
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

        DispatchQueue.main.async { self.ballPosition = next }
    }

    func clearHandState() {
        DispatchQueue.main.async {
            self.handPosition = nil
            self.handJoints   = nil
            self.isPinching   = false
            self.isFist       = false
            self.wasFist      = false
            if self.isGrabbingBall {
                self.isGrabbingBall = false
                self.handPosHistory.removeAll()
            }
        }
    }
}
