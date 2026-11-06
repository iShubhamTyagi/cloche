import Foundation
import Metal
import MetalPerformanceShaders
import RealityKit
import simd

/// The finishing pass's settings. Every number can be changed here.
struct ViewerLook: Sendable {
    /// 0 is the rendered picture; 1 is the full filmic curve.
    var filmic: Float = 0.3
    var exposure: Float = 0.97
    var bloom: Float = 0.42
    /// Brightness (0...1) above which highlights start to bloom.
    var bloomThreshold: Float = 0.8
    var vignette: Float = 0.3
    var grain: Float = 0.012
    var depthOfField: Float = 1
    /// Blur begins this far behind the focus, and is full at `blurFull`, as shares of the plate's radius.
    var blurStart: Float = 0.7
    var blurFull: Float = 2.6
}

/// Depth of field, bloom, a filmic curve, vignette and grain, in one pass after the render. The
/// shader is compiled when the viewer opens, so the project needs no Metal build step. If anything
/// here is unavailable the picture simply passes through unchanged.
final class ViewerPost: @unchecked Sendable {
    private struct Parameters {
        var focus: Float, blurStart: Float, blurEnd: Float, p22: Float, p32: Float
        var dof: Float, bloom: Float, threshold: Float, vignette: Float, grain: Float
        var filmic: Float, exposure: Float, time: Float
    }

    private let lock = NSLock()
    private var look = ViewerLook()
    private var isOff = false
    private var focus: Float = 0.5
    private var plate: Float = 0.12
    private var pipelines: [MTLPixelFormat: MTLRenderPipelineState] = [:]
    private var library: MTLLibrary?
    private var scaler: MPSImageBilinearScale?
    private var nearBlur: MPSImageGaussianBlur?
    private var farBlur: MPSImageGaussianBlur?
    private var textures: (half: MTLTexture, near: MTLTexture, far: MTLTexture)?
    private var failed = false

    /// `off`: Reduce Motion or Low Power Mode.
    func configure(off: Bool, focusDistance: Float, plateRadius: Float, depthOfField: Float) {
        lock.lock()
        isOff = off
        look.depthOfField = depthOfField
        focus = focusDistance
        plate = plateRadius
        lock.unlock()
    }

    func render(_ context: ARView.PostProcessContext) {
        lock.lock()
        let look = look, off = isOff, focus = focus, plate = plate
        lock.unlock()
        guard !off, !failed, let pipeline = pipeline(context), prepare(context),
              let textures, let scaler, let nearBlur, let farBlur else {
            passThrough(context)
            return
        }
        scaler.encode(commandBuffer: context.commandBuffer, sourceTexture: context.sourceColorTexture, destinationTexture: textures.half)
        nearBlur.encode(commandBuffer: context.commandBuffer, sourceTexture: textures.half, destinationTexture: textures.near)
        farBlur.encode(commandBuffer: context.commandBuffer, sourceTexture: textures.half, destinationTexture: textures.far)

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = context.targetColorTexture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let encoder = context.commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        var parameters = Parameters(
            focus: focus, blurStart: plate * look.blurStart, blurEnd: plate * look.blurFull,
            p22: context.projection.columns.2.z, p32: context.projection.columns.3.z,
            dof: look.depthOfField, bloom: look.bloom, threshold: look.bloomThreshold, vignette: look.vignette,
            grain: look.grain, filmic: look.filmic, exposure: look.exposure, time: Float(context.time.truncatingRemainder(dividingBy: 100)))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(context.sourceColorTexture, index: 0)
        encoder.setFragmentTexture(context.sourceDepthTexture, index: 1)
        encoder.setFragmentTexture(textures.near, index: 2)
        encoder.setFragmentTexture(textures.far, index: 3)
        encoder.setFragmentBytes(&parameters, length: MemoryLayout<Parameters>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }

    private func passThrough(_ context: ARView.PostProcessContext) {
        guard let blit = context.commandBuffer.makeBlitCommandEncoder() else { return }
        blit.copy(from: context.sourceColorTexture, to: context.targetColorTexture)
        blit.endEncoding()
    }

    private func pipeline(_ context: ARView.PostProcessContext) -> MTLRenderPipelineState? {
        let format = context.targetColorTexture.pixelFormat
        if let made = pipelines[format] { return made }
        do {
            let library = try self.library ?? context.device.makeLibrary(source: Self.source, options: nil)
            self.library = library
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "lookVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "lookFragment")
            descriptor.colorAttachments[0].pixelFormat = format
            let made = try context.device.makeRenderPipelineState(descriptor: descriptor)
            pipelines[format] = made
            return made
        } catch {
            failed = true
            return nil
        }
    }

    /// The half-size work textures, made again when the view changes size.
    private func prepare(_ context: ARView.PostProcessContext) -> Bool {
        guard MPSSupportsMTLDevice(context.device) else { return false }
        let width = max(context.sourceColorTexture.width / 2, 1), height = max(context.sourceColorTexture.height / 2, 1)
        if let textures, textures.half.width == width, textures.half.height == height { return true }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .private
        guard let half = context.device.makeTexture(descriptor: descriptor),
              let near = context.device.makeTexture(descriptor: descriptor),
              let far = context.device.makeTexture(descriptor: descriptor) else { return false }
        textures = (half, near, far)
        scaler = MPSImageBilinearScale(device: context.device)
        nearBlur = MPSImageGaussianBlur(device: context.device, sigma: 7)
        farBlur = MPSImageGaussianBlur(device: context.device, sigma: 26)
        return true
    }

    private static let source = """
    #include <metal_stdlib>
    using namespace metal;
    struct Parameters { float focus, blurStart, blurEnd, p22, p32, dof, bloom, threshold, vignette, grain, filmic, exposure, time; };
    struct Varying { float4 position [[position]]; float2 uv; };
    vertex Varying lookVertex(uint id [[vertex_id]]) {
        float2 u = float2((id << 1) & 2, id & 2);
        Varying o;
        o.position = float4(u * 2 - 1, 0, 1);
        o.uv = float2(u.x, 1 - u.y);
        return o;
    }
    float hash(float2 p) { return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453); }
    fragment float4 lookFragment(Varying in [[stage_in]], texture2d<float> scene [[texture(0)]], depth2d<float> depth [[texture(1)]],
                                 texture2d<float> nearBlur [[texture(2)]], texture2d<float> farBlur [[texture(3)]],
                                 constant Parameters& p [[buffer(0)]]) {
        constexpr sampler s(filter::linear, address::clamp_to_edge);
        float4 source = scene.sample(s, in.uv);
        // Nothing rendered here: the view's background shows through, so leave it transparent.
        if (source.a < 0.01) { return source; }
        float3 c = source.rgb;
        // Distance from the camera, from the depth buffer.
        float d = depth.sample(s, in.uv);
        float distance = abs(p.p32 / (d + p.p22));
        float coc = smoothstep(p.blurStart, p.blurEnd, distance - p.focus) * p.dof;
        c = mix(c, nearBlur.sample(s, in.uv).rgb, coc);
        // Highlights spill softly.
        float3 glow = farBlur.sample(s, in.uv).rgb;
        c += max(glow - p.threshold, 0.0) * p.bloom * 2.0;
        // A filmic curve: a toe that holds the shadows, a shoulder that rolls off the highlights.
        c *= p.exposure;
        float3 film = c * (2.51 * c + 0.03) / (c * (2.43 * c + 0.59) + 0.14);
        c = mix(c, film, p.filmic);
        float2 q = in.uv - 0.5;
        c *= 1.0 - p.vignette * smoothstep(0.25, 0.8, length(q));
        float light = dot(c, float3(0.3, 0.6, 0.1));
        c += (hash(in.position.xy + fract(p.time) * 61.0) - 0.5) * p.grain * smoothstep(0.05, 0.4, light);
        return float4(c, source.a);
    }
    """
}
