import Domain
@testable import DoorSensing
import Testing

@MainActor
struct AdaptiveDoorSensorTests {
    @Test func startsOpenOnFaceDownWhenNoHingeHasReported() {
        let sensor = AdaptiveDoorSensor()
        #expect(sensor.source == .faceDown)
        #expect(sensor.state == .open)
    }

    @Test func manualOverrideDrivesTheStreamAndDuplicatesAreDropped() async {
        let sensor = AdaptiveDoorSensor()
        var iterator = sensor.doorStates().makeAsyncIterator()
        #expect(await iterator.next() == .open)

        sensor.manualOverride = .closed
        sensor.manualOverride = .closed
        sensor.manualOverride = .ajar

        #expect(await iterator.next() == .closed)
        #expect(await iterator.next() == .ajar)
    }

    @Test func newListenersGetTheCurrentStateImmediately() async {
        let sensor = AdaptiveDoorSensor()
        sensor.manualOverride = .closed
        var iterator = sensor.doorStates().makeAsyncIterator()
        #expect(await iterator.next() == .closed)
    }
}
