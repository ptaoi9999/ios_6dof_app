import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        RealityView { content in
            // 簡易的な部屋のシミュレーションとして、中央に直方体を配置
            let boxMesh = MeshResource.generateBox(size: 1.0)
            let material = SimpleMaterial(color: .blue, isMetallic: true)
            let boxEntity = ModelEntity(mesh: boxMesh, materials: [material])
            boxEntity.position = [0, 0, -2] // カメラの前方2m
            
            content.add(boxEntity)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview {
    ContentView()
}
