import SwiftUI
import RealityKit
import ARKit

struct ContentView: View {
    var body: some View {
        ARViewContainer()
            .edgesIgnoringSafeArea(.all)
    }
}

struct ARViewContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // 簡易的な部屋のシミュレーションとして、中央に直方体を配置
        let boxMesh = MeshResource.generateBox(size: 1.0)
        let material = SimpleMaterial(color: .blue, isMetallic: true)
        let boxEntity = ModelEntity(mesh: boxMesh, materials: [material])
        boxEntity.position = [0, 0, -2] // カメラの前方2m
        
        // アンカーの作成と追加
        let anchor = AnchorEntity(world: .zero)
        anchor.addChild(boxEntity)
        arView.scene.addAnchor(anchor)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

#Preview {
    ContentView()
}
