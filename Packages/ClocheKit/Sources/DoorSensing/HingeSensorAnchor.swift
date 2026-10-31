#if canImport(UIKit)
import SwiftUI
import UIKit

/// Invisible view that hosts the hinge interaction. Place it once, behind the root view.
public struct HingeSensorAnchor: UIViewRepresentable {
    private let sensor: AdaptiveDoorSensor

    public init(sensor: AdaptiveDoorSensor) {
        self.sensor = sensor
    }

    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        sensor.attachHinge(to: view)
        return view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif
