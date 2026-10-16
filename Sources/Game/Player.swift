import simd

/// The player character. `position` is the point between the feet, not the centre,
/// which keeps ground resolution simple.
struct Player {
    var position = SIMD3<Float>(0, 1.2, 4)
    var velocity = SIMD3<Float>.zero
    var facing: Float = Float.pi
    var onGround = false
    var capturedKind: EnemyKind?

    /// Horizontal collision radius.
    let radius: Float = 0.34
    /// Collision height measured up from `position`.
    let height: Float = 1.0
    /// Ledge height the player can simply walk over without a jump.
    let stepHeight: Float = 0.36

    /// Possessing a creature swaps the movement profile, which is the whole point
    /// of the mechanic: the same level plays differently depending on your host.
    var moveSpeed: Float {
        switch capturedKind {
        case .walker: return 4.2
        case .hopper: return 8.8
        case nil:     return 6.2
        }
    }

    var jumpSpeed: Float {
        switch capturedKind {
        case .walker: return 11.8
        case .hopper: return 8.4
        case nil:     return 9.8
        }
    }
}

/// A thrown cap. Travels straight, expires on a timer or on hitting a target.
struct HatProjectile {
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var life: Float
    var spin: Float
}
