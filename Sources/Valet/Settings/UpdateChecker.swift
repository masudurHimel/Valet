import Foundation

struct SemVer: Comparable, Equatable {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(_ string: String) {
        var s = string
        if s.hasPrefix("v") { s.removeFirst() }
        let parts = s.split(separator: ".").map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        major = parts[0]!
        minor = parts.count > 1 ? parts[1]! : 0
        patch = parts.count > 2 ? parts[2]! : 0
    }

    static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

/// THE ONLY NETWORK CODE IN VALET. Runs exclusively when the user clicks
/// "Check for Updates" in the About tab. One GET to the GitHub Releases API.
final class UpdateChecker {
    static let repoSlug = "masudurHimel/Valet"
    /// Read from the built bundle (injected from the VERSION file at build time
    /// by Scripts/make-app.sh) so there is a single source of truth. Falls back
    /// to "0.0.0" outside a bundle (e.g. `swift run`, unit tests); that fallback
    /// can only ever over-report an available update, never suppress a real one.
    static var currentVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
    }

    enum Status: Equatable {
        case upToDate
        case updateAvailable(String)
        case failed
    }

    func check() async -> Status {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repoSlug)/releases/latest"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let latest = SemVer(tag),
              let current = SemVer(Self.currentVersion)
        else { return .failed }
        return current < latest ? .updateAvailable(tag) : .upToDate
    }
}
