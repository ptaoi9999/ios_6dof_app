import RealityKit
import UIKit
import simd

/// 設定パネルの構築およびタッチ・移動制御を行うモジュール
func makeSettingsPanelEntity() -> ModelEntity {
    // パネル本体（PBRスレートグレー）
    var panelMat = PhysicallyBasedMaterial()
    panelMat.baseColor = .init(tint: UIColor(red: 0.12, green: 0.15, blue: 0.20, alpha: 0.90))
    panelMat.roughness = .init(floatLiteral: 0.3)
    panelMat.metallic  = .init(floatLiteral: 0.6)
    
    let panelBase = ModelEntity(
        mesh: .generateBox(width: 0.36, height: 0.24, depth: 0.015),
        materials: [panelMat]
    )
    panelBase.name = "settingsPanel"

    // ヘッダー（掴み用の持ち手バー）
    var headerMat = PhysicallyBasedMaterial()
    headerMat.baseColor        = .init(tint: UIColor(red: 0.0, green: 0.5, blue: 0.9, alpha: 1.0))
    headerMat.emissiveColor    = .init(color: UIColor(red: 0.0, green: 0.5, blue: 0.9, alpha: 1.0))
    headerMat.emissiveIntensity = 1.0
    headerMat.roughness        = .init(floatLiteral: 0.2)
    headerMat.metallic         = .init(floatLiteral: 0.8)

    let headerBar = ModelEntity(
        mesh: .generateBox(width: 0.34, height: 0.035, depth: 0.02),
        materials: [headerMat]
    )
    headerBar.name = "panelHeader"
    headerBar.position = [0, 0.09, 0.005]
    panelBase.addChild(headerBar)

    // パススルー切り替えボタン (立体ボタン)
    var btnMat = PhysicallyBasedMaterial()
    btnMat.baseColor = .init(tint: .systemGray)
    btnMat.roughness = .init(floatLiteral: 0.3)
    btnMat.metallic  = .init(floatLiteral: 0.4)

    let passthroughBtn = ModelEntity(
        mesh: .generateBox(width: 0.24, height: 0.07, depth: 0.025),
        materials: [btnMat]
    )
    passthroughBtn.name = "btnPassthrough"
    passthroughBtn.position = [0, -0.02, 0.01]
    panelBase.addChild(passthroughBtn)

    // ボタン上のステータスインジケーター（小さな発光LED風球体）
    var ledMat = PhysicallyBasedMaterial()
    ledMat.baseColor = .init(tint: .red)
    ledMat.emissiveColor = .init(color: .red)
    ledMat.emissiveIntensity = 1.0
    
    let led = ModelEntity(mesh: .generateSphere(radius: 0.01), materials: [ledMat])
    led.name = "btnLED"
    led.position = [0.09, 0, 0.015]
    passthroughBtn.addChild(led)

    return panelBase
}

/// 毎フレームの設定パネルのインタラクション更新
func updateSettingsPanel(
    panelEntity: ModelEntity,
    tracker: ARTracker
) {
    // パネルの位置更新（掴んで移動中、または初期設定）
    panelEntity.transform.matrix = tracker.panelTransform

    // パススルーボタンのビジュアル更新 (ON/OFF状態)
    if let btn = panelEntity.findEntity(named: "btnPassthrough") as? ModelEntity {
        let isOn = tracker.isPassthroughEnabled
        
        // ボタンが押されている間の少しへこむアニメーション位置
        let targetZ: Float = tracker.isBtnPressed ? 0.002 : 0.01
        btn.position.z = targetZ
        
        var btnMat = PhysicallyBasedMaterial()
        btnMat.baseColor = .init(tint: isOn ? UIColor.systemGreen : UIColor.systemGray)
        btnMat.roughness = .init(floatLiteral: 0.3)
        btnMat.metallic  = .init(floatLiteral: 0.4)
        if isOn {
            btnMat.emissiveColor = .init(color: UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 1))
            btnMat.emissiveIntensity = 0.8
        }
        btn.model?.materials = [btnMat]

        // LEDインジケーターの更新
        if let led = btn.findEntity(named: "btnLED") as? ModelEntity {
            var ledMat = PhysicallyBasedMaterial()
            let ledColor: UIColor = isOn ? .green : .red
            ledMat.baseColor = .init(tint: ledColor)
            ledMat.emissiveColor = .init(color: ledColor)
            ledMat.emissiveIntensity = isOn ? 2.5 : 1.0
            led.model?.materials = [ledMat]
        }
    }
}
