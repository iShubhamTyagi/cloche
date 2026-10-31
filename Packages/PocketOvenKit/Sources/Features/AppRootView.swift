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

    private let dependencies: FeatureDependencies
    private let debug: DebugOptions

    public init(dependencies: FeatureDependencies, debug: DebugOptions = DebugOptions()) {
        self.dependencies = dependencies
        self.debug = debug
    }

    public var body: some View {
        content
            .background(HingeSensorAnchor(sensor: dependencies.doorSensor).accessibilityHidden(true))
            .onChange(of: scenePhase) { _, phase in
                // Catch up on deadlines that passed while the app was in the background.
                if phase == .active { dependencies.session.send(.tick) }
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
}
