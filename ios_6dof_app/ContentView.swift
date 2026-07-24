import SwiftUI
import RealityKit

struct ContentView: View {
    @StateObject private var tracker = ARTracker()

    var body: some View {
        HStack(spacing: 0) {
            VRViewContainer(eye: .left,  tracker: tracker)
            Divider()
                .background(Color.black)
                .frame(width: 2)
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
        arView.session = tracker.session

        // 1. 部屋のシーン構築
        setupVRChatHomeScene(in: arView)

        // 2. カスタムカメラ
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 85
        camera.name = "vrCamera"
        let camAnchor = AnchorEntity(world: .zero)
        camAnchor.addChild(camera)
        arView.scene.addAnchor(camAnchor)

        // 3. ハンドスケルトン（複数球体 + ボーン）
        let handAnchor = makeHandSkeletonAnchor()
        arView.scene.addAnchor(handAnchor)

        // 4. 物理ボール（金属レッド）
        var ballMat = PhysicallyBasedMaterial()
        ballMat.baseColor = .init(tint: UIColor(red: 0.9, green: 0.15, blue: 0.15, alpha: 1))
        ballMat.roughness = .init(floatLiteral: 0.15)
        ballMat.metallic  = .init(floatLiteral: 0.85)
        let ball = ModelEntity(mesh: .generateSphere(radius: 0.08), materials: [ballMat])
        ball.name = "vrBall"
        let ballAnchor = AnchorEntity(world: .zero)
        ballAnchor.addChild(ball)
        arView.scene.addAnchor(ballAnchor)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // カメラ位置・回転をARKitに同期（IPDオフセット付き）
        if let cam = uiView.scene.findEntity(named: "vrCamera") {
            let ipdOffset: Float = (eye == .left) ? -0.032 : 0.032
            var eyeT = matrix_identity_float4x4
            eyeT.columns.3 = simd_make_float4(ipdOffset, 0, 0, 1)
            cam.transform.matrix = tracker.cameraTransform * eyeT
        }

        // ハンドスケルトンの更新
        if let handAnchor = uiView.scene.findEntity(named: "handAnchor") {
            updateHandSkeleton(
                handAnchor: handAnchor,
                joints: tracker.handJoints,
                isPinching: tracker.isPinching,
                isGrabbing: tracker.isGrabbingBall
            )
        }

        // ボールの位置更新
        uiView.scene.findEntity(named: "vrBall")?.position = tracker.ballPosition
    }
}

#Preview {
    ContentView()
}
