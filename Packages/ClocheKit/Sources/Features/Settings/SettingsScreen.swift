import DesignSystem
import DoorSensing
import SwiftUI

/// Settings, Gate 0 subset: door mode, keep-awake, sounds and the demo bake. The rest
/// (privacy policy, restore purchases, recipe book options) arrives in 2.10 and 3.1.
struct SettingsScreen: View {
    @Bindable var settings: AppSettings
    let hingePresent: Bool
    let onDemoBake: () -> Void
    let onClose: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.margin) {
                HStack {
                    Text("Settings", bundle: .module)
                        .textStyle(.voice(22))
                        .foregroundStyle(Palette.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(action: onClose) {
                        Text("Done", bundle: .module)
                    }
                    .buttonStyle(.text)
                    .accessibilityIdentifier("settings.done")
                }

                section(Text("Door", bundle: .module)) {
                    doorOption(.automatic, title: hingePresent ? Text("Close the phone", bundle: .module) : Text("Face down", bundle: .module), note: hingePresent ? Text("The fold is the oven door.", bundle: .module) : Text("Place the phone screen-down on a flat surface.", bundle: .module))
                    if hingePresent {
                        doorOption(.faceDown, title: Text("Face down", bundle: .module), note: Text("For a desk where folding is awkward.", bundle: .module))
                    }
                }

                section(Text("While baking", bundle: .module)) {
                    toggle(isOn: $settings.keepsScreenAwake, title: Text("Keep the screen awake", bundle: .module), note: Text("A black screen with a faint line, so the oven can tell when the door opens.", bundle: .module), id: "settings.keepAwake")
                    toggle(isOn: $settings.soundsOn, title: Text("Oven sounds", bundle: .module), note: Text("The end chime. The silent switch always mutes it.", bundle: .module), id: "settings.sounds")
                }

                section(Text("Try it", bundle: .module)) {
                    Button(action: onDemoBake) {
                        VStack(alignment: .leading, spacing: Spacing.s1) {
                            Text("Demo bake · 5 seconds", bundle: .module)
                                .textStyle(.body.sized(16))
                                .fontWeight(.medium)
                                .foregroundStyle(Palette.text)
                            Text("A short bake to see the whole loop. It earns no stars.", bundle: .module)
                                .textStyle(.note)
                                .foregroundStyle(Palette.muted)
                        }
                        .frame(maxWidth: .infinity, minHeight: HitTarget.minimum, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("settings.demoBake")
                }

                Text("Everything stays on this phone. No account, no tracking.", bundle: .module)
                    .textStyle(.voice(15))
                    .foregroundStyle(Palette.sand)
            }
            .padding(Spacing.margin)
        }
        .pocketScreenBackground()
    }

    private func section(_ title: Text, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s3) {
            EyebrowLabel(title)
            VStack(alignment: .leading, spacing: Spacing.s3) {
                content()
            }
            .padding(Spacing.s4)
            .background(Palette.surface, in: RoundedRectangle(cornerRadius: Radius.tile))
        }
    }

    private func doorOption(_ mode: DoorModePreference, title: Text, note: Text) -> some View {
        let isSelected = settings.doorMode == mode
        return Button {
            settings.doorMode = mode
        } label: {
            HStack(alignment: .top, spacing: Spacing.s3) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Palette.sand : Palette.subtle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    title.textStyle(.body.sized(16)).fontWeight(.medium).foregroundStyle(Palette.text)
                    note.textStyle(.note).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: HitTarget.minimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func toggle(isOn: Binding<Bool>, title: Text, note: Text, id: String) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: Spacing.s1) {
                title.textStyle(.body.sized(16)).fontWeight(.medium).foregroundStyle(Palette.text)
                note.textStyle(.note).foregroundStyle(Palette.muted)
            }
        }
        .tint(Palette.sand)
        .frame(minHeight: HitTarget.minimum)
        .accessibilityIdentifier(id)
    }
}
