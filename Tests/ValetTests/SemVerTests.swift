import Testing
@testable import Valet

@Suite struct SemVerTests {
    @Test func parsesPlainAndPrefixedVersions() {
        #expect(SemVer("1.2.3") == SemVer(major: 1, minor: 2, patch: 3))
        #expect(SemVer("v0.1.0") == SemVer(major: 0, minor: 1, patch: 0))
        #expect(SemVer("2.0") == SemVer(major: 2, minor: 0, patch: 0))
        #expect(SemVer("garbage") == nil)
        #expect(SemVer("") == nil)
    }

    @Test func comparesCorrectly() {
        #expect(SemVer("1.0.0")! < SemVer("1.0.1")!)
        #expect(SemVer("1.9.9")! < SemVer("2.0.0")!)
        #expect(SemVer("0.1.0")! < SemVer("0.2.0")!)
        #expect(!(SemVer("1.0.0")! < SemVer("1.0.0")!))
    }
}
