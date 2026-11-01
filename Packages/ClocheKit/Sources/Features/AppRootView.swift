import DesignSystem
import DoorSensing
import Services
import SwiftUI

/// Debug-only switches, passed in by the composition root from launch arguments.
public struct DebugOptions: Sendable {
    public var showsComponentGallery = false
    public var showsDoorReadout = false

    public init(showsComponentGallery: Bool = false, showsDoorReadout: Bool = false) {
        self.showsComponentGallery = showsComponentGallery
        self.showsDoorReadout = showsDoorReadout
    }
}

/// The app's root: hosts the hinge sensor and the session screens.
public struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsSplash = true
    @State private var awayMonitor: AppAwayMonitor

    private let dependencies: FeatureDependencies
    private let debug: DebugOptions

    public init(dependencies: FeatureDependencies, debug: DebugOptions = DebugOptions()) {
        self.dependencies = dependencies
        self.debug = debug
        _awayMonitor = State(initialValue: AppAwayMonitor(sensor: dependencies.doorSensor))
    }

    public var body: some View {
        ZStack {
            if showsSplash {
                SplashScreen(isOnCover: dependencies.doorSensor.hingeReading?.status == .closed)
                    .transition(.opacity)
            } else {
                content
                    .transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(for: SplashScreen.duration)
            // Reduce Motion: a straight cut instead of the cross-fade.
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                showsSplash = false
            }
        }
        .background(HingeSensorAnchor(sensor: dependencies.doorSensor).accessibilityHidden(true))
        // Full screen everywhere: no time, network or battery over the oven (open screen and cover).
        .statusBarHidden()
        .onChange(of: scenePhase) { _, phase in
            // Catch up on deadlines that passed while the app was in the background.
            if phase == .active { dependencies.session.send(.tick) }
            awayMonitor.scenePhaseChanged(to: phase, isBaking: isBaking)
        }
        .onChange(of: dependencies.settings.doorMode, initial: true) { _, mode in
            dependencies.doorSensor.preference = mode
        }
        #if DEBUG
        .overlay(alignment: .top) {
            if debug.showsDoorReadout {
                DoorDebugOverlay(sensor: dependencies.doorSensor)
            }
        }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        if debug.showsComponentGallery {
            ComponentGallery()
        } else {
            SessionRootView(dependencies: dependencies)
        }
        #else
        SessionRootView(dependencies: dependencies)
        #endif
    }

    /// The bake is in the oven: leaving the app now counts as opening the door.
    private var isBaking: Bool {
        switch dependencies.session.phase {
        case .baking, .ajar: true
        default: false
        }
    }
}
