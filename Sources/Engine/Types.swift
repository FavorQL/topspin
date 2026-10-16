import simd

/// CPU-side vertex layout. Must stay byte-compatible with `struct Vertex` in Shaders.metal.
///
/// `SIMD3<Float>` is 16 bytes / 16-byte aligned in Swift, and `float3` is likewise
/// 16 bytes / 16-byte aligned in MSL, so this struct is 32 bytes on both sides.
struct Vertex {
    var position: SIMD3<Float>
    var normal: SIMD3<Float>
}

/// Per-draw uniforms. Must stay byte-compatible with `struct Uniforms` in Shaders.metal.
///
/// Layout: float4x4 (64) + float4x4 (64) + float4 * 3 (48) = 176 bytes, 16-byte aligned.
struct Uniforms {
    var modelMatrix: simd_float4x4
    var viewProjection: simd_float4x4
    var baseColor: SIMD4<Float>
    var lightDirection: SIMD4<Float>
    var cameraPosition: SIMD4<Float>
}

/// One submitted draw call.
struct DrawItem {
    var mesh: GPUMesh
    var modelMatrix: simd_float4x4
    var color: SIMD4<Float>
}

/// Snapshot of the on-screen controls, refreshed every frame.
struct InputState {
    /// Left stick, x = strafe, y = forward. Both in -1...1.
    var move: SIMD2<Float> = .zero
    var jumpHeld: Bool = false
    var hatHeld: Bool = false

    static let idle = InputState()
}
