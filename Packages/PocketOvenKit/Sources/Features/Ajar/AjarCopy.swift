import DesignSystem
import Domain
import SwiftUI

/// Words for the door-ajar screens (boards S2 7 and Duo 2).
struct AjarCopy {
    let source: DoorSource

    var headline: Text {
        switch source {
        case .hinge: Text("Lift the door shut.", bundle: .module)
        default: Text("Shut the door.", bundle: .module)
        }
    }

    var helper: Text {
        switch source {
        case .hinge: Text("Close the phone to keep baking. Left open, this bake ends as half-baked.", bundle: .module)
        default: Text("Place the phone face down to keep baking. Left up, this bake ends as half-baked.", bundle: .module)
        }
    }

    func ringLabel(_ remaining: TimeInterval) -> Text {
        Text("\(CountdownFormat.seconds(remaining)) seconds left", bundle: .module)
    }
}
