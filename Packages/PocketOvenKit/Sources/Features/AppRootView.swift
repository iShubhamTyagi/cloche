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

    private let session: SessionController
    private let doorSensor: AdaptiveDoorSensor
    private let screenAwake: any ScreenAwakeControlling
    private let debug: DebugOptions

    public init(session: SessionController, doorSensor: AdaptiveDoorSensor, screenAwake: any ScreenAwakeControlling, debug: DebugOptions = DebugOptions()) {
        self.session = session
        self.doorSensor = doorSensor
        self.screenAwake = screenAwake
        self.debug = debug
    }

    public var body: some View {
        content
            .background(HingeSensorAnchor(sensor: doorSensor).accessibilityHidden(true))
            .onChange(of: scenePhase) { _, phase in
                // Catch up on deadlines that passed while the app was in the background.
                if phase == .active { session.send(.tick) }
            }
            #if DEBUG
            .overlay(alignment: .topTrailing) {
                if debug.showsDoorReadout {
                    DoorDebugOverlay(sensor: doorSensor)
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
            SessionRootView(session: session, doorSensor: doorSensor, screenAwake: screenAwake)
        }
        #else
        SessionRootView(session: session, doorSensor: doorSensor, screenAwake: screenAwake)
        #endif
    }
}
