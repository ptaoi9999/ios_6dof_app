import RealityKit
import UIKit

/// VRChat LaunchPad風の3Dメニューエンティティを生成する
func createLaunchPadEntity() -> ModelEntity {
    // パネル本体
    var panelMat = PhysicallyBasedMaterial()
    panelMat.baseColor  = .init(tint: UIColor(red: 0.04, green: 0.08, blue: 0.18, alpha: 0.85))
    panelMat.roughness  = .init(floatLiteral: 0.2)
    panelMat.metallic   = .init(floatLiteral: 0.5)
    let menuBase = ModelEntity(
        mesh: .generateBox(width: 0.44, height: 0.30, depth: 0.01),
        materials: [panelMat]
    )

    // タイトルバー（ネオンブルー）
    var titleMat = PhysicallyBasedMaterial()
    titleMat.baseColor        = .init(tint: UIColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 1))
    titleMat.roughness        = .init(floatLiteral: 0.1)
    titleMat.metallic         = .init(floatLiteral: 0.6)
    titleMat.emissiveColor    = .init(color: UIColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 1))
    titleMat.emissiveIntensity = 1.5
    let titleBar = ModelEntity(
        mesh: .generateBox(width: 0.40, height: 0.045, depth: 0.005),
        materials: [titleMat]
    )
    titleBar.position = [0, 0.115, 0.008]
    menuBase.addChild(titleBar)

    // ボタンA（ブルー）
    var btnMatA = PhysicallyBasedMaterial()
    btnMatA.baseColor        = .init(tint: .systemBlue)
    btnMatA.roughness        = .init(floatLiteral: 0.3)
    btnMatA.metallic         = .init(floatLiteral: 0.3)
    btnMatA.emissiveColor    = .init(color: UIColor(red: 0, green: 0.4, blue: 1, alpha: 1))
    btnMatA.emissiveIntensity = 0.5
    let btnA = ModelEntity(mesh: .generateBox(width: 0.16, height: 0.065, depth: 0.015), materials: [btnMatA])
    btnA.position = [-0.10, -0.015, 0.013]
    menuBase.addChild(btnA)

    // ボタンB（オレンジ）
    var btnMatB = PhysicallyBasedMaterial()
    btnMatB.baseColor        = .init(tint: .systemOrange)
    btnMatB.roughness        = .init(floatLiteral: 0.3)
    btnMatB.metallic         = .init(floatLiteral: 0.3)
    btnMatB.emissiveColor    = .init(color: UIColor(red: 1, green: 0.4, blue: 0, alpha: 1))
    btnMatB.emissiveIntensity = 0.5
    let btnB = ModelEntity(mesh: .generateBox(width: 0.16, height: 0.065, depth: 0.015), materials: [btnMatB])
    btnB.position = [0.10, -0.015, 0.013]
    menuBase.addChild(btnB)

    // 枠ボーダー（グロウ風）
    var borderMat = PhysicallyBasedMaterial()
    borderMat.baseColor        = .init(tint: UIColor(red: 0.0, green: 0.7, blue: 1.0, alpha: 1))
    borderMat.roughness        = .init(floatLiteral: 0.1)
    borderMat.metallic         = .init(floatLiteral: 0.8)
    borderMat.emissiveColor    = .init(color: UIColor(red: 0.0, green: 0.6, blue: 1.0, alpha: 1))
    borderMat.emissiveIntensity = 0.8
    // 上辺
    let bTop = ModelEntity(mesh: .generateBox(width: 0.44, height: 0.006, depth: 0.003), materials: [borderMat])
    bTop.position = [0, 0.147, 0.007]
    menuBase.addChild(bTop)
    // 下辺
    let bBot = ModelEntity(mesh: .generateBox(width: 0.44, height: 0.006, depth: 0.003), materials: [borderMat])
    bBot.position = [0, -0.147, 0.007]
    menuBase.addChild(bBot)

    return menuBase
}
