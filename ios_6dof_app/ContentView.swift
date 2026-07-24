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
        // カメラ映像を表示できるように .ar モードで初期化し、共通セッションを割り当てる
        let arView = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        arView.session = tracker.session

        // 1. 部屋のバーチャルシーン構築
        setupVRChatHomeScene(in: arView)

        // 2. カスタムカメラ
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = 85
        camera.name = "vrCamera"
        let camAnchor = AnchorEntity(world: .zero)
        camAnchor.addChild(camera)
        arView.scene.addAnchor(camAnchor)

        // 3. ハンドスケルトン（リアルな肉付け＋骨格）
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

        // 5. 設定パネル (3D UI)
        let panelEntity = makeSettingsPanelEntity()
        let panelAnchor = AnchorEntity(world: .zero)
        panelAnchor.addChild(panelEntity)
        arView.scene.addAnchor(panelAnchor)

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        // パススルー切り替え（現世カメラ映像 vs 純粋VRモード）
        let isPassthrough = tracker.isPassthroughEnabled
        uiView.environment.background = isPassthrough ? .cameraFeed() : .color(.black)
        setHouseVisibility(in: uiView, visible: !isPassthrough)

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
                isGrabbing: tracker.isGrabbingBall || tracker.isGrabbingPanel
            )
        }

        // ボールの位置更新
        uiView.scene.findEntity(named: "vrBall")?.position = tracker.ballPosition

        // 設定パネルのインタラクション・位置更新
        if let panel = uiView.scene.findEntity(named: "settingsPanel") as? ModelEntity {
            updateSettingsPanel(panelEntity: panel, tracker: tracker)
        }
    }
}

#Preview {
    ContentView()
}
