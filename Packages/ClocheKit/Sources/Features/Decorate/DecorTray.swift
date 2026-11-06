import Decorating
import DesignSystem
import SwiftUI
import UIKit

/// The bottom half of decorating: Cream, Pipe, Top, one at a time, and only that step's choices,
/// with the turntable and Undo always to hand.
struct DecorTray: View {
    let model: DecorStudioModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: Spacing.s3) {
            HStack(spacing: Spacing.s2) {
                ForEach(DecorStep.allCases, id: \.self) { step in
                    stepTab(step)
                }
                Spacer(minLength: Spacing.s2)
                Button { model.toggleSpin() } label: {
                    Text(model.isSpinning ? "Stop" : "Spin", bundle: .module)
                        .textStyle(.control)
                        .foregroundStyle(Palette.text)
                        .padding(.horizontal, Spacing.s3)
                        .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                        .overlay(Capsule().strokeBorder(model.isSpinning ? Palette.accent : Palette.brassLine, lineWidth: model.isSpinning ? 2 : 1))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(model.isSpinning ? "Stop the turntable" : "Spin the turntable", bundle: .module))
                .accessibilityIdentifier("decorate.spin")
                Button { model.undo() } label: {
                    Text("Undo", bundle: .module)
                        .textStyle(.control)
                        .foregroundStyle(model.canUndo ? Palette.text : Palette.subtle)
                        .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!model.canUndo)
                .accessibilityIdentifier("decorate.undo")
            }
            Spacer(minLength: 0)
            choices
            if model.step == .top, !model.isAtBowls {
                Button { model.showBowls() } label: {
                    Text("Tap the cake to add, or go back to the bowls", bundle: .module)
                        .textStyle(.voice(16))
                        .foregroundStyle(Palette.brass)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: HitTarget.minimum)
                }
                .buttonStyle(.plain)
            } else {
                Text(DecorCopy.hint(model.step), bundle: .module)
                    .textStyle(.voice(16))
                    .foregroundStyle(Palette.brass)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .sensoryFeedback(.impact(weight: .light, intensity: 0.6), trigger: model.tick)
        .accessibilityActions { accessibilityRoutes }
    }

    private func stepTab(_ step: DecorStep) -> some View {
        let isSelected = model.step == step
        return Button { model.step = step } label: {
            Text(DecorCopy.step(step), bundle: .module)
                .textStyle(.eyebrow)
                .foregroundStyle(isSelected ? Palette.text : Palette.muted)
                .padding(.horizontal, Spacing.s2)
                .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                .overlay(alignment: .bottom) {
                    Capsule().fill(isSelected ? Palette.brass : .clear).frame(height: 2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("decorate.step.\(step.rawValue)")
    }

    @ViewBuilder
    private var choices: some View {
        HStack(spacing: Spacing.s3) {
            if model.step == .top {
                ForEach(DecorCatalog.toppings, id: \.self) { name in
                    DecorChoice(name: name, isSelected: model.topping == name, reduceMotion: reduceMotion) {
                        ToppingIcon(name: name)
                    } action: {
                        model.pick(topping: name)
                    }
                }
            } else {
                ForEach(DecorCatalog.colours, id: \.self) { name in
                    let index = DecorCatalog.paletteIndex(name)
                    let selected = model.step == .cream ? model.creamColour == index : model.pipeColour == index
                    DecorChoice(name: name, isSelected: selected, reduceMotion: reduceMotion) {
                        Circle().fill(Self.colour(index))
                    } action: {
                        if model.step == .cream { model.creamColour = index } else { model.pipeColour = index }
                    }
                }
            }
        }
    }

    /// Icing is food, so its colour comes from the food palette, not the interface's tokens.
    private static func colour(_ index: Int) -> Color {
        let (r, g, b) = ViewerAssets.palette[index].rgb
        return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    /// Dragging isn't an option with VoiceOver, so the same results are one action away.
    @ViewBuilder
    private var accessibilityRoutes: some View {
        if model.step == .cream {
            Button { model.creamWholeCake() } label: { Text("Cream the whole cake", bundle: .module) }
        } else if model.step == .pipe {
            ForEach(model.geometry.pipeRings, id: \.self) { ring in
                Button { model.pipeWholeRing(ring) } label: { Text(ringLabel(ring), bundle: .module) }
            }
        } else if model.step == .top {
            Button { model.placeNextTopping() } label: { Text("Add a topping", bundle: .module) }
        }
    }

    private func ringLabel(_ ring: PipeRing) -> LocalizedStringKey {
        switch ring {
        case .edge: "Pipe the edge"
        case .middle: "Pipe the inner ring"
        case .base: "Pipe the base"
        }
    }
}

/// One colour or topping: a circle with its name under it. Selection shows as a ring and a
/// larger size, never as colour alone.
private struct DecorChoice<Art: View>: View {
    let name: String
    let isSelected: Bool
    let reduceMotion: Bool
    @ViewBuilder let art: Art
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.s2) {
                art
                    .frame(width: HitTarget.minimum + Spacing.s2, height: HitTarget.minimum + Spacing.s2)
                    .padding(Spacing.s1)
                    .overlay(Circle().strokeBorder(isSelected ? Palette.brass : Palette.brassLine, lineWidth: isSelected ? 2 : 1))
                    .scaleEffect(isSelected ? 1.06 : 1)
                    .animation(reduceMotion ? nil : .spring(duration: 0.2), value: isSelected)
                Text(DecorCopy.short(name), bundle: .module)
                    .textStyle(.note)
                    .foregroundStyle(isSelected ? Palette.text : Palette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("decorate.\(name)")
    }
}

/// A topping's rendered heap, loaded once.
private struct ToppingIcon: View {
    let name: String

    @MainActor private static var loaded: [String: UIImage] = [:]

    var body: some View {
        if let image = Self.image(name) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Circle().fill(Palette.surface)
        }
    }

    @MainActor private static func image(_ name: String) -> UIImage? {
        if let image = loaded[name] { return image }
        let image = Bundle.module.url(forResource: "topping_icon_\(name)", withExtension: "png")
            .flatMap { UIImage(contentsOfFile: $0.path) }
        loaded[name] = image
        return image
    }
}
