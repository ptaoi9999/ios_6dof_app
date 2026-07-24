import RealityKit
import UIKit
import simd

/// 手の骨格ジョイント名リスト
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

/// 指の節（Segment）および手のひらを埋めるボーン接続（親, 子, 太さ）のリスト
struct HandSegmentDef {
    let fromKey: String
    let toKey: String
    let thickness: Float // 太さ（メートル単位）
}

let kHandSegmentDefs: [HandSegmentDef] = [
    // 手のひら / 手の甲の肉付け
    HandSegmentDef(fromKey: "wrist", toKey: "VNHHPRK_TBT", thickness: 0.022),
    HandSegmentDef(fromKey: "wrist", toKey: "VNHHPRK_ICP", thickness: 0.024),
    HandSegmentDef(fromKey: "wrist", toKey: "VNHHPRK_MCP", thickness: 0.025),
    HandSegmentDef(fromKey: "wrist", toKey: "VNHHPRK_RCP", thickness: 0.023),
    HandSegmentDef(fromKey: "wrist", toKey: "VNHHPRK_PCP", thickness: 0.021),
    
    // 手のひら横方向の接続（掌を一枚の肉付けに見せる）
    HandSegmentDef(fromKey: "VNHHPRK_ICP", toKey: "VNHHPRK_MCP", thickness: 0.022),
    HandSegmentDef(fromKey: "VNHHPRK_MCP", toKey: "VNHHPRK_RCP", thickness: 0.022),
    HandSegmentDef(fromKey: "VNHHPRK_RCP", toKey: "VNHHPRK_PCP", thickness: 0.020),
    HandSegmentDef(fromKey: "VNHHPRK_TBT", toKey: "VNHHPRK_ICP", thickness: 0.020),

    // 親指
    HandSegmentDef(fromKey: "VNHHPRK_TBT", toKey: "VNHHPRK_TMP", thickness: 0.020),
    HandSegmentDef(fromKey: "VNHHPRK_TMP", toKey: "VNHHPRK_TIP", thickness: 0.018),
    HandSegmentDef(fromKey: "VNHHPRK_TIP", toKey: "VNHHPRK_TTX", thickness: 0.016),

    // 人差し指
    HandSegmentDef(fromKey: "VNHHPRK_ICP", toKey: "VNHHPRK_IPP", thickness: 0.019),
    HandSegmentDef(fromKey: "VNHHPRK_IPP", toKey: "VNHHPRK_IIP", thickness: 0.017),
    HandSegmentDef(fromKey: "VNHHPRK_IIP", toKey: "VNHHPRK_ITX", thickness: 0.015),

    // 中指
    HandSegmentDef(fromKey: "VNHHPRK_MCP", toKey: "VNHHPRK_MPP", thickness: 0.020),
    HandSegmentDef(fromKey: "VNHHPRK_MPP", toKey: "VNHHPRK_MIP", thickness: 0.018),
    HandSegmentDef(fromKey: "VNHHPRK_MIP", toKey: "VNHHPRK_MTX", thickness: 0.015),

    // 薬指
    HandSegmentDef(fromKey: "VNHHPRK_RCP", toKey: "VNHHPRK_RPP", thickness: 0.019),
    HandSegmentDef(fromKey: "VNHHPRK_RPP", toKey: "VNHHPRK_RIP", thickness: 0.017),
    HandSegmentDef(fromKey: "VNHHPRK_RIP", toKey: "VNHHPRK_RTX", thickness: 0.014),

    // 小指
    HandSegmentDef(fromKey: "VNHHPRK_PCP", toKey: "VNHHPRK_PPP", thickness: 0.017),
    HandSegmentDef(fromKey: "VNHHPRK_PPP", toKey: "VNHHPRK_PIP", thickness: 0.015),
    HandSegmentDef(fromKey: "VNHHPRK_PIP", toKey: "VNHHPRK_PTX", thickness: 0.013)
]

/// 肌色のリアルなマテリアルを生成する
func createSkinMaterial(tint: UIColor) -> PhysicallyBasedMaterial {
    var mat = PhysicallyBasedMaterial()
    mat.baseColor = .init(tint: tint)
    mat.roughness = .init(floatLiteral: 0.45) // 人間の皮膚に近いしっとりとした光沢
    mat.metallic  = .init(floatLiteral: 0.0)
    return mat
}

/// リアルな手のエンティティ（関節球体＋厚みのある指・手掌セグメント）を生成
func makeHandSkeletonAnchor() -> AnchorEntity {
    let anchor = AnchorEntity(world: .zero)
    anchor.name = "handAnchor"

    let skinMat = createSkinMaterial(tint: UIColor(red: 0.88, green: 0.74, blue: 0.65, alpha: 1.0))

    // 1. 各関節の球体（関節の滑らかな膨らみ）
    for name in kHandJointNames {
        let isTip = name.hasSuffix("TX") || name.hasSuffix("TTX")
        let isWrist = name == "wrist"
        
        // 関節ごとの適切な半径
        let radius: Float = isWrist ? 0.018 : (isTip ? 0.011 : 0.012)

        let mesh = MeshResource.generateSphere(radius: radius)
        let entity = ModelEntity(mesh: mesh, materials: [skinMat])
        entity.name = "joint_\(name)"
        entity.scale = SIMD3<Float>.zero
        anchor.addChild(entity)
    }

    // 2. 指の節・手のひらの肉付けセグメント（標準サイズ 1m x 1m x 1m のBoxで初期化し、scaleで太さと長さを制御）
    let baseMesh = MeshResource.generateBox(width: 1.0, height: 1.0, depth: 1.0)
    for (idx, _) in kHandSegmentDefs.enumerated() {
        let entity = ModelEntity(mesh: baseMesh, materials: [skinMat])
        entity.name = "segment_\(idx)"
        entity.scale = SIMD3<Float>.zero
        anchor.addChild(entity)
    }

    return anchor
}

/// 毎フレーム、手のエンティティの位置・方向・厚みをリアルタイム更新
func updateHandSkeleton(
    handAnchor: Entity,
    joints: [String: simd_float3]?,
    isPinching: Bool,
    isGrabbing: Bool
) {
    // 状態に応じたスキンカラー（通常時: 肌色, ピンチ時: 黄色寄り, 掴み時: 緑色寄り）
    let normalSkin = UIColor(red: 0.88, green: 0.74, blue: 0.65, alpha: 1.0)
    let pinchSkin  = UIColor(red: 0.95, green: 0.85, blue: 0.40, alpha: 1.0)
    let grabSkin   = UIColor(red: 0.50, green: 0.88, blue: 0.55, alpha: 1.0)
    
    let activeTint = isGrabbing ? grabSkin : (isPinching ? pinchSkin : normalSkin)
    let activeMat  = createSkinMaterial(tint: activeTint)

    guard let joints = joints else {
        // 手が未検出の場合はすべて非表示
        for child in handAnchor.children {
            child.scale = SIMD3<Float>.zero
        }
        return
    }

    // 1. 各関節の更新
    for child in handAnchor.children where child.name.hasPrefix("joint_") {
        let key = String(child.name.dropFirst("joint_".count))
        if let pos = joints[key] {
            child.position = pos
            child.scale    = SIMD3<Float>(1, 1, 1)
            if let me = child as? ModelEntity {
                me.model?.materials = [activeMat]
            }
        } else {
            child.scale = SIMD3<Float>.zero
        }
    }

    // 2. 指の節および手のひらの肉付けセグメントの更新
    for (idx, def) in kHandSegmentDefs.enumerated() {
        guard let segEntity = handAnchor.findEntity(named: "segment_\(idx)") as? ModelEntity else { continue }
        
        if let fromPos = joints[def.fromKey], let toPos = joints[def.toKey] {
            let diff = toPos - fromPos
            let len = simd_length(diff)
            
            if len > 0.002 {
                // 位置は2点の中点
                segEntity.position = (fromPos + toPos) * 0.5
                
                // 長さ（Y方向）と、幅・厚み（X, Z方向）を設定
                segEntity.scale = SIMD3<Float>(def.thickness, len, def.thickness)
                
                // Y軸正方向 (0, 1, 0) から diff ベクトル方向への回転計算
                let up = simd_make_float3(0, 1, 0)
                let dir = simd_normalize(diff)
                let dot = simd_dot(up, dir)
                let cross = simd_cross(up, dir)
                let crossLen = simd_length(cross)
                
                if crossLen > 0.001 {
                    let angle = atan2(crossLen, dot)
                    segEntity.orientation = simd_quaternion(angle, simd_normalize(cross))
                } else if dot < 0 {
                    segEntity.orientation = simd_quaternion(Float.pi, simd_make_float3(1, 0, 0))
                } else {
                    segEntity.orientation = simd_quaternion(0, simd_make_float3(0, 1, 0))
                }
                
                segEntity.model?.materials = [activeMat]
            } else {
                segEntity.scale = SIMD3<Float>.zero
            }
        } else {
            segEntity.scale = SIMD3<Float>.zero
        }
    }
}
