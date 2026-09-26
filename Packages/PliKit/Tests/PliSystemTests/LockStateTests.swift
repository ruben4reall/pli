import Foundation
import Testing
@testable import PliSystem

@Suite struct LockStateTests {
    @Test func theLockedFlagIsRead() {
        #expect(LockState.isLocked(session: ["CGSSessionScreenIsLocked": true]))
        #expect(LockState.isLocked(session: ["CGSSessionScreenIsLocked": NSNumber(value: 1)]))
        #expect(!LockState.isLocked(session: ["CGSSessionScreenIsLocked": false]))
    }

    @Test func aMissingOrOddValueMeansUnlocked() {
        #expect(!LockState.isLocked(session: nil))
        #expect(!LockState.isLocked(session: [:]))
        #expect(!LockState.isLocked(session: ["kCGSSessionOnConsoleKey": true]))
        #expect(!LockState.isLocked(session: ["CGSSessionScreenIsLocked": "yes"]))
    }

    @Test func theLiveSessionCanBeRead() {
        // While tests run, someone is logged in and the screen is unlocked.
        #expect(!LockState.current())
    }
}
