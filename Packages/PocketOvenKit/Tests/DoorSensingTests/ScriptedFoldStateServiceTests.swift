import Domain
import DoorSensing
import Testing

struct ScriptedFoldStateServiceTests {
    @Test func emitsScriptedStatesInOrderThenFinishes() async {
        let service = ScriptedFoldStateService(steps: [.init(.closed), .init(.ajar), .init(.open)])

        var received: [DoorState] = []
        for await state in service.doorStates() {
            received.append(state)
        }

        #expect(received == [.closed, .ajar, .open])
    }

    @Test func reportsItsDoorSource() {
        let service = ScriptedFoldStateService(source: .hinge, steps: [])
        #expect(service.source == .hinge)
    }
}
