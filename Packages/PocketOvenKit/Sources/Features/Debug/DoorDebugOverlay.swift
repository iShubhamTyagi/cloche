#if DEBUG
import DesignSystem
import DoorSensing
import Domain
import SwiftUI

/// Gate 0 readout: which door source is active, what it reports, and raw hinge / gravity values.
/// The Closed / Ajar / Open buttons stand in for sensors in the simulator. Debug builds only.
struct DoorDebugOverlay: View {
    @Bindable var sensor: AdaptiveDoorSensor
    /// Collapsed to a small chip so it never covers the screen's own controls.
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.s2) {
            Button {
                isExpanded.toggle()
            } label: {
                Text(verbatim: "\(sensor.source.rawValue) · \(sensor.state.rawValue) \(isExpanded ? "▴" : "▾")")
                    .font(.system(size: 12, design: .monospaced))
                    .padding(.horizontal, Spacing.s3)
                    .frame(minHeight: HitTarget.minimum)
                    .background(.black.opacity(0.75), in: Capsule())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Palette.text)
            .accessibilityIdentifier("doorDebug.toggle")

            if isExpanded {
                panel
            }
        }
        .padding(.horizontal, Spacing.s3)
        .accessibilityElement(children: .contain)
    }

    private var panel: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            row("Source", sensor.source.rawValue)
            row("Door", sensor.state.rawValue)
            row("Hinge", hingeText)
            row("Gravity z", sensor.faceDown.gravityZ.map { String(format: "%.3f", $0) } ?? (sensor.faceDown.isAvailable ? "waiting" : "no motion sensor"))

            Picker(selection: $sensor.preference) {
                Text(verbatim: "Automatic").tag(DoorModePreference.automatic)
                Text(verbatim: "Face-down").tag(DoorModePreference.faceDown)
            } label: {
                Text(verbatim: "Door mode")
            }
            .pickerStyle(.segmented)

            HStack(spacing: Spacing.s2) {
                overrideButton("Closed", .closed)
                overrideButton("Ajar", .ajar)
                overrideButton("Open", .open)
                Button(String("Sensors")) { sensor.manualOverride = nil }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("doorDebug.sensors")
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .foregroundStyle(Palette.text)
        .padding(Spacing.s3)
        .background(.black.opacity(0.85), in: RoundedRectangle(cornerRadius: Radius.chip))
        .accessibilityElement(children: .contain)
    }

    private var hingeText: String {
        guard let reading = sensor.hingeReading else {
            return sensor.hingePresent ? "present" : "none"
        }
        return "\(reading.status.rawValue) · angle \(String(format: "%.2f", reading.angle))"
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(verbatim: label).foregroundStyle(Palette.muted)
            Spacer()
            Text(verbatim: value).accessibilityIdentifier("doorDebug.\(label)")
        }
    }

    private func overrideButton(_ title: String, _ state: DoorState) -> some View {
        Button(title) { sensor.manualOverride = state }
            .buttonStyle(.borderedProminent)
            .tint(sensor.manualOverride == state ? Palette.sand : Palette.surface)
            .accessibilityIdentifier("doorDebug.override.\(state.rawValue)")
    }
}
#endif
