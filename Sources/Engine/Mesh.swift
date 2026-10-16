import Metal
import simd

/// An indexed mesh living in GPU memory. Everything in this project is procedural,
/// so there are no asset files to load.
final class GPUMesh {
    let vertexBuffer: MTLBuffer
    let indexBuffer: MTLBuffer
    let indexCount: Int

    init?(device: MTLDevice, vertices: [Vertex], indices: [UInt16]) {
        guard !vertices.isEmpty, !indices.isEmpty else { return nil }

        let vertexLength = MemoryLayout<Vertex>.stride * vertices.count
        let indexLength = MemoryLayout<UInt16>.stride * indices.count

        guard let vertexBuffer = device.makeBuffer(bytes: vertices,
                                                   length: vertexLength,
                                                   options: .storageModeShared),
              let indexBuffer = device.makeBuffer(bytes: indices,
                                                  length: indexLength,
                                                  options: .storageModeShared)
        else { return nil }

        self.vertexBuffer = vertexBuffer
        self.indexBuffer = indexBuffer
        self.indexCount = indices.count
    }
}

/// Procedural geometry generators. All meshes are unit-sized and get scaled by
/// the model matrix at draw time.
enum MeshFactory {

    static func box(size: SIMD3<Float>) -> (vertices: [Vertex], indices: [UInt16]) {
        let h = size * 0.5
        var vertices: [Vertex] = []
        var indices: [UInt16] = []

        func addFace(_ a: SIMD3<Float>,
                     _ b: SIMD3<Float>,
                     _ c: SIMD3<Float>,
                     _ d: SIMD3<Float>,
                     normal: SIMD3<Float>) {
            let base = UInt16(vertices.count)
            vertices.append(Vertex(position: a, normal: normal))
            vertices.append(Vertex(position: b, normal: normal))
            vertices.append(Vertex(position: c, normal: normal))
            vertices.append(Vertex(position: d, normal: normal))
            indices.append(contentsOf: [base, base + 1, base + 2,
                                        base, base + 2, base + 3])
        }

        addFace(SIMD3<Float>( h.x, -h.y,  h.z),
                SIMD3<Float>( h.x, -h.y, -h.z),
                SIMD3<Float>( h.x,  h.y, -h.z),
                SIMD3<Float>( h.x,  h.y,  h.z), normal: SIMD3<Float>(1, 0, 0))

        addFace(SIMD3<Float>(-h.x, -h.y, -h.z),
                SIMD3<Float>(-h.x, -h.y,  h.z),
                SIMD3<Float>(-h.x,  h.y,  h.z),
                SIMD3<Float>(-h.x,  h.y, -h.z), normal: SIMD3<Float>(-1, 0, 0))

        addFace(SIMD3<Float>(-h.x, h.y,  h.z),
                SIMD3<Float>( h.x, h.y,  h.z),
                SIMD3<Float>( h.x, h.y, -h.z),
                SIMD3<Float>(-h.x, h.y, -h.z), normal: SIMD3<Float>(0, 1, 0))

        addFace(SIMD3<Float>(-h.x, -h.y, -h.z),
                SIMD3<Float>( h.x, -h.y, -h.z),
                SIMD3<Float>( h.x, -h.y,  h.z),
                SIMD3<Float>(-h.x, -h.y,  h.z), normal: SIMD3<Float>(0, -1, 0))

        addFace(SIMD3<Float>(-h.x, -h.y, h.z),
                SIMD3<Float>( h.x, -h.y, h.z),
                SIMD3<Float>( h.x,  h.y, h.z),
                SIMD3<Float>(-h.x,  h.y, h.z), normal: SIMD3<Float>(0, 0, 1))

        addFace(SIMD3<Float>( h.x, -h.y, -h.z),
                SIMD3<Float>(-h.x, -h.y, -h.z),
                SIMD3<Float>(-h.x,  h.y, -h.z),
                SIMD3<Float>( h.x,  h.y, -h.z), normal: SIMD3<Float>(0, 0, -1))

        return (vertices, indices)
    }

    static func plane(size: Float) -> (vertices: [Vertex], indices: [UInt16]) {
        let h = size * 0.5
        let normal = SIMD3<Float>(0, 1, 0)
        let vertices = [
            Vertex(position: SIMD3<Float>(-h, 0,  h), normal: normal),
            Vertex(position: SIMD3<Float>( h, 0,  h), normal: normal),
            Vertex(position: SIMD3<Float>( h, 0, -h), normal: normal),
            Vertex(position: SIMD3<Float>(-h, 0, -h), normal: normal)
        ]
        let indices: [UInt16] = [0, 1, 2, 0, 2, 3]
        return (vertices, indices)
    }

    static func sphere(radius: Float,
                       rings: Int = 14,
                       sectors: Int = 24) -> (vertices: [Vertex], indices: [UInt16]) {
        var vertices: [Vertex] = []
        var indices: [UInt16] = []

        for ring in 0...rings {
            let v = Float(ring) / Float(rings)
            let phi = v * Float.pi
            for sector in 0...sectors {
                let u = Float(sector) / Float(sectors)
                let theta = u * 2 * Float.pi
                let normal = SIMD3<Float>(sin(phi) * cos(theta),
                                          cos(phi),
                                          sin(phi) * sin(theta))
                vertices.append(Vertex(position: normal * radius, normal: normal))
            }
        }

        let rowStride = sectors + 1
        for ring in 0..<rings {
            for sector in 0..<sectors {
                let a = UInt16(ring * rowStride + sector)
                let b = UInt16((ring + 1) * rowStride + sector)
                let c = UInt16((ring + 1) * rowStride + sector + 1)
                let d = UInt16(ring * rowStride + sector + 1)
                indices.append(contentsOf: [a, b, c, a, c, d])
            }
        }

        return (vertices, indices)
    }
}

/// Shared mesh instances used by every draw call in the game.
final class MeshLibrary {
    let unitBox: GPUMesh
    let unitSphere: GPUMesh
    let unitPlane: GPUMesh

    init?(device: MTLDevice) {
        let box = MeshFactory.box(size: SIMD3<Float>(1, 1, 1))
        let sphere = MeshFactory.sphere(radius: 1)
        let plane = MeshFactory.plane(size: 1)

        guard let unitBox = GPUMesh(device: device, vertices: box.vertices, indices: box.indices),
              let unitSphere = GPUMesh(device: device, vertices: sphere.vertices, indices: sphere.indices),
              let unitPlane = GPUMesh(device: device, vertices: plane.vertices, indices: plane.indices)
        else { return nil }

        self.unitBox = unitBox
        self.unitSphere = unitSphere
        self.unitPlane = unitPlane
    }
}
