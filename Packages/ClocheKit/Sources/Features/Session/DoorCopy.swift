import Domain
import SwiftUI

/// Wording that depends on how the door closes. Face-down is the default on every iPhone;
/// the Duo closes like an oven door.
struct DoorCopy {
    let source: DoorSource

    var afterPreheatNote: Text {
        switch source {
        case .hinge: Text("Then close the phone", bundle: .module)
        default: Text("Then place the phone face down", bundle: .module)
        }
    }

    var waitingPill: Text {
        switch source {
        case .hinge: Text("Waiting for the fold", bundle: .module)
        default: Text("Waiting for a flat, face-down phone", bundle: .module)
        }
    }

    var preheatHelper: Text {
        switch source {
        case .hinge: Text("Close the phone like an oven door. The bake starts the moment it shuts, and the outer screen keeps the time.", bundle: .module)
        default: Text("Place the phone face down on a flat surface. The bake starts the moment it settles. Turn it over when the time is up.", bundle: .module)
        }
    }

    var preheatFooter: Text? {
        switch source {
        case .hinge: nil
        default: Text("The screen stays dark with a faint glowing line", bundle: .module)
        }
    }
}
