import DesignSystem
import Domain
import SwiftUI

/// Words and positions for the grade card (boards 5 Grade and S2 8 Half-baked grade).
struct GradeCopy {
    let grade: Grade
    var isDemo = false

    var eyebrow: Text {
        grade.isHalfBaked ? Text("Opened early", bundle: .module) : Text("Fresh from the oven", bundle: .module)
    }

    /// The italic line under the stars. Nothing ever scolds.
    var voiceLine: Text {
        if isDemo {
            return Text("A demo bake. Real bakes earn the stars.", bundle: .module)
        }
        if grade.isHalfBaked {
            return Text("Nothing is lost. It still goes in your recipe book.", bundle: .module)
        }
        switch grade.browning {
        case .golden: return Text("Golden all over. Just right.", bundle: .module)
        case .pale: return Text("A little pale. A hotter oven next time.", bundle: .module)
        case .dark: return Text("A touch dark. A cooler oven next time.", bundle: .module)
        }
    }

    var donenessLabel: Text {
        grade.isHalfBaked ? Text("Half-baked", bundle: .module) : Text("Fully baked", bundle: .module)
    }

    var donenessPercent: Int {
        Int((min(max(grade.doneness, 0), 1) * 100).rounded())
    }

    var browningLabel: Text {
        switch grade.browning {
        case .pale: Text("Pale", bundle: .module)
        case .golden: Text("Golden", bundle: .module)
        case .dark: Text("Dark", bundle: .module)
        }
    }

    /// Marker position on the pale-to-dark browning bar, 0 to 1.
    static func browningPosition(_ browning: Browning) -> Double {
        switch browning {
        case .pale: 0.12
        case .golden: 0.5
        case .dark: 0.88
        }
    }
}
