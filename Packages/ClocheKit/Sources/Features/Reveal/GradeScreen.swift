import DesignSystem
import Domain
import SwiftUI

/// Reveal and grade, one screen for the iPhone and the Duo (boards "4 Reveal", "5 Grade",
/// "S2 8 Half-baked grade", "Duo 5" and "Duo 6"). The top half is the same oven as everywhere
/// (`OvenFrame` in `OvenStage`'s slot, door off) with steam over a finished bake; the grade sits
/// in the glass of its open door on the bottom half.
///
/// On the Duo the door follows the real hinge as it unfolds. On the iPhone, turned up after a
/// finished bake, the door drops open (700 ms) and the steam rises; Reduce Motion cross-fades.
struct GradeScreen: View {
    let recipe: Recipe
    let outcome: BakeOutcome
    let door: DoorStyle
    let send: (SessionEvent) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 0 still shut, 1 open. Drives the iPhone's door drop; the Duo's door follows its hinge.
    @State private var opening: Double

    init(recipe: Recipe, outcome: BakeOutcome, door: DoorStyle, send: @escaping (SessionEvent) -> Void) {
        self.recipe = recipe
        self.outcome = outcome
        self.door = door
        self.send = send
        // A half-baked bake was opened early: the door is already open.
        _opening = State(initialValue: door.followsHinge || !outcome.isFullyBaked ? 1 : 0)
    }

    /// The door's lift: the hinge on the Duo, otherwise dropping from upright to flat.
    private var liftDegrees: Double {
        door.followsHinge ? door.liftDegrees : (1 - opening) * 90
    }

    var body: some View {
        let grade = GradeCalculator.grade(outcome, served: true)
        let copy = GradeCopy(grade: grade, isDemo: outcome.bake.isDemo)
        let dishProgress = grade.isHalfBaked ? max(outcome.doneness * 0.5, 0.3) : 1

        OvenStage(isContentFullBleed: true) {
            EmptyView()
        } oven: {
            OvenFrame(
                plate: outcome.isFullyBaked ? Text("Prêt.", bundle: .module) : Text("Done", bundle: .module),
                isPlateItalic: outcome.isFullyBaked,
                heat: grade.isHalfBaked ? 0.8 : 1,
                dish: Dish(recipeID: recipe.id),
                dishProgress: dishProgress,
                browning: grade.browning,
                showsDoor: false
            )
            .overlay {
                if !grade.isHalfBaked {
                    SteamView()
                        .opacity(opening)
                }
            }
            .accessibilityHidden(true)
        } content: {
            DoorPanel(liftDegrees: liftDegrees) {
                gradeContent(grade: grade, copy: copy, dishProgress: dishProgress)
                    .opacity(opening)
            }
        }
        .hingeCrease(door)
        .background(Palette.black.ignoresSafeArea())
        .onAppear {
            guard opening < 1 else { return }
            withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .easeInOut(duration: 0.7).delay(0.15)) {
                opening = 1
            }
        }
    }

    private func gradeContent(grade: Grade, copy: GradeCopy, dishProgress: Double) -> some View {
        VStack(spacing: Spacing.s3) {
            HStack(spacing: Spacing.s4) {
                DishView(dish: Dish(recipeID: recipe.id), progress: dishProgress, browning: grade.browning, showsPlate: true)
                    .frame(width: 110, height: 110)
                VStack(alignment: .leading, spacing: Spacing.s1) {
                    EyebrowLabel(copy.eyebrow)
                        .accessibilityIdentifier("grade.eyebrow")
                    (grade.isHalfBaked ? Text("Half-baked.", bundle: .module) : Text("Prêt.", bundle: .module))
                        .textStyle(.hero.sized(grade.isHalfBaked ? 40 : 48, lineHeight: 52))
                        .foregroundStyle(Palette.sand)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .accessibilityIdentifier("reveal.title")
                    Stars(earned: grade.stars, size: 22)
                        .accessibilityIdentifier("grade.stars")
                    copy.voiceLine
                        .textStyle(.voice(15))
                        .foregroundStyle(Palette.sand)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            DonenessBar(copy: copy)

            Spacer(minLength: 0)

            HStack(spacing: Spacing.s3) {
                Button {
                    send(.decorate)
                } label: {
                    Text("Decorate", bundle: .module)
                }
                .buttonStyle(.primary)
                .accessibilityLabel(Text("Decorate, \(Int(outcome.bake.breakDuration / 60)) minute break", bundle: .module))
                .accessibilityIdentifier("grade.decorate")
                Button {
                    send(.servePlain)
                } label: {
                    Text("Serve plain", bundle: .module)
                }
                .buttonStyle(.outline)
                .accessibilityIdentifier("grade.servePlain")
            }
        }
    }
}
