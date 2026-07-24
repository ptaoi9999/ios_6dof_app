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
    // 検出されたすべての手の関節の3D世界座標（型セーフなJointNameキー）
    @Published var handJoints: [VNHumanHandPoseObservation.JointName: simd_float3]? = nil

    // 現在ピンチ（つまむ）されているか
    @Published var isPinching: Bool = false

    // つまんで動かせるボールの位置と状態
    @Published var ballPosition: simd_float3 = simd_make_float3(0, -0.5, -1.8)
    @Published var isGrabbingBall: Bool = false
    var ballVelocity: simd_float3 = simd_make_float3(0, 0, 0)
    private var handPosHistory: [simd_float3] = []

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

            // 代表点（人差し指先端または手首）
            guard let indexTip = jointsDict[.indexTip] ?? jointsDict[.wrist] else {
                clearHandState(); return
            }

            let thumbTip = jointsDict[.thumbTip] ?? indexTip

            // ピンチ判定 (3D距離 5cm)
            let pinchDetected = simd_distance(indexTip, thumbTip) < 0.05

            DispatchQueue.main.async {
                self.handPosition = indexTip
                self.handJoints   = jointsDict
                self.isPinching   = pinchDetected

                // ボールの掴み・投げ処理
                let distToBall = simd_distance(indexTip, self.ballPosition)
                if pinchDetected {
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
            if self.isGrabbingBall {
                self.isGrabbingBall = false
                self.handPosHistory.removeAll()
            }
        }
    }
}
