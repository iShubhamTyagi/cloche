import DesignSystem
import DoorSensing
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

/// Entry screen. Replaced by the Prep screen in Phase 1.4.
public struct AppRootView: View {
    private let doorSensor: AdaptiveDoorSensor
    private let debug: DebugOptions

    public init(doorSensor: AdaptiveDoorSensor, debug: DebugOptions = DebugOptions()) {
        self.doorSensor = doorSensor
        self.debug = debug
    }

    public var body: some View {
        content
            .background(HingeSensorAnchor(sensor: doorSensor).accessibilityHidden(true))
            #if DEBUG
            .overlay(alignment: .bottom) {
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
            placeholder
        }
        #else
        placeholder
        #endif
    }

    private var placeholder: some View {
        VStack(spacing: Spacing.s3) {
            Text("Pocket Oven", bundle: .module)
                .textStyle(.title)
                .foregroundStyle(Palette.text)
                .accessibilityIdentifier("root.title")
            Text("Closed to commit, open to create.", bundle: .module)
                .textStyle(.voice(22))
                .foregroundStyle(Palette.sand)
        }
        .padding(.horizontal, Spacing.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .pocketScreenBackground()
    }
}

#Preview {
    AppRootView(doorSensor: AdaptiveDoorSensor(), debug: DebugOptions(showsDoorReadout: true))
}
