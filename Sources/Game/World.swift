import simd

/// A solid axis-aligned block the player can stand on and bump into.
struct Platform {
    var center: SIMD3<Float>
    var halfExtents: SIMD3<Float>
    var color: SIMD4<Float>

    var top: Float { center.y + halfExtents.y }
    var bottom: Float { center.y - halfExtents.y }
}

/// A spinning pickup.
struct Coin {
    var position: SIMD3<Float>
    var phase: Float
    var collected: Bool = false
}

/// Possession targets. Each kind changes how the player moves once hijacked.
enum EnemyKind {
    /// Heavy and slow, but jumps high.
    case walker
    /// Light and fast, but jumps low.
    case hopper

    var bodyColor: SIMD4<Float> {
        switch self {
        case .walker: return SIMD4<Float>(0.84, 0.29, 0.25, 1)
        case .hopper: return SIMD4<Float>(0.60, 0.38, 0.92, 1)
        }
    }
}

/// A patrolling creature. Movement is a pure sine along `axis` around `home`,
/// so it can never drift out of its patrol lane no matter the frame rate.
struct Enemy {
    var kind: EnemyKind
    var home: SIMD3<Float>
    var axis: SIMD3<Float> = SIMD3<Float>(1, 0, 0)
    var position: SIMD3<Float>
    var phase: Float = 0
    var alive: Bool = true
}

/// The course layout, built procedurally at launch.
struct World {
    var platforms: [Platform] = []
    var coins: [Coin] = []
    var enemies: [Enemy] = []
    var goalPosition = SIMD3<Float>(0, 4, -20)

    static func makeCourse() -> World {
        var world = World()

        let grass = SIMD4<Float>(0.40, 0.62, 0.36, 1)
        let stone = SIMD4<Float>(0.55, 0.56, 0.60, 1)
        let sand = SIMD4<Float>(0.82, 0.72, 0.50, 1)
        let brick = SIMD4<Float>(0.74, 0.45, 0.34, 1)

        world.platforms = [
            Platform(center: SIMD3<Float>(0, 0.5, -6),
                     halfExtents: SIMD3<Float>(2.5, 0.5, 2.5), color: grass),

            Platform(center: SIMD3<Float>(-5.5, 1.0, -11),
                     halfExtents: SIMD3<Float>(1.6, 1.0, 1.6), color: stone),

            Platform(center: SIMD3<Float>(0, 1.6, -13.5),
                     halfExtents: SIMD3<Float>(1.8, 1.6, 1.8), color: brick),

            Platform(center: SIMD3<Float>(5.5, 1.0, -11),
                     halfExtents: SIMD3<Float>(1.6, 1.0, 1.6), color: stone),

            Platform(center: SIMD3<Float>(-3.0, 2.2, -17),
                     halfExtents: SIMD3<Float>(1.2, 0.35, 1.2), color: sand),

            Platform(center: SIMD3<Float>(3.0, 2.6, -17),
                     halfExtents: SIMD3<Float>(1.2, 0.35, 1.2), color: sand),

            Platform(center: SIMD3<Float>(0, 3.0, -21),
                     halfExtents: SIMD3<Float>(3.0, 0.6, 3.0), color: grass)
        ]

        // Coins on the ground and floating just above each platform.
        world.coins = [
            Coin(position: SIMD3<Float>(0, 0.9, -2.0), phase: 0.0),
            Coin(position: SIMD3<Float>(-2.2, 0.9, -4.5), phase: 0.7),
            Coin(position: SIMD3<Float>(2.2, 0.9, -4.5), phase: 1.4),
            Coin(position: SIMD3<Float>(0, 1.9, -6.0), phase: 2.1),
            Coin(position: SIMD3<Float>(-5.5, 2.9, -11.0), phase: 0.4),
            Coin(position: SIMD3<Float>(5.5, 2.9, -11.0), phase: 1.1),
            Coin(position: SIMD3<Float>(0, 4.1, -13.5), phase: 1.8),
            Coin(position: SIMD3<Float>(-3.0, 3.5, -17.0), phase: 2.5),
            Coin(position: SIMD3<Float>(3.0, 3.9, -17.0), phase: 3.2),
            Coin(position: SIMD3<Float>(0, 4.6, -19.0), phase: 3.9)
        ]

        world.enemies = [
            Enemy(kind: .walker,
                  home: SIMD3<Float>(-5.5, 2.5, -11),
                  axis: SIMD3<Float>(1, 0, 0),
                  position: SIMD3<Float>(-5.5, 2.5, -11)),
            Enemy(kind: .hopper,
                  home: SIMD3<Float>(5.5, 2.4, -11),
                  axis: SIMD3<Float>(0, 0, 1),
                  position: SIMD3<Float>(5.5, 2.4, -11)),
            Enemy(kind: .hopper,
                  home: SIMD3<Float>(0, 4.4, -21),
                  axis: SIMD3<Float>(1, 0, 0),
                  position: SIMD3<Float>(0, 4.4, -21))
        ]

        world.goalPosition = SIMD3<Float>(0, 3.6, -21)
        return world
    }
}
