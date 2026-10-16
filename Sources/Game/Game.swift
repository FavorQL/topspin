import Foundation
import simd

enum GameState {
    case playing
    case cleared
}

/// Owns the whole simulation: player, world, camera and the possession mechanic.
/// `Renderer` calls `update` once per frame and then asks for the draw list.
final class Game {

    // MARK: - Public state

    var aspect: Float = 16.0 / 9.0
    var input = InputState.idle

    private(set) var state: GameState = .playing
    private(set) var coinCount = 0
    private(set) var totalCoins = 0
    private(set) var possessedKind: EnemyKind?
    private(set) var hat: HatProjectile?

    var player = Player()
    var camera = FollowCamera()
    var world = World.makeCourse()

    // MARK: - Private state

    private var capturedEnemy: Enemy?
    private var previousJumpHeld = false
    private var previousHatHeld = false

    private let gravity: Float = -24
    private let terminalVelocity: Float = -40
    /// The grass plane is a finite island. Step past its edge and you fall.
    private let groundHalfExtent: Float = 22
    private let worldLimit: Float = 24
    private let fallOutHeight: Float = -6
    private let hatSpeed: Float = 17
    private let hatLifetime: Float = 0.7
    private let captureRadius: Float = 0.85
    private let coinRadius: Float = 0.8
    private let goalRadius: Float = 1.4

    init() {
        totalCoins = world.coins.count
    }

    // MARK: - Camera matrices

    var viewProjectionMatrix: simd_float4x4 {
        let projection = Math.perspective(fovyRadians: 55 * .pi / 180,
                                          aspect: aspect,
                                          near: 0.1,
                                          far: 220)
        let view = Math.lookAt(eye: camera.eyePosition,
                               center: camera.lookTarget,
                               up: SIMD3<Float>(0, 1, 0))
        return projection * view
    }

    // MARK: - Simulation

    func update(deltaTime: Float) {
        camera.update(deltaTime: deltaTime, target: player.position)

        updatePlayer(deltaTime: deltaTime)
        updateEnemies(deltaTime: deltaTime)
        updateHat(deltaTime: deltaTime)
        updateCoins(deltaTime: deltaTime)

        if state == .playing,
           simd_distance(player.position, world.goalPosition) < goalRadius {
            state = .cleared
        }
    }

    private func updatePlayer(deltaTime: Float) {
        // Resolve stick input against the camera so "up" is always away from the viewer.
        var direction = camera.forwardOnGround * input.move.y
            + camera.rightOnGround * input.move.x

        let magnitude = min(simd_length(direction), 1)
        if magnitude > 0.001 {
            direction = simd_normalize(direction)
            player.facing = atan2(direction.x, direction.z)
        }

        let speed = player.moveSpeed * magnitude
        player.velocity.x = direction.x * speed
        player.velocity.z = direction.z * speed

        // Jump on the rising edge of the button only.
        let jumpPressed = input.jumpHeld && !previousJumpHeld
        if jumpPressed && player.onGround {
            player.velocity.y = player.jumpSpeed
            player.onGround = false
        }
        previousJumpHeld = input.jumpHeld

        // Releasing early cuts the jump short, which gives usable height control.
        var appliedGravity = gravity
        if player.velocity.y > 0 && !input.jumpHeld {
            appliedGravity *= 2.1
        }
        player.velocity.y = max(player.velocity.y + appliedGravity * deltaTime,
                                terminalVelocity)

        let previousFeet = player.position.y
        player.position += player.velocity * deltaTime

        resolveVerticalCollision(previousFeet: previousFeet)
        resolveHorizontalCollision()

        player.position.x = min(max(player.position.x, -worldLimit), worldLimit)
        player.position.z = min(max(player.position.z, -worldLimit), worldLimit)

        if player.position.y < fallOutHeight {
            respawn()
        }

        // Cap button: throw when free, release the host when possessing.
        let hatPressed = input.hatHeld && !previousHatHeld
        previousHatHeld = input.hatHeld

        if hatPressed {
            if possessedKind != nil {
                releasePossession()
            } else if hat == nil {
                throwHat()
            }
        }
    }

    private func resolveVerticalCollision(previousFeet: Float) {
        // The grass plane only supports you while you are actually over it.
        var support: Float = -Float.greatestFiniteMagnitude
        if abs(player.position.x) <= groundHalfExtent, abs(player.position.z) <= groundHalfExtent {
            support = 0
        }

        for platform in world.platforms {
            // Only surfaces at or below the feet (plus a step tolerance) can hold us up,
            // which is what stops us from snapping onto platforms we are passing beneath.
            guard platform.top <= previousFeet + player.stepHeight else { continue }
            guard abs(player.position.x - platform.center.x) <= platform.halfExtents.x + player.radius,
                  abs(player.position.z - platform.center.z) <= platform.halfExtents.z + player.radius
            else { continue }
            support = max(support, platform.top)
        }

        if player.position.y <= support {
            player.position.y = support
            player.velocity.y = 0
            player.onGround = true
        } else {
            player.onGround = false
        }
    }

    private func resolveHorizontalCollision() {
        let feet = player.position.y
        let head = feet + player.height

        for platform in world.platforms {
            // Walkable ledges are handled by the vertical pass; only true walls block here.
            if feet + player.stepHeight >= platform.top { continue }
            if head <= platform.bottom { continue }

            let dx = player.position.x - platform.center.x
            let dz = player.position.z - platform.center.z
            let overlapX = platform.halfExtents.x + player.radius - abs(dx)
            let overlapZ = platform.halfExtents.z + player.radius - abs(dz)
            guard overlapX > 0, overlapZ > 0 else { continue }

            // Push out along the shallower axis so we slide instead of sticking.
            if overlapX < overlapZ {
                player.position.x += dx < 0 ? -overlapX : overlapX
                player.velocity.x = 0
            } else {
                player.position.z += dz < 0 ? -overlapZ : overlapZ
                player.velocity.z = 0
            }
        }
    }

    private func updateEnemies(deltaTime: Float) {
        for index in world.enemies.indices where world.enemies[index].alive {
            var enemy = world.enemies[index]
            enemy.phase += deltaTime
            let rate: Float = enemy.kind == .walker ? 0.9 : 1.7
            let offset = sin(enemy.phase * rate) * 3.0
            enemy.position = enemy.home + enemy.axis * offset
            world.enemies[index] = enemy
        }
    }

    private func updateCoins(deltaTime: Float) {
        let pickupPoint = player.position + SIMD3<Float>(0, 0.45, 0)
        for index in world.coins.indices where !world.coins[index].collected {
            world.coins[index].phase += deltaTime * 2.2
            if simd_distance(world.coins[index].position, pickupPoint) < coinRadius {
                world.coins[index].collected = true
                coinCount += 1
            }
        }
    }

    private func updateHat(deltaTime: Float) {
        guard var projectile = hat else { return }

        projectile.position += projectile.velocity * deltaTime
        projectile.life -= deltaTime
        projectile.spin += deltaTime * 22

        var hitIndex: Int?
        for index in world.enemies.indices where world.enemies[index].alive {
            if simd_distance(world.enemies[index].position, projectile.position) < captureRadius {
                hitIndex = index
                break
            }
        }

        if let index = hitIndex {
            capture(enemyIndex: index)
            hat = nil
        } else if projectile.life <= 0 {
            hat = nil
        } else {
            hat = projectile
        }
    }

    private func throwHat() {
        let forward = camera.forwardOnGround
        let origin = player.position + SIMD3<Float>(0, 0.9, 0) + forward * 0.45
        hat = HatProjectile(position: origin,
                            velocity: forward * hatSpeed,
                            life: hatLifetime,
                            spin: 0)
    }

    private func capture(enemyIndex: Int) {
        var enemy = world.enemies[enemyIndex]
        enemy.alive = false
        world.enemies.remove(at: enemyIndex)

        capturedEnemy = enemy
        possessedKind = enemy.kind
        player.capturedKind = enemy.kind
        player.position = SIMD3<Float>(enemy.position.x, player.position.y, enemy.position.z)
        player.velocity = .zero
        player.velocity.y = 0
    }

    private func releasePossession() {
        guard var enemy = capturedEnemy else {
            possessedKind = nil
            player.capturedKind = nil
            return
        }

        enemy.alive = true
        enemy.position = SIMD3<Float>(player.position.x, enemy.home.y, player.position.z)
        enemy.home = enemy.position
        world.enemies.append(enemy)

        capturedEnemy = nil
        possessedKind = nil
        player.capturedKind = nil
        player.velocity.y = max(player.velocity.y, 3.0)
    }

    private func respawn() {
        if possessedKind != nil {
            releasePossession()
        }
        player.position = SIMD3<Float>(0, 1.2, 4)
        player.velocity = .zero
        player.onGround = false
        camera.reset()
    }

    // MARK: - Draw list

    func buildDrawItems(into items: inout [DrawItem], meshes: MeshLibrary) {
        items.append(DrawItem(mesh: meshes.unitPlane,
                              modelMatrix: Math.translation(SIMD3<Float>(0, 0, 0))
                                  * Math.scale(SIMD3<Float>(repeating: groundHalfExtent * 2)),
                              color: SIMD4<Float>(0.38, 0.58, 0.35, 1)))

        for platform in world.platforms {
            items.append(DrawItem(mesh: meshes.unitBox,
                                  modelMatrix: Math.translation(platform.center)
                                      * Math.scale(platform.halfExtents * 2),
                                  color: platform.color))
        }

        for coin in world.coins where !coin.collected {
            let bob = sin(coin.phase) * 0.16
            let position = SIMD3<Float>(coin.position.x, coin.position.y + bob, coin.position.z)
            items.append(DrawItem(mesh: meshes.unitSphere,
                                  modelMatrix: Math.translation(position)
                                      * Math.rotationY(coin.phase * 1.9)
                                      * Math.scale(SIMD3<Float>(repeating: 0.26)),
                                  color: SIMD4<Float>(1.0, 0.80, 0.18, 1)))
        }

        for enemy in world.enemies where enemy.alive {
            let bob = enemy.kind == .hopper ? abs(sin(enemy.phase * 3.0)) * 0.45 : 0
            let position = SIMD3<Float>(enemy.position.x,
                                        enemy.position.y + bob,
                                        enemy.position.z)
            switch enemy.kind {
            case .walker:
                items.append(DrawItem(mesh: meshes.unitBox,
                                      modelMatrix: Math.translation(position)
                                          * Math.scale(SIMD3<Float>(repeating: 0.9)),
                                      color: enemy.kind.bodyColor))
            case .hopper:
                items.append(DrawItem(mesh: meshes.unitSphere,
                                      modelMatrix: Math.translation(position)
                                          * Math.scale(SIMD3<Float>(repeating: 0.5)),
                                      color: enemy.kind.bodyColor))
            }
        }

        // Goal marker: a pillar with a glowing orb on top.
        items.append(DrawItem(mesh: meshes.unitBox,
                              modelMatrix: Math.translation(world.goalPosition + SIMD3<Float>(0, 1.6, 0))
                                  * Math.scale(SIMD3<Float>(0.36, 3.2, 0.36)),
                              color: SIMD4<Float>(0.95, 0.95, 0.98, 1)))
        items.append(DrawItem(mesh: meshes.unitSphere,
                              modelMatrix: Math.translation(world.goalPosition + SIMD3<Float>(0, 3.5, 0))
                                  * Math.scale(SIMD3<Float>(repeating: 0.42)),
                              color: state == .cleared
                                  ? SIMD4<Float>(0.45, 1.0, 0.55, 1)
                                  : SIMD4<Float>(1.0, 0.85, 0.25, 1)))

        if let hat = hat {
            items.append(DrawItem(mesh: meshes.unitSphere,
                                  modelMatrix: Math.translation(hat.position)
                                      * Math.scale(SIMD3<Float>(0.22, 0.09, 0.22)),
                                  color: SIMD4<Float>(0.98, 0.36, 0.34, 1)))
        }

        appendPlayer(items: &items, meshes: meshes)
    }

    private func appendPlayer(items: inout [DrawItem], meshes: MeshLibrary) {
        let origin = Math.translation(player.position) * Math.rotationY(player.facing)

        switch possessedKind {
        case .walker:
            items.append(DrawItem(mesh: meshes.unitBox,
                                  modelMatrix: origin
                                      * Math.translation(SIMD3<Float>(0, 0.45, 0))
                                      * Math.scale(SIMD3<Float>(repeating: 0.9)),
                                  color: EnemyKind.walker.bodyColor))

        case .hopper:
            items.append(DrawItem(mesh: meshes.unitSphere,
                                  modelMatrix: origin
                                      * Math.translation(SIMD3<Float>(0, 0.5, 0))
                                      * Math.scale(SIMD3<Float>(repeating: 0.5)),
                                  color: EnemyKind.hopper.bodyColor))

        case nil:
            // Torso
            items.append(DrawItem(mesh: meshes.unitBox,
                                  modelMatrix: origin
                                      * Math.translation(SIMD3<Float>(0, 0.32, 0))
                                      * Math.scale(SIMD3<Float>(0.52, 0.64, 0.46)),
                                  color: SIMD4<Float>(0.88, 0.91, 0.97, 1)))
            // Head
            items.append(DrawItem(mesh: meshes.unitSphere,
                                  modelMatrix: origin
                                      * Math.translation(SIMD3<Float>(0, 0.82, 0))
                                      * Math.scale(SIMD3<Float>(repeating: 0.34)),
                                  color: SIMD4<Float>(0.97, 0.93, 0.88, 1)))
            // Cap
            items.append(DrawItem(mesh: meshes.unitSphere,
                                  modelMatrix: origin
                                      * Math.translation(SIMD3<Float>(0, 0.95, 0))
                                      * Math.scale(SIMD3<Float>(0.38, 0.20, 0.38)),
                                  color: SIMD4<Float>(0.98, 0.36, 0.34, 1)))
        }
    }
}
