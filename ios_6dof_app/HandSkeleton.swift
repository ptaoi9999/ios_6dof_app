import RealityKit
import UIKit
import Vision
import simd

/// 手の骨格ジョイント型リスト
let kHandJointNames: [VNHumanHandPoseObservation.JointName] = [
    .wrist,
    // 親指
    .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
    // 人差し指
    .indexMCP, .indexPIP, .indexDIP, .indexTip,
    // 中指
    .middleMCP, .middlePIP, .middleDIP, .middleTip,
    // 薬指
    .ringMCP, .ringPIP, .ringDIP, .ringTip,
    // 小指
    .littleMCP, .littlePIP, .littleDIP, .littleTip
]

/// 指の節（Segment）および手のひらを埋めるボーン接続の定義
struct HandSegmentDef {
    let fromKey: VNHumanHandPoseObservation.JointName
    let toKey: VNHumanHandPoseObservation.JointName
    let thickness: Float // 太さ（メートル単位）
}

let kHandSegmentDefs: [HandSegmentDef] = [
    // 手のひら / 手の甲の肉付け
    HandSegmentDef(fromKey: .wrist, toKey: .thumbCMC, thickness: 0.022),
    HandSegmentDef(fromKey: .wrist, toKey: .indexMCP, thickness: 0.024),
    HandSegmentDef(fromKey: .wrist, toKey: .middleMCP, thickness: 0.025),
    HandSegmentDef(fromKey: .wrist, toKey: .ringMCP, thickness: 0.023),
    HandSegmentDef(fromKey: .wrist, toKey: .littleMCP, thickness: 0.021),
    
    // 手のひら横方向の接続
    HandSegmentDef(fromKey: .indexMCP, toKey: .middleMCP, thickness: 0.022),
    HandSegmentDef(fromKey: .middleMCP, toKey: .ringMCP, thickness: 0.022),
    HandSegmentDef(fromKey: .ringMCP, toKey: .littleMCP, thickness: 0.020),
    HandSegmentDef(fromKey: .thumbCMC, toKey: .indexMCP, thickness: 0.020),

    // 親指
    HandSegmentDef(fromKey: .thumbCMC, toKey: .thumbMP, thickness: 0.020),
    HandSegmentDef(fromKey: .thumbMP, toKey: .thumbIP, thickness: 0.018),
    HandSegmentDef(fromKey: .thumbIP, toKey: .thumbTip, thickness: 0.016),

    // 人差し指
    HandSegmentDef(fromKey: .indexMCP, toKey: .indexPIP, thickness: 0.019),
    HandSegmentDef(fromKey: .indexPIP, toKey: .indexDIP, thickness: 0.017),
    HandSegmentDef(fromKey: .indexDIP, toKey: .indexTip, thickness: 0.015),

    // 中指
    HandSegmentDef(fromKey: .middleMCP, toKey: .middlePIP, thickness: 0.020),
    HandSegmentDef(fromKey: .middlePIP, toKey: .middleDIP, thickness: 0.018),
    HandSegmentDef(fromKey: .middleDIP, toKey: .middleTip, thickness: 0.015),

    // 薬指
    HandSegmentDef(fromKey: .ringMCP, toKey: .ringPIP, thickness: 0.019),
    HandSegmentDef(fromKey: .ringPIP, toKey: .ringDIP, thickness: 0.017),
    HandSegmentDef(fromKey: .ringDIP, toKey: .ringTip, thickness: 0.014),

    // 小指
    HandSegmentDef(fromKey: .littleMCP, toKey: .littlePIP, thickness: 0.017),
    HandSegmentDef(fromKey: .littlePIP, toKey: .littleDIP, thickness: 0.015),
    HandSegmentDef(fromKey: .littleDIP, toKey: .littleTip, thickness: 0.013)
]

/// 肌色のリアルなマテリアルを生成する
func createSkinMaterial(tint: UIColor) -> PhysicallyBasedMaterial {
    var mat = PhysicallyBasedMaterial()
    mat.baseColor = .init(tint: tint)
    mat.roughness = .init(floatLiteral: 0.45)
    mat.metallic  = .init(floatLiteral: 0.0)
    return mat
}

/// リアルな手のエンティティ（関節球体＋肉付けセグメント）を生成
func makeHandSkeletonAnchor() -> AnchorEntity {
    let anchor = AnchorEntity(world: .zero)
    anchor.name = "handAnchor"

    let skinMat = createSkinMaterial(tint: UIColor(red: 0.88, green: 0.74, blue: 0.65, alpha: 1.0))

    // 1. 各関節の球体 (全21箇所)
    for (idx, joint) in kHandJointNames.enumerated() {
        let isTip = joint == .thumbTip || joint == .indexTip || joint == .middleTip || joint == .ringTip || joint == .littleTip
        let isWrist = joint == .wrist
        let radius: Float = isWrist ? 0.018 : (isTip ? 0.011 : 0.012)

        let mesh = MeshResource.generateSphere(radius: radius)
        let entity = ModelEntity(mesh: mesh, materials: [skinMat])
        entity.name = "joint_\(idx)"
        entity.scale = SIMD3<Float>.zero
        anchor.addChild(entity)
    }

    // 2. 指の節・手のひらの肉付けセグメント
    let baseMesh = MeshResource.generateBox(width: 1.0, height: 1.0, depth: 1.0)
    for (idx, _) in kHandSegmentDefs.enumerated() {
        let entity = ModelEntity(mesh: baseMesh, materials: [skinMat])
        entity.name = "segment_\(idx)"
        entity.scale = SIMD3<Float>.zero
        anchor.addChild(entity)
    }

    return anchor
}

/// 毎フレーム、手のエンティティの位置・方向・厚みを更新
func updateHandSkeleton(
    handAnchor: Entity,
    joints: [VNHumanHandPoseObservation.JointName: simd_float3]?,
    isPinching: Bool,
    isGrabbing: Bool
) {
    let normalSkin = UIColor(red: 0.88, green: 0.74, blue: 0.65, alpha: 1.0)
    let pinchSkin  = UIColor(red: 0.95, green: 0.85, blue: 0.40, alpha: 1.0)
    let grabSkin   = UIColor(red: 0.50, green: 0.88, blue: 0.55, alpha: 1.0)
    
    let activeTint = isGrabbing ? grabSkin : (isPinching ? pinchSkin : normalSkin)
    let activeMat  = createSkinMaterial(tint: activeTint)

    guard let joints = joints else {
        for child in handAnchor.children {
            child.scale = SIMD3<Float>.zero
        }
        return
    }

    // 1. 各関節球体の更新
    for (idx, jointKey) in kHandJointNames.enumerated() {
        guard let entity = handAnchor.findEntity(named: "joint_\(idx)") as? ModelEntity else { continue }
        if let pos = joints[jointKey] {
            entity.position = pos
            entity.scale    = SIMD3<Float>(1, 1, 1)
            entity.model?.materials = [activeMat]
        } else {
            entity.scale = SIMD3<Float>.zero
        }
    }

    // 2. 指の節および手のひらの肉付けセグメントの更新
    for (idx, def) in kHandSegmentDefs.enumerated() {
        guard let segEntity = handAnchor.findEntity(named: "segment_\(idx)") as? ModelEntity else { continue }
        
        if let fromPos = joints[def.fromKey], let toPos = joints[def.toKey] {
            let diff = toPos - fromPos
            let len = simd_length(diff)
            
            if len > 0.002 {
                segEntity.position = (fromPos + toPos) * 0.5
                segEntity.scale = SIMD3<Float>(def.thickness, len, def.thickness)
                
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
