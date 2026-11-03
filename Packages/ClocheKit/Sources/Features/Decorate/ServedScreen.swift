import Decorating
import DesignSystem
import Domain
import SwiftUI
import UIKit

/// Served (decorating plan D6): the finished cake in the live viewer, at an angle and slowly
/// turning, its stars, a time-lapse replay of how it was made, a share image, and Done. A plain
/// serve (nothing decorated) shows the bare bake.
struct ServedScreen: View {
    let outcome: BakeOutcome
    let grade: Grade
    let onDone: () -> Void

    @State private var model: DecorStudioModel
    @State private var replayTask: Task<Void, Never>?
    private let snapshot: UIImage?
    private let dishKey: ViewerAssets.DishKey

    init(outcome: BakeOutcome, grade: Grade, onDone: @escaping () -> Void) {
        self.outcome = outcome
        self.grade = grade
        self.onDone = onDone
        let key: ViewerAssets.DishKey = Dish(recipeID: outcome.bake.recipeID) == .cupcakes ? .cupcake : .cake
        dishKey = key
        let geometry = ViewerAssets.profile(key)?.geometry ?? (key == .cupcake ? .cupcake : .cake)
        let draftKey = DecorDraftStore.key(for: outcome)
        let store = DecorDraftStore.standard
        // An auto-serve at the end of the break never passed through Serve: archive it here.
        let document = store.served(key: draftKey) ?? store.serve(key: draftKey) ?? DecorDocument(dish: geometry)
        _model = State(initialValue: DecorStudioModel(served: document, aspect: 0.46))
        snapshot = CakeSnapshot.image(of: CakeSurfaces(document: document), side: 1080)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Palette.ground.ignoresSafeArea()
            CakeViewerView(model: model, dish: dishKey, browning: grade.browning == .dark ? 1 : 0)
                .ignoresSafeArea()
            VStack(spacing: Spacing.s4) {
                Stars(earned: grade.stars)
                    .accessibilityElement()
                    .accessibilityLabel(Text("\(grade.stars) stars", bundle: .module))
                HStack(spacing: Spacing.s3) {
                    Button(action: replay) {
                        Text("Replay", bundle: .module)
                    }
                    .buttonStyle(.outline)
                    .accessibilityHint(Text("Watch the cake being decorated again", bundle: .module))
                    if let snapshot {
                        ShareLink(item: Image(uiImage: snapshot), preview: SharePreview(Text("My cake", bundle: .module), image: Image(uiImage: snapshot))) {
                            Text("Share", bundle: .module)
                        }
                        .buttonStyle(.outline)
                    }
                }
                Button(action: onDone) {
                    Text("Done", bundle: .module)
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("served.done")
            }
            .padding(Spacing.margin)
            .background(LinearGradient(colors: [.clear, Palette.ground.opacity(0.9)], startPoint: .top, endPoint: .center))
        }
        .onDisappear { replayTask?.cancel() }
        .accessibilityIdentifier("served.screen")
    }

    private func replay() {
        replayTask?.cancel()
        let model = model
        replayTask = Task { await model.replay() }
    }
}

/// A flat, top-down picture of a cake for sharing: the plate, the bake, the icing and toppings.
enum CakeSnapshot {
    @MainActor
    static func image(of surfaces: CakeSurfaces, side: CGFloat) -> UIImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        let icing = IcingImage.make(surfaces.top)?.colour
        let g = surfaces.geometry
        return renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor(red: 0.055, green: 0.055, blue: 0.05, alpha: 1).setFill()
            cg.fill(CGRect(x: 0, y: 0, width: side, height: side))
            let plate = side * 0.92
            UIColor(white: 0.93, alpha: 1).setFill()
            cg.fillEllipse(in: CGRect(x: (side - plate) / 2, y: (side - plate) / 2, width: plate, height: plate))
            let mmToPx = plate / 300
            let cake = CGFloat(g.radius * 2) * mmToPx
            let rect = CGRect(x: (side - cake) / 2, y: (side - cake) / 2, width: cake, height: cake)
            UIColor(red: 0.8, green: 0.55, blue: 0.27, alpha: 1).setFill()
            cg.fillEllipse(in: rect)
            if let icing {
                cg.saveGState()
                cg.addEllipse(in: rect)
                cg.clip()
                cg.draw(icing, in: rect)
                cg.restoreGState()
            }
            for p in surfaces.placements where p.at.surface == .top {
                let x = side / 2 + CGFloat(p.at.a * cos(p.at.b)) * mmToPx
                let y = side / 2 - CGFloat(p.at.a * sin(p.at.b)) * mmToPx
                let r: CGFloat = p.kind == "sprinkle" ? 1.6 : 5
                ToppingColour.of(p.kind, variant: p.variant).setFill()
                cg.fillEllipse(in: CGRect(x: x * 1 - r * mmToPx / 2, y: y - r * mmToPx / 2, width: r * mmToPx, height: r * mmToPx))
            }
        }
    }
}

@MainActor
enum ToppingColour {
    static func of(_ kind: String, variant: Int) -> UIColor {
        switch kind {
        case "raspberry", "strawberry_slice": UIColor(red: 0.56, green: 0.06, blue: 0.16, alpha: 1)
        case "blueberry": UIColor(red: 0.11, green: 0.13, blue: 0.25, alpha: 1)
        case "cherry": UIColor(red: 0.43, green: 0.04, blue: 0.09, alpha: 1)
        case "mint_leaf": UIColor(red: 0.16, green: 0.37, blue: 0.14, alpha: 1)
        case "chocolate_curl", "chocolate_shard": UIColor(red: 0.18, green: 0.1, blue: 0.07, alpha: 1)
        case "gold_flake": UIColor(red: 0.91, green: 0.76, blue: 0.42, alpha: 1)
        case "sugar_pearl": UIColor(white: 0.95, alpha: 1)
        case "pistachio_crumb": UIColor(red: 0.42, green: 0.54, blue: 0.16, alpha: 1)
        case "almond_flake": UIColor(red: 0.92, green: 0.85, blue: 0.71, alpha: 1)
        case "flower_petal": UIColor(red: 0.85, green: 0.44, blue: 0.56, alpha: 1)
        case "sprinkle": ToppingFactory.sprinkleColours[variant % ToppingFactory.sprinkleColours.count]
        default: UIColor(white: 0.8, alpha: 1)
        }
    }
}
