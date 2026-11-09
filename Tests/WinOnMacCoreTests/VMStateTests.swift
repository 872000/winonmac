import XCTest
@testable import WinOnMacCore

final class VMStateTests: XCTestCase {

    func testStoppedCanStartButNotPauseOrStop() {
        XCTAssertTrue(VMState.stopped.canStart)
        XCTAssertFalse(VMState.stopped.canStop)
        XCTAssertFalse(VMState.stopped.canPause)
        XCTAssertFalse(VMState.stopped.canResume)
        XCTAssertTrue(VMState.stopped.canTakeSnapshot)
        XCTAssertTrue(VMState.stopped.canRestoreSnapshot)
        XCTAssertFalse(VMState.stopped.isBusy)
    }

    func testRunningCanPauseAndStopButNotStart() {
        XCTAssertFalse(VMState.running.canStart)
        XCTAssertTrue(VMState.running.canStop)
        XCTAssertTrue(VMState.running.canPause)
        XCTAssertFalse(VMState.running.canResume)
        XCTAssertFalse(VMState.running.canTakeSnapshot)
    }

    func testPausedCanResumeAndStopButNotPause() {
        XCTAssertTrue(VMState.paused.canResume)
        XCTAssertTrue(VMState.paused.canStop)
        XCTAssertFalse(VMState.paused.canPause)
        XCTAssertFalse(VMState.paused.canStart)
        XCTAssertFalse(VMState.paused.canTakeSnapshot)
    }

    func testBusyStatesBlockUserActions() {
        XCTAssertTrue(VMState.starting.isBusy)
        XCTAssertTrue(VMState.stopping.isBusy)
        XCTAssertFalse(VMState.starting.canStart)
        XCTAssertFalse(VMState.stopping.canStop)
    }

    func testErrorStateCanRetryStart() {
        XCTAssertTrue(VMState.error.canStart)
        XCTAssertTrue(VMState.error.canTransition(to: .starting))
        XCTAssertTrue(VMState.error.canTransition(to: .stopped))
        XCTAssertFalse(VMState.error.canTransition(to: .running))
    }

    func testTransitionTable() {
        XCTAssertTrue(VMState.stopped.canTransition(to: .starting))
        XCTAssertFalse(VMState.stopped.canTransition(to: .running))
        XCTAssertFalse(VMState.stopped.canTransition(to: .paused))
        XCTAssertTrue(VMState.running.canTransition(to: .paused))
        XCTAssertTrue(VMState.running.canTransition(to: .stopping))
        XCTAssertFalse(VMState.running.canTransition(to: .starting))
        XCTAssertTrue(VMState.paused.canTransition(to: .running))
        XCTAssertFalse(VMState.paused.canTransition(to: .starting))
        XCTAssertTrue(VMState.starting.canTransition(to: .running))
        XCTAssertTrue(VMState.stopping.canTransition(to: .stopped))
        XCTAssertFalse(VMState.starting.canTransition(to: .paused))
    }

    func testDisplayNames() {
        XCTAssertEqual(VMState.running.displayName, "Running")
        XCTAssertEqual(VMState.paused.displayName, "Paused")
        XCTAssertEqual(VMState.stopped.displayName, "Stopped")
    }
}
