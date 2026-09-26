import AppKit
import Testing
@testable import PliSystem

/// The address of a C function that does nothing and returns 0: a stand-in for any private symbol.
private func stubAddress() -> UnsafeMutableRawPointer {
    let stub: @convention(c) () -> Int32 = { 0 }
    return unsafeBitCast(stub, to: UnsafeMutableRawPointer.self)
}

@MainActor @Suite struct PrivateAPITests {
    /// A pretend library: every name in `present` resolves to a harmless function, everything else is missing.
    private func loader(present: Set<String>, libraryExists: Bool = true) -> PrivateAPI.SymbolLoader {
        PrivateAPI.SymbolLoader(open: { _ in libraryExists ? stubAddress() : nil },
                                find: { _, name in present.contains(name) ? stubAddress() : nil })
    }

    private let skyLightNames: Set<String> = ["SLSMainConnectionID", "SLSSpaceCreate", "SLSSpaceSetAbsoluteLevel",
                                              "SLSShowSpaces", "SLSSpaceAddWindowsAndRemoveFromSpaces"]

    @Test func everySymbolPresentTurnsTheFeaturesOn() {
        let all = loader(present: skyLightNames.union(["SACLockScreenImmediate", "CGSMainConnectionID", "CGSSetConnectionProperty"]))
        #expect(PrivateAPI.skyLight(using: all) != nil)
        #expect(PrivateAPI.login(using: all) != nil)
        #expect(PrivateAPI.cursor(using: all) != nil)
    }

    @Test func oneMissingSymbolTurnsOnlyItsFeatureOff() {
        let noShowSpaces = loader(present: skyLightNames.subtracting(["SLSShowSpaces"]).union(["SACLockScreenImmediate"]))
        #expect(PrivateAPI.skyLight(using: noShowSpaces) == nil)
        #expect(PrivateAPI.login(using: noShowSpaces) != nil)
        #expect(PrivateAPI.cursor(using: noShowSpaces) == nil)
    }

    @Test func aMissingLibraryTurnsEverythingOff() {
        let gone = loader(present: skyLightNames, libraryExists: false)
        #expect(PrivateAPI.skyLight(using: gone) == nil)
        #expect(PrivateAPI.login(using: gone) == nil)
        #expect(PrivateAPI.cursor(using: gone) == nil)
    }

    @Test func absentFeaturesDoNothingAndSayWhy() {
        #expect(LockScreenSpace(functions: nil) == nil)
        let locker = ScreenLocker(functions: nil)
        #expect(!locker.isAvailable)
        #expect(!locker.lockNow())
        final class Count { var hides = 0; var shows = 0 }
        let count = Count()
        let cursor = BackgroundCursor(functions: nil, hide: { count.hides += 1 }, show: { count.shows += 1 })
        cursor.setHidden(true)
        #expect(!cursor.isAvailable && count.hides == 0 && !cursor.isHidden)
    }

    @Test func theCursorIsHiddenAndShownInPairs() {
        final class Count { var hides = 0; var shows = 0 }
        let count = Count()
        let functions = PrivateAPI.CursorFunctions(mainConnectionID: { 7 }, setConnectionProperty: { _, _, _, _ in 0 })
        let cursor = BackgroundCursor(functions: functions, hide: { count.hides += 1 }, show: { count.shows += 1 })
        cursor.setHidden(true)
        cursor.setHidden(true)
        #expect(count.hides == 1 && cursor.isHidden)
        cursor.setHidden(false)
        cursor.setHidden(false)
        #expect(count.shows == 1 && !cursor.isHidden)
    }

    @Test func theRealLookupNeverCrashes() {
        // On the owner's macOS 26.5 all three resolve; on a future macOS some may not, and that must be fine.
        _ = PrivateAPI.skyLight()
        _ = PrivateAPI.login()
        _ = PrivateAPI.cursor()
        #expect(PrivateAPI.SymbolLoader.system.resolve(["NoSuchFunction"], in: PrivateAPI.skyLightPath) == nil)
        #expect(PrivateAPI.SymbolLoader.system.resolve(["Anything"], in: "/System/Library/PrivateFrameworks/Nope.framework/Nope") == nil)
    }
}
