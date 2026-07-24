import RealityKit
import UIKit
import simd

/// 手の骨格ジョイント名リスト（VNHumanHandPoseObservationのrawValueキーに対応）
let kHandJointNames: [String] = [
    "wrist",
    // 親指
    "VNHHPRK_TBT", "VNHHPRK_TMP", "VNHHPRK_TIP", "VNHHPRK_TTX",
    // 人差し指
    "VNHHPRK_ICP", "VNHHPRK_IPP", "VNHHPRK_IIP", "VNHHPRK_ITX",
    // 中指
    "VNHHPRK_MCP", "VNHHPRK_MPP", "VNHHPRK_MIP", "VNHHPRK_MTX",
    // 薬指
    "VNHHPRK_RCP", "VNHHPRK_RPP", "VNHHPRK_RIP", "VNHHPRK_RTX",
    // 小指
    "VNHHPRK_PCP", "VNHHPRK_PPP", "VNHHPRK_PIP", "VNHHPRK_PTX"
]

/// ハンドスケルトンのボーン接続（各ペアは親→子の方向）
let kHandBones: [(String, String)] = [
    // 手首から各指のMCP
    ("wrist", "VNHHPRK_ICP"),
    ("wrist", "VNHHPRK_MCP"),
    ("wrist", "VNHHPRK_RCP"),
    ("wrist", "VNHHPRK_PCP"),
    ("wrist", "VNHHPRK_TBT"),
    // 人差し指
    ("VNHHPRK_ICP", "VNHHPRK_IPP"),
    ("VNHHPRK_IPP", "VNHHPRK_IIP"),
    ("VNHHPRK_IIP", "VNHHPRK_ITX"),
    // 中指
    ("VNHHPRK_MCP", "VNHHPRK_MPP"),
    ("VNHHPRK_MPP", "VNHHPRK_MIP"),
    ("VNHHPRK_MIP", "VNHHPRK_MTX"),
    // 薬指
    ("VNHHPRK_RCP", "VNHHPRK_RPP"),
    ("VNHHPRK_RPP", "VNHHPRK_RIP"),
    ("VNHHPRK_RIP", "VNHHPRK_RTX"),
    // 小指
    ("VNHHPRK_PCP", "VNHHPRK_PPP"),
    ("VNHHPRK_PPP", "VNHHPRK_PIP"),
    ("VNHHPRK_PIP", "VNHHPRK_PTX"),
    // 親指
    ("VNHHPRK_TBT", "VNHHPRK_TMP"),
    ("VNHHPRK_TMP", "VNHHPRK_TIP"),
    ("VNHHPRK_TIP", "VNHHPRK_TTX")
]

/// ハンドスケルトンのRealityKitエンティティ（ジョイント球体）を生成する
func makeHandSkeletonAnchor() -> AnchorEntity {
    let anchor = AnchorEntity(world: .zero)
    anchor.name = "handAnchor"

    for name in kHandJointNames {
        let isTip  = name.hasSuffix("TX") || name.hasSuffix("TTX")
        let isMCP  = name.hasSuffix("CP") || name == "wrist"
        let radius: Float = isTip ? 0.011 : (isMCP ? 0.010 : 0.008)

        // 肌色のPBRライクなマテリアル
        var mat = PhysicallyBasedMaterial()
        mat.baseColor = .init(tint: UIColor(red: 0.85, green: 0.72, blue: 0.62, alpha: 1.0))
        mat.roughness = .init(floatLiteral: 0.7)
        mat.metallic  = .init(floatLiteral: 0.0)

        let mesh   = MeshResource.generateSphere(radius: radius)
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        entity.name  = "joint_\(name)"
        entity.scale = .zero
        anchor.addChild(entity)
    }

    // ボーン（細い円柱）を追加
    for (_, _) in kHandBones {
        var boneMat = PhysicallyBasedMaterial()
        boneMat.baseColor = .init(tint: UIColor(red: 0.80, green: 0.67, blue: 0.58, alpha: 1.0))
        boneMat.roughness = .init(floatLiteral: 0.8)
        boneMat.metallic  = .init(floatLiteral: 0.0)

        // プレースホルダー（位置は updateHandSkeleton で毎フレーム更新）
        let boneMesh   = MeshResource.generateBox(width: 0.005, height: 0.001, depth: 0.005)
        let boneEntity = ModelEntity(mesh: boneMesh, materials: [boneMat])
        boneEntity.name  = "bone_placeholder"
        boneEntity.scale = SIMD3<Float>.zero
        anchor.addChild(boneEntity)
    }

    return anchor
}

/// 毎フレーム、手の骨格エンティティを joints辞書に基づいて更新する
func updateHandSkeleton(
    handAnchor: Entity,
    joints: [String: simd_float3]?,
    isPinching: Bool,
    isGrabbing: Bool
) {
    // 状態によるカラー
    let pinchTint  = UIColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1.0)
    let grabTint   = UIColor(red: 0.4, green: 0.9, blue: 0.5, alpha: 1.0)
    let skinTint   = UIColor(red: 0.85, green: 0.72, blue: 0.62, alpha: 1.0)
    let activeTint = isGrabbing ? grabTint : (isPinching ? pinchTint : skinTint)

    // ジョイント球体の更新
    var boneEntities: [ModelEntity] = []

    for child in handAnchor.children {
        guard child.name.hasPrefix("joint_") else { continue }
        let key = String(child.name.dropFirst("joint_".count))

        if let pos = joints?[key] {
            child.position = pos
            child.scale    = [1, 1, 1]
            if let me = child as? ModelEntity {
                var mat = PhysicallyBasedMaterial()
                mat.baseColor = .init(tint: activeTint)
                mat.roughness = .init(floatLiteral: 0.7)
                mat.metallic  = .init(floatLiteral: 0.0)
                me.model?.materials = [mat]
            }
        } else {
            child.scale = .zero
        }
    }

    // ボーン（円柱）の更新
    for child in handAnchor.children where child.name == "bone_placeholder" {
        boneEntities.append(child as? ModelEntity ?? ModelEntity())
    }

    guard let joints = joints else {
        for b in boneEntities { b.scale = .zero }
        return
    }

    for (idx, (fromKey, toKey)) in kHandBones.enumerated() {
        guard idx < boneEntities.count,
              let fromPos = joints[fromKey],
              let toPos   = joints[toKey]
        else {
            if idx < boneEntities.count { boneEntities[idx].scale = .zero }
            continue
        }

        let bone = boneEntities[idx]
        let diff = toPos - fromPos
        let len  = simd_length(diff)
        guard len > 0.001 else { bone.scale = .zero; continue }

        // ボーンを中点に配置し、長さと向きを調整
        bone.position = (fromPos + toPos) * 0.5
        bone.scale    = [1, 1, len / 0.001] // 元のheight=0.001に合わせてscale.z=len/0.001

        // Y→diffの方向へ回転
        let up     = simd_make_float3(0, 1, 0)
        let dir    = simd_normalize(diff)
        let cross  = simd_cross(up, dir)
        let dot    = simd_dot(up, dir)
        let crossLen = simd_length(cross)
        if crossLen > 0.001 {
            let angle = atan2(crossLen, dot)
            bone.orientation = simd_quaternion(angle, simd_normalize(cross))
        }

        var boneMat = PhysicallyBasedMaterial()
        boneMat.baseColor = .init(tint: activeTint.withAlphaComponent(0.85))
        boneMat.roughness = .init(floatLiteral: 0.8)
        boneMat.metallic  = .init(floatLiteral: 0.0)
        bone.model?.materials = [boneMat]
    }
}
