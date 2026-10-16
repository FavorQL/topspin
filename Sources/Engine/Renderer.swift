import MetalKit
import simd

/// Owns the Metal pipeline and drives one simulation + render step per frame.
final class Renderer: NSObject, MTKViewDelegate {

    let device: MTLDevice
    let meshes: MeshLibrary
    let game: Game

    /// Supplies the latest control state immediately before each simulation step.
    var inputProvider: (() -> InputState)?
    /// Invoked after every simulated frame so the HUD can refresh.
    var onFrame: ((Game) -> Void)?

    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState

    private var drawItems: [DrawItem] = []
    private var lastTimestamp: CFTimeInterval = CACurrentMediaTime()

    private let lightDirection = simd_normalize(SIMD3<Float>(-0.42, -0.86, -0.30))

    init?(device: MTLDevice, view: MTKView, game: Game) {
        guard let commandQueue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main"),
              let meshes = MeshLibrary(device: device)
        else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "TopspinForward"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.rasterSampleCount = view.sampleCount
        descriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        descriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat

        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }

        let depthDescriptor = MTLDepthStencilDescriptor()
        depthDescriptor.label = "TopspinDepth"
        depthDescriptor.depthCompareFunction = .less
        depthDescriptor.isDepthWriteEnabled = true

        guard let depthState = device.makeDepthStencilState(descriptor: depthDescriptor) else {
            return nil
        }

        self.device = device
        self.commandQueue = commandQueue
        self.meshes = meshes
        self.game = game
        self.pipelineState = pipelineState
        self.depthState = depthState
        super.init()
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        game.aspect = Float(size.width / max(size.height, 1))
    }

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()
        var deltaTime = Float(now - lastTimestamp)
        lastTimestamp = now
        // Clamp so a hitch or a debugger pause never tunnels the player through geometry.
        deltaTime = min(max(deltaTime, 0), 1.0 / 20.0)

        if let inputProvider = inputProvider {
            game.input = inputProvider()
        }
        game.update(deltaTime: deltaTime)
        onFrame?(game)

        drawItems.removeAll(keepingCapacity: true)
        game.buildDrawItems(into: &drawItems, meshes: meshes)

        guard let renderPassDescriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        else { return }

        encoder.label = "TopspinForwardPass"
        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)
        // Everything here is a closed convex primitive, so back-face culling buys
        // little and only risks winding bugs. Depth testing handles hidden surfaces.
        encoder.setCullMode(.none)

        let viewProjection = game.viewProjectionMatrix
        let cameraPosition = game.camera.eyePosition

        for item in drawItems {
            var uniforms = Uniforms(modelMatrix: item.modelMatrix,
                                    viewProjection: viewProjection,
                                    baseColor: item.color,
                                    lightDirection: SIMD4<Float>(lightDirection, 0),
                                    cameraPosition: SIMD4<Float>(cameraPosition, 1))

            encoder.setVertexBuffer(item.mesh.vertexBuffer, offset: 0, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

            encoder.drawIndexedPrimitives(type: .triangle,
                                          indexCount: item.mesh.indexCount,
                                          indexType: .uint16,
                                          indexBuffer: item.mesh.indexBuffer,
                                          indexBufferOffset: 0)
        }

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
