import SwiftUI
import MetalKit
import UIKit
import QuartzCore
import simd

struct LiquidChromeParameters {
    let color: SIMD3<Float>
    let speed: Float
    let amplitude: Float
    let frequencyX: Float
    let frequencyY: Float
    let detail: Float
    let thickness: Float
    let interactive: Bool
    let depth: Float
    let roughness: Float
    let exposure: Float
    let rippleStrength: Float
    let rippleSize: Float
    let tilt: Float
    let intro: Bool
    let lightMode: Bool
    let maxDevicePixelRatio: Float
    let pixelBudget: Float
    let simulationCell: Float
    let simulationStep: Float

    static let frozenApps = LiquidChromeParameters(
        color: SIMD3<Float>(1, 1, 1),
        speed: 0.2,
        amplitude: 0.8,
        frequencyX: 3,
        frequencyY: 1,
        detail: 2,
        thickness: 0.3,
        interactive: true,
        depth: 0.8,
        roughness: 0,
        exposure: 2,
        rippleStrength: 1.4,
        rippleSize: 1.3,
        tilt: 0.65,
        intro: true,
        lightMode: false,
        maxDevicePixelRatio: 2,
        pixelBudget: 2_400_000,
        simulationCell: 4,
        simulationStep: 1.0 / 120.0
    )
}

private struct LiquidChromeStroke {
    var start: SIMD2<Float>
    var end: SIMD2<Float>
    var strength: Float
    var radius: Float
}

private struct LiquidChromeInputFrame {
    var pointer: SIMD2<Float>
    var pointerInside: Bool
}

/// SIMD4 fields keep every MSL uniform member naturally aligned to 16 bytes.
private struct LiquidChromeSimUniforms {
    var size: SIMD4<Float>
    var stroke: SIMD4<Float>
    var impulse: SIMD4<Float>
}

private struct LiquidChromeSlopeUniforms {
    var size: SIMD4<Float>
}

private struct LiquidChromeUniforms {
    var resolutionUnitTime: SIMD4<Float>
    var amplitudeFrequencyDepth: SIMD4<Float>
    var detailSharpnessPresenceRoughness: SIMD4<Float>
    var exposureRippleLight: SIMD4<Float>
    var tint: SIMD4<Float>
    var shiftAndSlopeSize: SIMD4<Float>
}

final class LiquidChromeInteraction {
    private let lock = NSLock()
    private var previousPoint: SIMD2<Float>?
    private var pointer = SIMD2<Float>(repeating: 0)
    private var pointerInside = false
    private var wasTouching = false
    private var reduceMotionEnabled = false
    private var strokes: [LiquidChromeStroke] = []

    /// Reduce Motion is enforced at the input boundary so touches cannot queue
    /// wave impulses that replay later when the accessibility setting changes.
    func setReduceMotion(_ enabled: Bool) {
        lock.lock()
        defer { lock.unlock() }
        reduceMotionEnabled = enabled
        previousPoint = nil
        pointer = SIMD2<Float>(repeating: 0)
        pointerInside = false
        wasTouching = false
        if enabled {
            strokes.removeAll(keepingCapacity: true)
        }
    }

    func updatePointer(_ location: CGPoint, in size: CGSize, touching: Bool) {
        guard size.width > 0, size.height > 0 else { return }
        let normalizedPoint = SIMD2<Float>(
            Float(min(max(location.x / size.width, 0), 1)),
            Float(min(max(location.y / size.height, 0), 1))
        )
        // Wave strokes use GLSL grid coordinates (origin at bottom-left).
        // The idle sway pointer keeps DOM screen coordinates (origin at top-left).
        let gridPoint = SIMD2<Float>(normalizedPoint.x, 1.0 - normalizedPoint.y)
        let pointerPoint = normalizedPoint * 2.0 - SIMD2<Float>(repeating: 1.0)

        lock.lock()
        defer { lock.unlock() }

        guard !reduceMotionEnabled else {
            previousPoint = nil
            pointer = SIMD2<Float>(repeating: 0)
            pointerInside = false
            wasTouching = false
            return
        }

        if touching && !wasTouching {
            appendStroke(LiquidChromeStroke(
                start: gridPoint, end: gridPoint,
                strength: -1.6 * LiquidChromeParameters.frozenApps.rippleSize,
                radius: 6.0 * LiquidChromeParameters.frozenApps.rippleSize
            ))
        } else if let previousPoint, pointerInside {
            let gridWidth = min(512.0, max(16.0, (Float(size.width) / 4.0).rounded()))
            let gridHeight = min(512.0, max(16.0, (Float(size.height) / 4.0).rounded()))
            let dx = (gridPoint.x - previousPoint.x) * gridWidth
            let dy = (gridPoint.y - previousPoint.y) * gridHeight
            let travel = hypot(dx, dy)
            if travel > 0.25 {
                appendStroke(LiquidChromeStroke(
                    start: previousPoint, end: gridPoint,
                    strength: -min(0.45, 0.04 + travel * 0.045)
                        * LiquidChromeParameters.frozenApps.rippleSize,
                    radius: 4.0 * LiquidChromeParameters.frozenApps.rippleSize
                ))
            }
        }
        self.previousPoint = gridPoint
        pointer = pointerPoint
        pointerInside = true
        wasTouching = touching
    }

    func endPointer() {
        lock.lock()
        previousPoint = nil
        pointerInside = false
        wasTouching = false
        lock.unlock()
    }

    fileprivate func currentFrame() -> LiquidChromeInputFrame {
        lock.lock()
        defer { lock.unlock() }
        return LiquidChromeInputFrame(pointer: pointer, pointerInside: pointerInside)
    }

    fileprivate func takeStroke() -> LiquidChromeStroke? {
        lock.lock()
        defer { lock.unlock() }
        guard !strokes.isEmpty else { return nil }
        return strokes.removeFirst()
    }

    private func appendStroke(_ stroke: LiquidChromeStroke) {
        strokes.append(stroke)
        if strokes.count > 6 {
            strokes.removeFirst(strokes.count - 6)
        }
    }
}

struct LiquidChromeBackground: UIViewRepresentable {
    let interaction: LiquidChromeInteraction

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func makeCoordinator() -> Coordinator {
        Coordinator(interaction: interaction)
    }

    func makeUIView(context: Context) -> MTKView {
        let view = LiquidChromeMetalView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.isOpaque = true
        view.backgroundColor = .black
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.colorPixelFormat = .bgra8Unorm
        view.framebufferOnly = true
        view.autoResizeDrawable = false
        view.enableSetNeedsDisplay = true
        view.isPaused = true
        view.isUserInteractionEnabled = false
        view.accessibilityElementsHidden = true
        context.coordinator.attach(view)
        view.onWindowChange = { [weak coordinator = context.coordinator] in
            coordinator?.refreshPlaybackPolicy()
        }
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.update(
            sceneActive: scenePhase == .active,
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            increasedContrast: colorSchemeContrast == .increased
        )
        context.coordinator.refreshPlaybackPolicy()
    }

    static func dismantleUIView(_ view: MTKView, coordinator: Coordinator) {
        coordinator.detach()
    }

    final class Coordinator: NSObject, MTKViewDelegate {
        private let parameters = LiquidChromeParameters.frozenApps
        private let interaction: LiquidChromeInteraction
        private weak var view: MTKView?
        private var device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        private var simulationPipeline: MTLRenderPipelineState?
        private var slopePipeline: MTLRenderPipelineState?
        private var chromePipeline: MTLRenderPipelineState?
        private var stateTextures: [MTLTexture] = []
        private var slopeTexture: MTLTexture?
        private var simulationSize = SIMD2<Int>(repeating: 0)
        private var currentStateIndex = 0
        private var time = 0.0
        private var lastFrameTime: CFTimeInterval = 0
        private var accumulator: Float = 0
        private var presence: Float
        private var yaw: Float = 0
        private var pitch: Float = 0
        private var yawVelocity: Float = 0
        private var pitchVelocity: Float = 0
        private var sceneActive = true
        private var reduceMotion = false
        private var interactionSuppressed = false
        private var reduceTransparency = false
        private var increasedContrast = false
        private var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        private var thermalState = ProcessInfo.processInfo.thermalState
        private var staticFrameDrawn = false
        private var needsSimulationReset = false
        private var renderingAvailable = false
        private var observerTokens: [NSObjectProtocol] = []
        private var previousDrawableSize = CGSize.zero

        init(interaction: LiquidChromeInteraction) {
            self.interaction = interaction
            self.presence = LiquidChromeParameters.frozenApps.intro ? 0 : 1
            super.init()
            interactionSuppressed = reduceMotion || lowPowerMode
            interaction.setReduceMotion(interactionSuppressed)
            needsSimulationReset = interactionSuppressed
            observeSystemChanges()
        }

        deinit {
            observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
        }

        func attach(_ view: MTKView) {
            self.view = view
            guard let device = view.device, let queue = device.makeCommandQueue() else {
                view.backgroundColor = .black
                return
            }
            self.device = device
            commandQueue = queue
            do {
                guard let library = device.makeDefaultLibrary() else {
                    throw LiquidChromeRenderError.defaultLibraryUnavailable
                }
                simulationPipeline = try makePipeline(device: device, library: library,
                    fragment: "liquidChromeSimulation", pixelFormat: .rg16Float, blends: false)
                slopePipeline = try makePipeline(device: device, library: library,
                    fragment: "liquidChromeSlope", pixelFormat: .rg16Float, blends: false)
                chromePipeline = try makePipeline(device: device, library: library,
                    fragment: "liquidChromeComposite", pixelFormat: view.colorPixelFormat, blends: true)
                renderingAvailable = true
            } catch {
                renderingAvailable = false
                view.backgroundColor = .black
                NSLog("LiquidChrome Metal pipeline unavailable; OLED black fallback: %@", String(describing: error))
            }
            view.delegate = self
            view.preferredFramesPerSecond = 60
            view.enableSetNeedsDisplay = true
            view.isPaused = true
        }

        private func makePipeline(
            device: MTLDevice,
            library: MTLLibrary,
            fragment: String,
            pixelFormat: MTLPixelFormat,
            blends: Bool
        ) throws -> MTLRenderPipelineState {
            guard let vertex = library.makeFunction(name: "liquidChromeVertex"),
                  let pixel = library.makeFunction(name: fragment) else {
                throw LiquidChromeRenderError.missingShaderFunction(fragment)
            }
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = pixel
            descriptor.colorAttachments[0].pixelFormat = pixelFormat
            descriptor.colorAttachments[0].isBlendingEnabled = blends
            if blends {
                descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
                descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
                descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }

        func update(sceneActive: Bool, reduceMotion: Bool, reduceTransparency: Bool, increasedContrast: Bool) {
            let currentLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            let suppressInteraction = reduceMotion || currentLowPowerMode
            let accessibilityChanged = self.reduceTransparency != reduceTransparency
                || self.increasedContrast != increasedContrast

            if self.sceneActive != sceneActive || self.reduceMotion != reduceMotion || accessibilityChanged {
                staticFrameDrawn = false
            }
            if interactionSuppressed != suppressInteraction {
                interaction.setReduceMotion(suppressInteraction)
                interactionSuppressed = suppressInteraction
                needsSimulationReset = true
            }
            if self.reduceMotion != reduceMotion || lowPowerMode != currentLowPowerMode {
                needsSimulationReset = true
                staticFrameDrawn = false
            }

            lowPowerMode = currentLowPowerMode
            self.sceneActive = sceneActive
            self.reduceMotion = reduceMotion
            self.reduceTransparency = reduceTransparency
            self.increasedContrast = increasedContrast
        }

        private func observeSystemChanges() {
            let center = NotificationCenter.default
            observerTokens.append(center.addObserver(
                forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                self.interactionSuppressed = self.reduceMotion || self.lowPowerMode
                self.interaction.setReduceMotion(self.interactionSuppressed)
                self.needsSimulationReset = true
                self.staticFrameDrawn = false
                self.refreshPlaybackPolicy()
            })
            observerTokens.append(center.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.thermalState = ProcessInfo.processInfo.thermalState
                self?.staticFrameDrawn = false
                self?.refreshPlaybackPolicy()
            })
            observerTokens.append(center.addObserver(
                forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                self?.staticFrameDrawn = false
                self?.refreshPlaybackPolicy()
            })
        }

        func refreshPlaybackPolicy() {
            guard let view else { return }
            lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
            thermalState = ProcessInfo.processInfo.thermalState
            let visible = view.window != nil && !view.isHidden
                && view.bounds.width > 0 && view.bounds.height > 0
                && view.convert(view.bounds, to: view.window).intersects(view.window?.bounds ?? .zero)
            let covered = isCoveredByOpaqueFullScreenPresentation(in: view)
            let thermallySafe = thermalState != .serious && thermalState != .critical
            let canAnimate = sceneActive && visible && !covered && thermallySafe
                && !lowPowerMode && !reduceMotion && renderingAvailable

            view.preferredFramesPerSecond = lowPowerMode ? 30 : 60
            if canAnimate {
                view.enableSetNeedsDisplay = false
                view.isPaused = false
            } else {
                view.enableSetNeedsDisplay = true
                view.isPaused = true
                if !staticFrameDrawn && visible && renderingAvailable {
                    view.setNeedsDisplay()
                }
            }
        }

        private func isCoveredByOpaqueFullScreenPresentation(in view: UIView) -> Bool {
            guard let window = view.window else { return true }
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for candidate in windowScene.windows where candidate !== window {
                    if !candidate.isHidden && candidate.alpha >= 0.99
                        && candidate.windowLevel > window.windowLevel { return true }
                }
            }
            var controller = window.rootViewController
            while let presented = controller?.presentedViewController {
                let fullScreen = presented.modalPresentationStyle == .fullScreen
                    || presented.modalPresentationStyle == .overFullScreen
                let alpha = presented.viewIfLoaded?.backgroundColor?.cgColor.alpha ?? 1.0
                if fullScreen && alpha >= 0.99 { return true }
                controller = presented
            }
            return false
        }

        func detach() {
            view?.delegate = nil
            view?.isPaused = true
            stateTextures.removeAll()
            slopeTexture = nil
            renderingAvailable = false
        }

        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            previousDrawableSize = .zero
            staticFrameDrawn = false
        }

        func draw(in view: MTKView) {
            guard renderingAvailable, let commandQueue,
                  let simulationPipeline, let slopePipeline, let chromePipeline,
                  view.window != nil, !view.isHidden, view.bounds.width > 0, view.bounds.height > 0,
                  !isCoveredByOpaqueFullScreenPresentation(in: view),
                  sceneActive, thermalState != .serious, thermalState != .critical else { return }
            guard resizeIfNeeded(view),
                  let drawable = view.currentDrawable,
                  let renderPass = view.currentRenderPassDescriptor,
                  let slopeTexture else { return }

            let now = CACurrentMediaTime()
            let dt = Float(min(max(now - lastFrameTime, 0), 0.05))
            lastFrameTime = now
            let frame = interaction.currentFrame()
            if reduceMotion || lowPowerMode {
                presence = 1
                yaw = 0
                pitch = 0
                yawVelocity = 0
                pitchVelocity = 0
                accumulator = 0
            } else {
                time += Double(dt * parameters.speed)
                if parameters.intro { presence = min(1, presence + dt / 1.8) }
                updateIdleSway(frame: frame, dt: dt)
            }

            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            if needsSimulationReset {
                encodeSimulationClear(on: commandBuffer)
                needsSimulationReset = false
            }
            var simulationSteps = 0
            if !reduceMotion && !lowPowerMode && !view.isPaused {
                accumulator += dt
                simulationSteps = min(4, Int(accumulator / parameters.simulationStep))
                accumulator -= Float(simulationSteps) * parameters.simulationStep
            }
            for step in 0..<simulationSteps {
                let stroke = step == 0 ? interaction.takeStroke() : nil
                let source = stateTextures[currentStateIndex]
                let destinationIndex = 1 - currentStateIndex
                encodeSimulation(commandBuffer: commandBuffer, source: source,
                    destination: stateTextures[destinationIndex], stroke: stroke, pipeline: simulationPipeline)
                currentStateIndex = destinationIndex
            }
            if simulationSteps > 0 {
                encodeSlope(commandBuffer: commandBuffer, source: stateTextures[currentStateIndex],
                    destination: slopeTexture, pipeline: slopePipeline)
            }

            renderPass.colorAttachments[0].loadAction = .clear
            renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
            renderPass.colorAttachments[0].storeAction = .store
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else { return }
            encoder.setRenderPipelineState(chromePipeline)
            encoder.setFragmentTexture(slopeTexture, index: 0)
            let width = Float(view.drawableSize.width)
            let height = Float(view.drawableSize.height)
            var uniforms = LiquidChromeUniforms(
                resolutionUnitTime: SIMD4<Float>(width, height, min(width, height), Float(time)),
                amplitudeFrequencyDepth: SIMD4<Float>(parameters.amplitude, parameters.frequencyX,
                    parameters.frequencyY, parameters.depth),
                detailSharpnessPresenceRoughness: SIMD4<Float>(parameters.detail,
                    5.0 / (3.0 * parameters.thickness),
                    1.0 - pow(1.0 - presence, 3.0), parameters.roughness),
                exposureRippleLight: SIMD4<Float>(parameters.exposure,
                    (reduceMotion || lowPowerMode) ? 0 : parameters.rippleStrength * 2.2,
                    parameters.lightMode ? 1 : 0, reduceTransparency ? 1 : 0),
                tint: SIMD4<Float>(parameters.color.x, parameters.color.y, parameters.color.z,
                    increasedContrast ? 1 : 0),
                shiftAndSlopeSize: SIMD4<Float>(yaw, pitch, Float(simulationSize.x), Float(simulationSize.y))
            )
            withUnsafeBytes(of: &uniforms) { bytes in
                encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 0)
            }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
            if reduceMotion || lowPowerMode {
                staticFrameDrawn = true
                view.isPaused = true
            }
        }

        private func updateIdleSway(frame: LiquidChromeInputFrame, dt: Float) {
            let hovering = parameters.interactive && frame.pointerInside
            let targetYaw = (hovering ? frame.pointer.x * 0.35
                : 0.22 * sin(Float(time) * 1.3)) * parameters.tilt
            let targetPitch = (hovering ? -frame.pointer.y * 0.28
                : 0.16 * sin(Float(time) * 0.9 + 1.7)) * parameters.tilt
            let stiffness: Float = 36
            let damping = 2.0 * sqrt(stiffness) * 0.95
            yawVelocity += ((targetYaw - yaw) * stiffness - yawVelocity * damping) * dt
            pitchVelocity += ((targetPitch - pitch) * stiffness - pitchVelocity * damping) * dt
            yaw += yawVelocity * dt
            pitch += pitchVelocity * dt
        }

        private func resizeIfNeeded(_ view: MTKView) -> Bool {
            let points = view.bounds.size
            guard points.width > 0, points.height > 0, let device else { return false }
            let scale = view.window?.screen.scale ?? view.contentScaleFactor
            var ratio = min(
                scale,
                min(
                    CGFloat(parameters.maxDevicePixelRatio),
                    sqrt(CGFloat(parameters.pixelBudget) / (points.width * points.height))
                )
            )
            if lowPowerMode { ratio = min(ratio, 1.0) }
            ratio = max(ratio, 0.5)

            let drawableSize = CGSize(
                width: max(1, (points.width * ratio).rounded()),
                height: max(1, (points.height * ratio).rounded())
            )
            let gridWidth = min(512, max(16, Int((points.width / CGFloat(parameters.simulationCell)).rounded())))
            let gridHeight = min(512, max(16, Int((points.height / CGFloat(parameters.simulationCell)).rounded())))
            if drawableSize != previousDrawableSize {
                previousDrawableSize = drawableSize
                view.drawableSize = drawableSize
                staticFrameDrawn = false
            }
            if gridWidth == simulationSize.x && gridHeight == simulationSize.y && stateTextures.count == 2 {
                return true
            }

            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .rg16Float, width: gridWidth, height: gridHeight, mipmapped: false
            )
            descriptor.usage = [.renderTarget, .shaderRead]
            descriptor.storageMode = .private
            guard let first = device.makeTexture(descriptor: descriptor),
                  let second = device.makeTexture(descriptor: descriptor),
                  let slope = device.makeTexture(descriptor: descriptor) else {
                stateTextures.removeAll()
                slopeTexture = nil
                renderingAvailable = false
                view.backgroundColor = .black
                view.isPaused = true
                return false
            }
            first.label = "LiquidChrome SIM State A (RG16Float)"
            second.label = "LiquidChrome SIM State B (RG16Float)"
            slope.label = "LiquidChrome SLOPE (RG16Float)"
            stateTextures = [first, second]
            slopeTexture = slope
            simulationSize = SIMD2<Int>(gridWidth, gridHeight)
            currentStateIndex = 0
            accumulator = 0
            clearTextures([first, second, slope])
            return true
        }

        /// Clears both wave buffers and the derived slope before a still frame
        /// or when returning from Reduce Motion, preventing old ripples from reappearing.
        private func encodeSimulationClear(on commandBuffer: MTLCommandBuffer) {
            var textures = stateTextures
            if let slopeTexture {
                textures.append(slopeTexture)
            }
            for texture in textures {
                let descriptor = MTLRenderPassDescriptor()
                let color = descriptor.colorAttachments[0]!
                color.texture = texture
                color.loadAction = .clear
                color.storeAction = .store
                color.clearColor = MTLClearColorMake(0, 0, 0, 1)
                guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
                    continue
                }
                encoder.endEncoding()
            }
        }

        private func clearTextures(_ textures: [MTLTexture]) {
            guard let commandBuffer = commandQueue?.makeCommandBuffer() else { return }
            for texture in textures {
                let descriptor = MTLRenderPassDescriptor()
                let color = descriptor.colorAttachments[0]!
                color.texture = texture
                color.loadAction = .clear
                color.storeAction = .store
                color.clearColor = MTLClearColorMake(0, 0, 0, 1)
                if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
                    encoder.endEncoding()
                }
            }
            commandBuffer.commit()
        }

        private func encodeSimulation(
            commandBuffer: MTLCommandBuffer,
            source: MTLTexture,
            destination: MTLTexture,
            stroke: LiquidChromeStroke?,
            pipeline: MTLRenderPipelineState
        ) {
            let descriptor = MTLRenderPassDescriptor()
            let color = descriptor.colorAttachments[0]!
            color.texture = destination
            color.loadAction = .dontCare
            color.storeAction = .store
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentTexture(source, index: 0)
            let strokeUniforms = stroke.map {
                SIMD4<Float>($0.start.x * Float(simulationSize.x), $0.start.y * Float(simulationSize.y),
                    $0.end.x * Float(simulationSize.x), $0.end.y * Float(simulationSize.y))
            } ?? SIMD4<Float>(repeating: 0)
            let impulseUniforms = stroke.map { SIMD4<Float>($0.strength, $0.radius, 0, 0) }
                ?? SIMD4<Float>(0, 1, 0, 0)
            var uniforms = LiquidChromeSimUniforms(
                size: SIMD4<Float>(Float(simulationSize.x), Float(simulationSize.y), 0, 0),
                stroke: strokeUniforms, impulse: impulseUniforms
            )
            withUnsafeBytes(of: &uniforms) { bytes in
                encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 0)
            }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
        }

        private func encodeSlope(
            commandBuffer: MTLCommandBuffer,
            source: MTLTexture,
            destination: MTLTexture,
            pipeline: MTLRenderPipelineState
        ) {
            let descriptor = MTLRenderPassDescriptor()
            let color = descriptor.colorAttachments[0]!
            color.texture = destination
            color.loadAction = .dontCare
            color.storeAction = .store
            guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return }
            encoder.setRenderPipelineState(pipeline)
            encoder.setFragmentTexture(source, index: 0)
            var uniforms = LiquidChromeSlopeUniforms(
                size: SIMD4<Float>(Float(simulationSize.x), Float(simulationSize.y), 0, 0)
            )
            withUnsafeBytes(of: &uniforms) { bytes in
                encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 0)
            }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
        }
    }
}

private final class LiquidChromeMetalView: MTKView {
    var onWindowChange: (() -> Void)?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        onWindowChange?()
    }
}

private enum LiquidChromeRenderError: Error {
    case defaultLibraryUnavailable
    case missingShaderFunction(String)
}
