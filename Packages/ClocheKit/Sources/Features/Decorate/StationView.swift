import Decorating
import DesignSystem
import SwiftUI

/// The decorating station (decorating plan §5.5): a pastry chef's mise en place around the live
/// cake. Every seat, cradle and control sits where `StationLayout` says; one tap picks a colour,
/// a nozzle, a topping or a tool. The selected item lifts 6 % and glows brass. The shelf, the
/// rail and the controls slide into their seats in that order (Reduce Motion: a fade).
struct StationView: View {
    let model: DecorStudioModel
    let layout: StationLayout
    let isRevealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let (scale, origin) = layout.transform(for: geo.size)
            let window = layout.cakeWindowPx
            ZStack(alignment: .topLeading) {
                if let panel = StationLayout.panel(layout.shape) {
                    Image(uiImage: panel)
                        .resizable()
                        .frame(width: layout.size.width * scale, height: layout.size.height * scale)
                        .offset(x: origin.x, y: origin.y)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .modifier(Reveal(isRevealed: isRevealed, order: 0, reduceMotion: reduceMotion))
                }
                ForEach(Array(layout.items.enumerated()), id: \.element.id) { index, item in
                    if item.group == "toppings", layout.shape == "iphone" {
                        EmptyView()
                    } else {
                        seat(item, scale: scale)
                            .position(x: origin.x + item.centrePx[0] * scale, y: origin.y + item.centrePx[1] * scale)
                            .modifier(Reveal(isRevealed: isRevealed, order: order(of: item), reduceMotion: reduceMotion))
                    }
                }
                if layout.shape == "iphone" {
                    toppingsShelf(scale: scale, origin: origin)
                        .modifier(Reveal(isRevealed: isRevealed, order: 1, reduceMotion: reduceMotion))
                }
                statusStrip
                    .frame(width: (window[2] - window[0]) * scale)
                    .offset(x: origin.x + window[0] * scale, y: origin.y + window[1] * scale - HitTarget.minimum / 2)
            }
        }
        .ignoresSafeArea()
    }

    private func order(of item: StationLayout.Item) -> Int {
        switch item.group {
        case "ingredients", "nozzles": 0
        case "toppings", "tools": 1
        default: 2
        }
    }

    /// The iPhone's toppings row scrolls and snaps to its seats with a haptic tick.
    private func toppingsShelf(scale: CGFloat, origin: CGPoint) -> some View {
        let items = layout.items(in: "toppings")
        let pitch = items.count > 1 ? (items[1].centrePx[0] - items[0].centrePx[0]) * scale : 60
        let y = (items.first?.centrePx[1] ?? 0) * scale + origin.y
        return ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(items) { item in
                    seat(item, scale: scale).frame(width: pitch)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .sensoryFeedback(.selection, trigger: model.topping)
        .frame(width: layout.size.width * scale - 2 * Spacing.s4, height: pitch * 1.1)
        .position(x: layout.size.width * scale / 2 + origin.x, y: y)
    }

    @ViewBuilder
    private func seat(_ item: StationLayout.Item, scale: CGFloat) -> some View {
        let size = CGSize(width: item.sizePx[0] * scale, height: item.sizePx[1] * scale)
        let selected = isSelected(item)
        Button { pick(item) } label: {
            SeatArt(item: item, size: size, isSelected: selected)
                .frame(width: max(size.width, HitTarget.minimum), height: max(size.height, HitTarget.minimum))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(selected ? 1.06 : 1)
        .animation(reduceMotion ? nil : .spring(duration: 0.25), value: selected)
        .accessibilityLabel(Text(DecorCopy.label(item.name), bundle: .module))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("decorate.\(item.name)")
    }

    private func isSelected(_ item: StationLayout.Item) -> Bool {
        switch item.kind {
        case "seat_pot": ViewerAssets.palette.firstIndex { $0.name == item.name } == model.colour
        case "seat_nozzle": item.name == "Nozzle" + model.nozzle.rawValue.capitalized && model.tool == .cone
        case "seat_bowl": item.name == model.topping && model.tool == .topping
        case "cradle": DecorCatalog.tools.first { $0.sprite == item.name }?.tool == model.tool
        default: false
        }
    }

    private func pick(_ item: StationLayout.Item) {
        switch item.kind {
        case "seat_pot":
            if let i = ViewerAssets.palette.firstIndex(where: { $0.name == item.name }) {
                model.colour = i
                if model.tool == .topping { model.tool = .cone }
            }
        case "seat_nozzle":
            model.nozzle = Nozzle(rawValue: item.name.replacingOccurrences(of: "Nozzle", with: "").lowercased()) ?? .round
            model.tool = .cone
        case "seat_bowl":
            model.topping = item.name
            model.tool = .topping
        case "cradle":
            if let tool = DecorCatalog.tools.first(where: { $0.sprite == item.name })?.tool { model.tool = tool }
        default:
            control(item.name)
        }
    }

    private func control(_ name: String) {
        switch name {
        case "undo": model.undo()
        case "clear": model.clear()
        case "turntable": model.toggleTurntable()
        case "speed": model.cycleSpeed()
        case "plate": model.setPlate(model.plate == "carrara" ? "emperador" : "carrara")
        case "backdrop": model.setBackdrop(model.backdrop == "night" ? "linen" : "night")
        default: break
        }
    }

    /// The slim strip over the cake: tool, colour, nozzle or topping.
    private var statusStrip: some View {
        HStack(spacing: Spacing.s2) {
            Text(DecorCopy.label(DecorCatalog.tools.first { $0.tool == model.tool }?.sprite ?? "topping"), bundle: .module)
            if model.tool == .topping {
                Text(DecorCopy.label(model.topping), bundle: .module)
            } else {
                Text(DecorCopy.label(ViewerAssets.palette[model.colour].name), bundle: .module)
                if model.tool == .cone { Text(DecorCopy.label("Nozzle" + model.nozzle.rawValue.capitalized), bundle: .module) }
            }
        }
        .textStyle(.control)
        .foregroundStyle(Palette.text)
        .lineLimit(1)
        .padding(.horizontal, Spacing.s3)
        .frame(height: HitTarget.minimum - Spacing.s2)
        .background(Capsule().fill(Palette.ground.opacity(0.7)))
        .accessibilityElement(children: .combine)
    }
}

/// The art for one seat: the rendered vessel or tool sprite with its shadow, or a code-drawn
/// stand-in; controls are app-drawn labels.
private struct SeatArt: View {
    let item: StationLayout.Item
    let size: CGSize
    let isSelected: Bool

    var body: some View {
        ZStack {
            if item.kind == "control" {
                Text(DecorCopy.label(item.name), bundle: .module)
                    .textStyle(.control)
                    .foregroundStyle(Palette.text)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(.horizontal, Spacing.s2)
                    .frame(minWidth: HitTarget.minimum, minHeight: HitTarget.minimum)
                    .background(Capsule().fill(Palette.ground.opacity(0.7)))
                    .overlay(Capsule().strokeBorder(Palette.line3, lineWidth: 1))
            } else if let sprite = DecorCatalog.sprite(spriteName) {
                if let shadow = DecorCatalog.sprite(spriteName + (isSelected ? "_shadow_lifted" : "_shadow")) {
                    Image(uiImage: shadow).resizable().scaledToFit()
                }
                Image(uiImage: sprite).resizable().scaledToFit()
            } else {
                Circle()
                    .fill(standInColour)
                    .overlay(Circle().strokeBorder(Palette.sand.opacity(0.8), lineWidth: 2))
                    .padding(size.width * 0.12)
            }
        }
        .frame(width: size.width, height: size.height)
        .shadow(color: isSelected ? Palette.sand.opacity(0.9) : .clear, radius: isSelected ? 10 : 0)
        .accessibilityHidden(true)
    }

    private var spriteName: String {
        switch item.kind {
        case "seat_pot": "vessel_pot_\(item.name)"
        case "seat_bowl": "vessel_bowl_\(item.name)"
        case "seat_nozzle": "vessel_nozzle_tray"
        case "cradle": "tool_\(item.name)_idle"
        default: item.name
        }
    }

    private var standInColour: Color {
        if item.kind == "seat_pot", let c = ViewerAssets.palette.first(where: { $0.name == item.name }) {
            let (r, g, b) = c.rgb
            return Color(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
        }
        return Palette.surface
    }
}

/// Slides a station group into its seat in order over about 0.6 s; Reduce Motion fades.
private struct Reveal: ViewModifier {
    let isRevealed: Bool
    let order: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isRevealed ? 1 : 0)
            .offset(y: isRevealed || reduceMotion ? 0 : (order == 0 ? -40 : 40))
            .animation(reduceMotion ? .easeInOut(duration: 0.3) : .easeOut(duration: 0.3).delay(Double(order) * 0.15), value: isRevealed)
    }
}
