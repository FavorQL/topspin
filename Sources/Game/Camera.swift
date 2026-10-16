import simd

/// Third-person orbit camera that trails the player with critically-damped smoothing.
struct FollowCamera {
    /// Orbit angle in radians. The camera sits at this angle around the target.
    var yaw: Float = 0
    /// Negative pitch raises the camera above the target.
    var pitch: Float = -0.34
    var distance: Float = 6.4

    private(set) var eyePosition = SIMD3<Float>(0, 3.6, 9)
    private(set) var lookTarget = SIMD3<Float>(0, 1.2, 0)

    private var smoothedTarget = SIMD3<Float>(0, 1.2, 0)

    /// Unit vector pointing where the camera looks, flattened to the ground plane.
    /// Movement input is resolved against this so "up" always means "away from camera".
    var forwardOnGround: SIMD3<Float> {
        SIMD3<Float>(-sin(yaw), 0, -cos(yaw))
    }

    var rightOnGround: SIMD3<Float> {
        SIMD3<Float>(cos(yaw), 0, -sin(yaw))
    }

    mutating func update(deltaTime: Float, target: SIMD3<Float>) {
        let focus = target + SIMD3<Float>(0, 1.05, 0)
        smoothedTarget += (focus - smoothedTarget) * min(1, deltaTime * 9)

        pitch = min(max(pitch, -1.15), 0.30)

        let horizontal = cos(pitch) * distance
        let vertical = -sin(pitch) * distance
        let desiredEye = smoothedTarget
            + SIMD3<Float>(sin(yaw) * horizontal, vertical, cos(yaw) * horizontal)

        eyePosition += (desiredEye - eyePosition) * min(1, deltaTime * 10)
        lookTarget = smoothedTarget
    }

    /// Feeds raw pan translation (in points) into the orbit angles.
    mutating func orbit(deltaYaw: Float, deltaPitch: Float) {
        yaw -= deltaYaw
        pitch -= deltaPitch
    }

    mutating func reset() {
        yaw = 0
        pitch = -0.34
        smoothedTarget = lookTarget
        let horizontal = cos(pitch) * distance
        let vertical = -sin(pitch) * distance
        eyePosition = smoothedTarget + SIMD3<Float>(0, vertical, horizontal)
    }
}
