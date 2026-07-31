import RealityKit
import UIKit

/// 部屋の静的シーン（VRChat Cozy Cabin風）をセットアップする
func setupVRChatHomeScene(in arView: ARView) {
    let anchor = AnchorEntity(world: .zero)
    anchor.name = "houseAnchor"

    // MARK: - マテリアル定義
    var wallMat = PhysicallyBasedMaterial()
    wallMat.baseColor = .init(tint: UIColor(red: 0.93, green: 0.91, blue: 0.86, alpha: 1))
    wallMat.roughness = .init(floatLiteral: 0.9)
    wallMat.metallic  = .init(floatLiteral: 0.0)

    var floorMat = PhysicallyBasedMaterial()
    floorMat.baseColor = .init(tint: UIColor(red: 0.22, green: 0.14, blue: 0.08, alpha: 1))
    floorMat.roughness = .init(floatLiteral: 0.6)
    floorMat.metallic  = .init(floatLiteral: 0.0)

    var ceilMat = PhysicallyBasedMaterial()
    ceilMat.baseColor = .init(tint: UIColor(red: 0.88, green: 0.85, blue: 0.80, alpha: 1))
    ceilMat.roughness = .init(floatLiteral: 0.95)
    ceilMat.metallic  = .init(floatLiteral: 0.0)

    var woodMat = PhysicallyBasedMaterial()
    woodMat.baseColor = .init(tint: UIColor(red: 0.42, green: 0.26, blue: 0.12, alpha: 1))
    woodMat.roughness = .init(floatLiteral: 0.65)
    woodMat.metallic  = .init(floatLiteral: 0.0)

    var stoneMat = PhysicallyBasedMaterial()
    stoneMat.baseColor = .init(tint: UIColor(red: 0.45, green: 0.42, blue: 0.40, alpha: 1))
    stoneMat.roughness = .init(floatLiteral: 0.92)
    stoneMat.metallic  = .init(floatLiteral: 0.0)

    var fireMat = PhysicallyBasedMaterial()
    fireMat.baseColor      = .init(tint: UIColor(red: 1.0, green: 0.45, blue: 0.0, alpha: 1))
    fireMat.roughness      = .init(floatLiteral: 1.0)
    fireMat.metallic       = .init(floatLiteral: 0.0)
    fireMat.emissiveColor  = .init(color: UIColor(red: 1.0, green: 0.4, blue: 0.0, alpha: 1))
    fireMat.emissiveIntensity = 3.5

    var fabricMat = PhysicallyBasedMaterial()
    fabricMat.baseColor = .init(tint: UIColor(red: 0.18, green: 0.24, blue: 0.20, alpha: 1))
    fabricMat.roughness = .init(floatLiteral: 0.98)
    fabricMat.metallic  = .init(floatLiteral: 0.0)

    var rugMat = PhysicallyBasedMaterial()
    rugMat.baseColor = .init(tint: UIColor(red: 0.78, green: 0.70, blue: 0.58, alpha: 1))
    rugMat.roughness = .init(floatLiteral: 1.0)
    rugMat.metallic  = .init(floatLiteral: 0.0)

    var glassMat = PhysicallyBasedMaterial()
    glassMat.baseColor       = .init(tint: UIColor(red: 0.7, green: 0.85, blue: 0.95, alpha: 0.25))
    glassMat.roughness       = .init(floatLiteral: 0.05)
    glassMat.metallic        = .init(floatLiteral: 0.0)
    glassMat.blending        = .transparent(opacity: .init(floatLiteral: 0.25))

    var starMat = PhysicallyBasedMaterial()
    starMat.baseColor        = .init(tint: .white)
    starMat.emissiveColor    = .init(color: .white)
    starMat.emissiveIntensity = 2.0

    var tvMat = PhysicallyBasedMaterial()
    tvMat.baseColor = .init(tint: UIColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1))
    tvMat.roughness = .init(floatLiteral: 0.05)
    tvMat.metallic  = .init(floatLiteral: 0.8)

    // MARK: - 部屋の構造
    let floor = ModelEntity(mesh: .generateBox(width: 10, height: 0.12, depth: 10), materials: [floorMat])
    floor.position = [0, -1.26, 0]
    anchor.addChild(floor)

    let ceiling = ModelEntity(mesh: .generateBox(width: 10, height: 0.12, depth: 10), materials: [ceilMat])
    ceiling.position = [0, 1.86, 0]
    anchor.addChild(ceiling)

    for xOff: Float in [-2.5, 2.5] {
        var beamMat = PhysicallyBasedMaterial()
        beamMat.baseColor = .init(tint: UIColor(red: 0.32, green: 0.20, blue: 0.10, alpha: 1))
        beamMat.roughness = .init(floatLiteral: 0.7)
        let beam = ModelEntity(mesh: .generateBox(width: 0.18, height: 0.18, depth: 10.2), materials: [beamMat])
        beam.position = [xOff, 1.75, 0]
        anchor.addChild(beam)
    }

    let backWallL = ModelEntity(mesh: .generateBox(width: 3.2, height: 3.2, depth: 0.12), materials: [wallMat])
    backWallL.position = [-3.4, 0.2, -5]
    anchor.addChild(backWallL)
    let backWallR = ModelEntity(mesh: .generateBox(width: 3.2, height: 3.2, depth: 0.12), materials: [wallMat])
    backWallR.position = [3.4, 0.2, -5]
    anchor.addChild(backWallR)

    let winFrameTop  = ModelEntity(mesh: .generateBox(width: 3.8, height: 0.12, depth: 0.15), materials: [woodMat])
    winFrameTop.position = [0, 1.3, -5.0]
    anchor.addChild(winFrameTop)
    let winFrameBot  = ModelEntity(mesh: .generateBox(width: 3.8, height: 0.12, depth: 0.15), materials: [woodMat])
    winFrameBot.position = [0, -0.6, -5.0]
    anchor.addChild(winFrameBot)
    let winFrameL    = ModelEntity(mesh: .generateBox(width: 0.12, height: 1.92, depth: 0.15), materials: [woodMat])
    winFrameL.position = [-1.84, 0.36, -5.0]
    anchor.addChild(winFrameL)
    let winFrameR    = ModelEntity(mesh: .generateBox(width: 0.12, height: 1.92, depth: 0.15), materials: [woodMat])
    winFrameR.position = [1.84, 0.36, -5.0]
    anchor.addChild(winFrameR)
    let windowGlass  = ModelEntity(mesh: .generateBox(width: 3.6, height: 1.92, depth: 0.02), materials: [glassMat])
    windowGlass.position = [0, 0.36, -4.98]
    anchor.addChild(windowGlass)

    for (mesh, pos) in [
        (MeshResource.generateBox(width: 10, height: 3.2, depth: 0.12), SIMD3<Float>(0, 0.2, 5)),
        (MeshResource.generateBox(width: 0.12, height: 3.2, depth: 10), SIMD3<Float>(-5, 0.2, 0)),
        (MeshResource.generateBox(width: 0.12, height: 3.2, depth: 10), SIMD3<Float>(5, 0.2, 0))
    ] {
        let w = ModelEntity(mesh: mesh, materials: [wallMat])
        w.position = pos
        anchor.addChild(w)
    }

    var skirtMat = PhysicallyBasedMaterial()
    skirtMat.baseColor = .init(tint: UIColor(red: 0.95, green: 0.93, blue: 0.90, alpha: 1))
    skirtMat.roughness = .init(floatLiteral: 0.5)
    for (size, pos) in [
        (SIMD3<Float>(10, 0.08, 0.06), SIMD3<Float>(0, -1.16, -5.03)),
        (SIMD3<Float>(10, 0.08, 0.06), SIMD3<Float>(0, -1.16,  5.03)),
        (SIMD3<Float>(0.06, 0.08, 10), SIMD3<Float>(-5.03, -1.16, 0)),
        (SIMD3<Float>(0.06, 0.08, 10), SIMD3<Float>( 5.03, -1.16, 0))
    ] {
        let sb = ModelEntity(mesh: .generateBox(size: size), materials: [skirtMat])
        sb.position = pos
        anchor.addChild(sb)
    }

    // MARK: - 暖炉
    let fpBase = ModelEntity(mesh: .generateBox(width: 1.8, height: 0.25, depth: 1.8), materials: [stoneMat])
    fpBase.position = [3.5, -1.13, -4.1]
    anchor.addChild(fpBase)
    let fpLWall = ModelEntity(mesh: .generateBox(width: 0.28, height: 1.4, depth: 1.4), materials: [stoneMat])
    fpLWall.position = [2.7, -0.4, -4.1]
    anchor.addChild(fpLWall)
    let fpBWall = ModelEntity(mesh: .generateBox(width: 1.8, height: 1.4, depth: 0.28), materials: [stoneMat])
    fpBWall.position = [3.5, -0.4, -4.74]
    anchor.addChild(fpBWall)
    let fpMantel = ModelEntity(mesh: .generateBox(width: 2.0, height: 0.14, depth: 0.55), materials: [woodMat])
    fpMantel.position = [3.5, 0.35, -4.1]
    anchor.addChild(fpMantel)
    for (off, sc): (SIMD3<Float>, Float) in [([0, 0, 0], 0.15), ([-0.1, -0.03, 0.05], 0.09), ([0.1, -0.05, 0.04], 0.07)] {
        let f = ModelEntity(mesh: .generateSphere(radius: sc), materials: [fireMat])
        f.position = [3.5 + off.x, -0.85 + off.y, -4.1 + off.z]
        anchor.addChild(f)
    }
    var brickMat = PhysicallyBasedMaterial()
    brickMat.baseColor = .init(tint: UIColor(red: 0.52, green: 0.38, blue: 0.30, alpha: 1))
    brickMat.roughness = .init(floatLiteral: 0.95)
    let hearth = ModelEntity(mesh: .generateBox(width: 1.8, height: 0.02, depth: 1.4), materials: [brickMat])
    hearth.position = [3.5, -1.19, -3.5]
    anchor.addChild(hearth)

    // MARK: - 家具
    let tableTop = ModelEntity(mesh: .generateBox(width: 1.5, height: 0.06, depth: 0.9), materials: [woodMat])
    tableTop.position = [-0.5, -0.85, -1.8]
    anchor.addChild(tableTop)
    let legMesh = MeshResource.generateBox(width: 0.06, height: 0.38, depth: 0.06)
    for pos: SIMD3<Float> in [[-1.18, -1.04, -2.2], [0.18, -1.04, -2.2],
                                [-1.18, -1.04, -1.4], [0.18, -1.04, -1.4]] {
        let leg = ModelEntity(mesh: legMesh, materials: [woodMat])
        leg.position = pos
        anchor.addChild(leg)
    }

    let seat = ModelEntity(mesh: .generateBox(width: 2.4, height: 0.30, depth: 0.90), materials: [fabricMat])
    seat.position = [-0.3, -0.95, 0.55]
    anchor.addChild(seat)
    let back = ModelEntity(mesh: .generateBox(width: 2.4, height: 0.75, depth: 0.18), materials: [fabricMat])
    back.position = [-0.3, -0.58, 1.0]
    anchor.addChild(back)
    for (xp, dep): (Float, Float) in [(-1.5, 0.90), (0.9, 0.90)] {
        let arm = ModelEntity(mesh: .generateBox(width: 0.20, height: 0.50, depth: dep), materials: [fabricMat])
        arm.position = [xp, -0.80, 0.55]
        anchor.addChild(arm)
    }
    var cushMat = PhysicallyBasedMaterial()
    cushMat.baseColor = .init(tint: UIColor(red: 0.28, green: 0.36, blue: 0.30, alpha: 1))
    cushMat.roughness = .init(floatLiteral: 0.95)
    for xOff: Float in [-0.8, 0.0, 0.8] {
        let cush = ModelEntity(mesh: .generateBox(width: 0.68, height: 0.14, depth: 0.68), materials: [cushMat])
        cush.position = [xOff - 0.3, -0.79, 0.55]
        anchor.addChild(cush)
    }

    let rug = ModelEntity(mesh: .generateBox(width: 2.6, height: 0.015, depth: 2.0), materials: [rugMat])
    rug.position = [-0.3, -1.19, -1.5]
    anchor.addChild(rug)

    let tvBoard = ModelEntity(mesh: .generateBox(width: 2.4, height: 0.40, depth: 0.50), materials: [woodMat])
    tvBoard.position = [0, -1.0, -4.8]
    anchor.addChild(tvBoard)
    let tvScreen = ModelEntity(mesh: .generateBox(width: 1.6, height: 0.92, depth: 0.05), materials: [tvMat])
    tvScreen.position = [0, -0.45, -4.76]
    anchor.addChild(tvScreen)
    var tvFrameMat = PhysicallyBasedMaterial()
    tvFrameMat.baseColor = .init(tint: UIColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1))
    tvFrameMat.roughness = .init(floatLiteral: 0.3)
    tvFrameMat.metallic  = .init(floatLiteral: 0.7)
    let tvFrame = ModelEntity(mesh: .generateBox(width: 1.72, height: 1.04, depth: 0.04), materials: [tvFrameMat])
    tvFrame.position = [0, -0.45, -4.78]
    anchor.addChild(tvFrame)

    var doorMat = PhysicallyBasedMaterial()
    doorMat.baseColor = .init(tint: UIColor(red: 0.30, green: 0.16, blue: 0.08, alpha: 1))
    doorMat.roughness = .init(floatLiteral: 0.6)
    let door = ModelEntity(mesh: .generateBox(width: 0.07, height: 2.1, depth: 1.05), materials: [doorMat])
    door.position = [-4.97, -0.15, -2.0]
    anchor.addChild(door)
    var knobMat = PhysicallyBasedMaterial()
    knobMat.baseColor = .init(tint: UIColor(red: 0.8, green: 0.65, blue: 0.2, alpha: 1))
    knobMat.roughness = .init(floatLiteral: 0.2)
    knobMat.metallic  = .init(floatLiteral: 0.9)
    let knob = ModelEntity(mesh: .generateSphere(radius: 0.04), materials: [knobMat])
    knob.position = [-4.90, -0.15, -1.57]
    anchor.addChild(knob)

    var potMat = PhysicallyBasedMaterial()
    potMat.baseColor = .init(tint: UIColor(red: 0.55, green: 0.45, blue: 0.35, alpha: 1))
    potMat.roughness = .init(floatLiteral: 0.85)
    let pot = ModelEntity(mesh: .generateBox(width: 0.44, height: 0.45, depth: 0.44), materials: [potMat])
    pot.position = [-4.0, -1.0, -4.2]
    anchor.addChild(pot)
    var leafMat = PhysicallyBasedMaterial()
    leafMat.baseColor = .init(tint: UIColor(red: 0.12, green: 0.40, blue: 0.15, alpha: 1))
    leafMat.roughness = .init(floatLiteral: 0.8)
    for (off, sc): (SIMD3<Float>, Float) in [([0, 0, 0], 0.35), ([-0.2, 0.1, 0.1], 0.22), ([0.18, 0.15, -0.1], 0.20)] {
        let leaf = ModelEntity(mesh: .generateSphere(radius: sc), materials: [leafMat])
        leaf.position = [-4.0 + off.x, -0.5 + off.y, -4.2 + off.z]
        anchor.addChild(leaf)
    }

    let shelf = ModelEntity(mesh: .generateBox(width: 0.8, height: 0.06, depth: 0.20), materials: [woodMat])
    shelf.position = [3.5, 0.42, -4.62]
    anchor.addChild(shelf)
    var frameMat = PhysicallyBasedMaterial()
    frameMat.baseColor = .init(tint: UIColor(red: 0.7, green: 0.58, blue: 0.3, alpha: 1))
    frameMat.roughness = .init(floatLiteral: 0.3)
    frameMat.metallic  = .init(floatLiteral: 0.6)
    let frame = ModelEntity(mesh: .generateBox(width: 0.18, height: 0.22, depth: 0.03), materials: [frameMat])
    frame.position = [3.5, 0.60, -4.63]
    anchor.addChild(frame)

    var fireLightComp = PointLightComponent()
    fireLightComp.color      = UIColor(red: 1.0, green: 0.55, blue: 0.2, alpha: 1)
    fireLightComp.intensity  = 500
    fireLightComp.attenuationRadius = 3.5
    let fireLight = Entity()
    fireLight.components.set(fireLightComp)
    fireLight.position = [3.5, -0.4, -4.1]
    anchor.addChild(fireLight)

    var ceilLightComp = PointLightComponent()
    ceilLightComp.color      = UIColor(red: 1.0, green: 0.95, blue: 0.85, alpha: 1)
    ceilLightComp.intensity  = 300
    ceilLightComp.attenuationRadius = 8.0
    let ceilLight = Entity()
    ceilLight.components.set(ceilLightComp)
    ceilLight.position = [0, 1.5, -1.0]
    anchor.addChild(ceilLight)

    for pos: SIMD3<Float> in [[-1.2, 0.8, -12], [0.3, 1.3, -14], [1.5, 0.6, -11],
                               [-0.5, 0.3, -13], [0.9, 1.5, -12], [-1.8, 1.4, -10],
                               [0.0, 0.1, -11],  [1.3, 1.0, -13]] {
        let s = ModelEntity(mesh: .generateSphere(radius: 0.03), materials: [starMat])
        s.position = pos
        anchor.addChild(s)
    }
    var moonMat = PhysicallyBasedMaterial()
    moonMat.baseColor        = .init(tint: UIColor(red: 0.96, green: 0.96, blue: 0.88, alpha: 1))
    moonMat.emissiveColor    = .init(color: UIColor(red: 0.9, green: 0.9, blue: 0.8, alpha: 1))
    moonMat.emissiveIntensity = 0.8
    moonMat.roughness        = .init(floatLiteral: 0.85)
    let moon = ModelEntity(mesh: .generateSphere(radius: 0.35), materials: [moonMat])
    moon.position = [-1.0, 1.2, -16]
    anchor.addChild(moon)

    // MARK: - NPC（ソファでくつろぐ人）
    buildLoungingNPC(parent: anchor)

    arView.scene.addAnchor(anchor)
}

// MARK: - NPC ビルダー

/// ソファの上に横になってゴロゴロしている人型NPCを構築する
/// ソファ中心: [-0.3, -0.95, 0.55]（座面上面 y ≈ -0.80）
private func buildLoungingNPC(parent: Entity) {

    // --- 肌・服 マテリアル ---
    var skinMat = PhysicallyBasedMaterial()
    skinMat.baseColor = .init(tint: UIColor(red: 0.92, green: 0.74, blue: 0.62, alpha: 1))
    skinMat.roughness = .init(floatLiteral: 0.85)
    skinMat.metallic  = .init(floatLiteral: 0.0)

    var shirtMat = PhysicallyBasedMaterial()
    shirtMat.baseColor = .init(tint: UIColor(red: 0.55, green: 0.70, blue: 0.85, alpha: 1))
    shirtMat.roughness = .init(floatLiteral: 0.90)
    shirtMat.metallic  = .init(floatLiteral: 0.0)

    var pantsMat = PhysicallyBasedMaterial()
    pantsMat.baseColor = .init(tint: UIColor(red: 0.25, green: 0.30, blue: 0.40, alpha: 1))
    pantsMat.roughness = .init(floatLiteral: 0.85)
    pantsMat.metallic  = .init(floatLiteral: 0.0)

    var hairMat = PhysicallyBasedMaterial()
    hairMat.baseColor = .init(tint: UIColor(red: 0.20, green: 0.14, blue: 0.10, alpha: 1))
    hairMat.roughness = .init(floatLiteral: 0.95)
    hairMat.metallic  = .init(floatLiteral: 0.0)

    // ソファ座面の上面 y ≈ -0.80
    // NPC は X 軸方向（左右）に横向きに寝る
    // 体の中心 x=-0.3, z=0.55 を基準とする

    let baseX: Float = -0.3
    let baseY: Float = -0.80   // 座面上面
    let baseZ: Float = 0.55

    // --- ルートエンティティ（NPC全体をまとめる）---
    let npc = Entity()
    npc.name = "npcLounging"
    parent.addChild(npc)

    // ─── 胴体（Torso） ───
    // 幅0.40, 高さ0.22, 奥行0.28  →  X方向に横に寝かせるので width と height を入れ替え
    // 横向き寝: 長軸を X 軸に
    let torso = ModelEntity(
        mesh: .generateBox(width: 0.90, height: 0.22, depth: 0.28, cornerRadius: 0.04),
        materials: [shirtMat]
    )
    torso.position = [baseX, baseY + 0.11, baseZ]
    npc.addChild(torso)

    // ─── 頭 ───
    let head = ModelEntity(mesh: .generateSphere(radius: 0.115), materials: [skinMat])
    head.position = [baseX + 0.55, baseY + 0.22, baseZ]
    npc.addChild(head)

    // ─── 髪（頭の上を覆う楕円）───
    let hair = ModelEntity(
        mesh: .generateBox(width: 0.23, height: 0.07, depth: 0.22, cornerRadius: 0.06),
        materials: [hairMat]
    )
    hair.position = [baseX + 0.55, baseY + 0.32, baseZ]
    npc.addChild(hair)

    // ─── 首 ───
    let neck = ModelEntity(
        mesh: .generateBox(width: 0.12, height: 0.08, depth: 0.10, cornerRadius: 0.02),
        materials: [skinMat]
    )
    neck.position = [baseX + 0.43, baseY + 0.20, baseZ]
    npc.addChild(neck)

    // ─── 腕（上腕）：両腕を前に曲げて添える ───
    // 上腕 (X方向長）
    let upperArmMesh = MeshResource.generateBox(width: 0.30, height: 0.11, depth: 0.10, cornerRadius: 0.03)

    // 前腕（少し短め、Z方向に折り曲げる）
    let foreArmMesh  = MeshResource.generateBox(width: 0.10, height: 0.10, depth: 0.25, cornerRadius: 0.03)

    // 上腕（前方）
    let upperArmF = ModelEntity(mesh: upperArmMesh, materials: [shirtMat])
    upperArmF.position = [baseX + 0.35, baseY + 0.22, baseZ - 0.18]
    npc.addChild(upperArmF)

    // 前腕（前方）
    let foreArmF = ModelEntity(mesh: foreArmMesh, materials: [skinMat])
    foreArmF.position = [baseX + 0.28, baseY + 0.22, baseZ - 0.33]
    npc.addChild(foreArmF)

    // ─── 手（手のひら）───
    let handMesh = MeshResource.generateBox(width: 0.09, height: 0.07, depth: 0.12, cornerRadius: 0.02)
    let handF = ModelEntity(mesh: handMesh, materials: [skinMat])
    handF.position = [baseX + 0.27, baseY + 0.22, baseZ - 0.46]
    npc.addChild(handF)

    // ─── 腰～骨盤部 ───
    let hip = ModelEntity(
        mesh: .generateBox(width: 0.45, height: 0.22, depth: 0.28, cornerRadius: 0.04),
        materials: [pantsMat]
    )
    hip.position = [baseX - 0.43, baseY + 0.11, baseZ]
    npc.addChild(hip)

    // ─── 太もも（大腿）───
    let thighMesh = MeshResource.generateBox(width: 0.40, height: 0.16, depth: 0.15, cornerRadius: 0.03)

    // 太もも1本目
    let thigh1 = ModelEntity(mesh: thighMesh, materials: [pantsMat])
    thigh1.position = [baseX - 0.80, baseY + 0.08, baseZ - 0.06]
    npc.addChild(thigh1)

    // 太もも2本目（上に重ねる）
    let thigh2 = ModelEntity(mesh: thighMesh, materials: [pantsMat])
    thigh2.position = [baseX - 0.80, baseY + 0.22, baseZ - 0.02]
    npc.addChild(thigh2)

    // ─── すね（膝下）：膝を少し曲げて Z 方向後ろに ───
    let shinMesh = MeshResource.generateBox(width: 0.10, height: 0.14, depth: 0.38, cornerRadius: 0.03)

    let shin1 = ModelEntity(mesh: shinMesh, materials: [pantsMat])
    shin1.position = [baseX - 0.98, baseY + 0.07, baseZ + 0.11]
    npc.addChild(shin1)

    let shin2 = ModelEntity(mesh: shinMesh, materials: [pantsMat])
    shin2.position = [baseX - 0.98, baseY + 0.22, baseZ + 0.11]
    npc.addChild(shin2)

    // ─── 足（つま先）───
    let footMesh = MeshResource.generateBox(width: 0.09, height: 0.08, depth: 0.20, cornerRadius: 0.02)

    let foot1 = ModelEntity(mesh: footMesh, materials: [skinMat])
    foot1.position = [baseX - 1.00, baseY + 0.04, baseZ + 0.22]
    npc.addChild(foot1)

    let foot2 = ModelEntity(mesh: footMesh, materials: [skinMat])
    foot2.position = [baseX - 1.00, baseY + 0.18, baseZ + 0.22]
    npc.addChild(foot2)

    // ─── 枕 ───
    var pilMat = PhysicallyBasedMaterial()
    pilMat.baseColor = .init(tint: UIColor(red: 0.95, green: 0.92, blue: 0.88, alpha: 1))
    pilMat.roughness = .init(floatLiteral: 0.95)
    let pillow = ModelEntity(
        mesh: .generateBox(width: 0.26, height: 0.10, depth: 0.42, cornerRadius: 0.05),
        materials: [pilMat]
    )
    pillow.position = [baseX + 0.56, baseY + 0.05, baseZ]
    npc.addChild(pillow)
}

/// バーチャルハウスの表示/非表示（パススルー切替用）
func setHouseVisibility(in arView: ARView, visible: Bool) {
    if let house = arView.scene.findEntity(named: "houseAnchor") {
        house.scale = visible ? SIMD3<Float>(1, 1, 1) : SIMD3<Float>.zero
    }
}
