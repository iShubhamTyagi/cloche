#if DEBUG
import Decorating
import MetalKit
import os
import QuartzCore
import SwiftUI

/// Decorating plan Phase D1: the viewer technology spike (DEBUG only, `-viewerSpike metal` or
/// `-viewerSpike realitykit`). Both draw the same demo cake (the icing height field over the top
/// grid, re-meshed every frame to stress the update path) and log frame and update times under
/// the `Spike` log category. Results: docs/viewer_decision.md.
struct ViewerSpikeScreen: View {
    let mode: String
    @State private var model = DecorStudioModel(geometry: .cake, aspect: 0.46)

    var body: some View {
        Group {
            if mode == "metal" {
                MetalSpikeView(surfaces: model.surfaces)
            } else {
                CakeViewerView(model: model, dish: .cake, browning: 0)
            }
        }
        .ignoresSafeArea()
        .task {
            model.applyDemo()
            if mode != "metal" { model.toggleTurntable() }
        }
    }
}

enum SpikeLog {
    static let logger = Logger(subsystem: "com.shubhamtyagi.cloche", category: "Spike")
    nonisolated(unsafe) static var frames: [Double] = []
    nonisolated(unsafe) static var updates: [Double] = []

    static func record(frame: Double, update: Double, label: String) {
        frames.append(frame)
        updates.append(update)
        guard frames.count >= 240 else { return }
        let f = frames.sorted(), u = updates.sorted()
        logger.notice("\(label, privacy: .public) frame median \(f[f.count / 2] * 1000, format: .fixed(precision: 2), privacy: .public) ms p95 \(f[f.count * 95 / 100] * 1000, format: .fixed(precision: 2), privacy: .public) ms; remesh median \(u[u.count / 2] * 1000, format: .fixed(precision: 2), privacy: .public) ms")
        frames.removeAll()
        updates.removeAll()
    }
}

/// The minimal Metal renderer: one pipeline, one lit shader, the icing top grid re-meshed and
/// re-uploaded every frame, turning like the turntable.
struct MetalSpikeView: UIViewRepresentable {
    let surfaces: CakeSurfaces

    func makeCoordinator() -> Renderer { Renderer(surfaces: surfaces) }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.colorPixelFormat = .bgra8Unorm
        view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColor(red: 0.06, green: 0.06, blue: 0.06, alpha: 1)
        view.delegate = context.coordinator
        context.coordinator.setup(view)
        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.surfaces = surfaces
    }

    @MainActor
    final class Renderer: NSObject, MTKViewDelegate {
        var surfaces: CakeSurfaces
        private var queue: MTLCommandQueue?
        private var pipeline: MTLRenderPipelineState?
        private var depth: MTLDepthStencilState?
        private var last = CACurrentMediaTime()
        private var angle: Float = 0
        private let profile = DishProfile.placeholder(.cake)

        init(surfaces: CakeSurfaces) { self.surfaces = surfaces }

        static let source = """
        #include <metal_stdlib>
        using namespace metal;
        struct V { float3 p [[attribute(0)]]; float3 n [[attribute(1)]]; float2 uv [[attribute(2)]]; };
        struct O { float4 pos [[position]]; float3 n; };
        vertex O vs(V v [[stage_in]], constant float4x4 &mvp [[buffer(1)]], constant float4x4 &model [[buffer(2)]]) {
            O o; o.pos = mvp * float4(v.p, 1); o.n = (model * float4(v.n, 0)).xyz; return o;
        }
        fragment float4 fs(O o [[stage_in]]) {
            float3 l = normalize(float3(-0.6, 0.8, 0.7));
            float d = max(dot(normalize(o.n), l), 0.0);
            float3 c = float3(0.93, 0.86, 0.72) * (0.25 + 0.75 * d);
            return float4(c, 1);
        }
        """

        func setup(_ view: MTKView) {
            guard let device = view.device, let library = try? device.makeLibrary(source: Self.source, options: nil) else { return }
            queue = device.makeCommandQueue()
            let vd = MTLVertexDescriptor()
            for (i, (format, offset)) in [(MTLVertexFormat.float3, 0), (.float3, 12), (.float2, 24)].enumerated() {
                vd.attributes[i].format = format
                vd.attributes[i].offset = offset
                vd.attributes[i].bufferIndex = 0
            }
            vd.layouts[0].stride = 32
            let desc = MTLRenderPipelineDescriptor()
            desc.vertexFunction = library.makeFunction(name: "vs")
            desc.fragmentFunction = library.makeFunction(name: "fs")
            desc.vertexDescriptor = vd
            desc.colorAttachments[0].pixelFormat = view.colorPixelFormat
            desc.depthAttachmentPixelFormat = view.depthStencilPixelFormat
            pipeline = try? device.makeRenderPipelineState(descriptor: desc)
            let ds = MTLDepthStencilDescriptor()
            ds.depthCompareFunction = .less
            ds.isDepthWriteEnabled = true
            depth = device.makeDepthStencilState(descriptor: ds)
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

        func draw(in view: MTKView) {
            let now = CACurrentMediaTime()
            let dt = now - last
            last = now
            angle += Float(dt) * 0.2 * 2 * .pi
            let t0 = CACurrentMediaTime()
            let mesh = ViewerMesh.icingTop(profile, field: surfaces.top)
            let remesh = CACurrentMediaTime() - t0
            guard let device = view.device, let queue, let pipeline, let pass = view.currentRenderPassDescriptor,
                  let drawable = view.currentDrawable, let cmd = queue.makeCommandBuffer(),
                  let enc = cmd.makeRenderCommandEncoder(descriptor: pass),
                  let vb = device.makeBuffer(bytes: mesh.vertices, length: mesh.vertices.count * 4),
                  let ib = device.makeBuffer(bytes: mesh.indices, length: mesh.indices.count * 4) else { return }
            let aspect = Float(view.drawableSize.width / max(view.drawableSize.height, 1))
            let model = Self.rotationY(angle)
            let mvp = Self.perspective(fovY: 30 * .pi / 180, aspect: aspect, near: 0.01, far: 10) * Self.lookDown(distance: 0.55) * model
            var m = mvp, mm = model
            enc.setRenderPipelineState(pipeline)
            enc.setDepthStencilState(depth)
            enc.setVertexBuffer(vb, offset: 0, index: 0)
            enc.setVertexBytes(&m, length: 64, index: 1)
            enc.setVertexBytes(&mm, length: 64, index: 2)
            enc.drawIndexedPrimitives(type: .triangle, indexCount: mesh.indices.count, indexType: .uint32, indexBuffer: ib, indexBufferOffset: 0)
            enc.endEncoding()
            cmd.present(drawable)
            cmd.commit()
            SpikeLog.record(frame: dt, update: remesh, label: "metal")
        }

        static func rotationY(_ a: Float) -> simd_float4x4 {
            simd_float4x4(SIMD4(cos(a), 0, -sin(a), 0), SIMD4(0, 1, 0, 0), SIMD4(sin(a), 0, cos(a), 0), SIMD4(0, 0, 0, 1))
        }

        static func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
            let y = 1 / tan(fovY / 2), x = y / aspect, z = far / (near - far)
            return simd_float4x4(SIMD4(x, 0, 0, 0), SIMD4(0, y, 0, 0), SIMD4(0, 0, z, -1), SIMD4(0, 0, z * near, 0))
        }

        /// Camera above the cake looking straight down (view up = -Z).
        static func lookDown(distance: Float) -> simd_float4x4 {
            simd_float4x4(SIMD4(1, 0, 0, 0), SIMD4(0, 0, 1, 0), SIMD4(0, -1, 0, 0), SIMD4(0, 0, -distance, 1))
        }
    }
}
#endif
