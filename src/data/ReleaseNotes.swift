import Combine
import Foundation

/// What changed, read out of the CHANGELOG.md that make-app.sh copies into the
/// bundle. The version itself is not held here: the app reads it back out of its
/// own Info.plist, which make-app.sh fills from the VERSION file. One number,
/// one place, and nothing to keep in step by hand.
public struct Release {
    public let version: String
    public let date: String
    public let sections: [Section]

    public struct Section {
        public let title: String
        public let items: [String]
    }
}

/// Holds the parsed notes and whether the window is showing them.
///
/// An ObservableObject rather than @State: the macOS 27 SDK ships @State as a
/// macro whose plugin the command line tools do not carry, so it does not
/// compile on this machine.
public final class ReleaseNotes: ObservableObject {
    public static let shared = ReleaseNotes()

    @Published public var showing = false

    /// The last three releases. Headings without a real version — an
    /// "Unreleased" section, say — are read past rather than shown as one.
    public private(set) lazy var releases: [Release] = Self.parse(limit: 3)

    private init() {}

    static func parse(limit: Int) -> [Release] {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parse(markdown: text, limit: limit)
    }

    /// Split out from the bundle so the checks can feed it the real CHANGELOG.md
    /// without an app bundle around them.
    public static func parse(markdown text: String, limit: Int) -> [Release] {
        var out: [(version: String, date: String, sections: [(String, [String])])] = []

        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix("## ") {
                let head = line.dropFirst(3).trimmingCharacters(in: .whitespaces)
                // "[1.4.2] - 2026-09-07"
                guard head.hasPrefix("["), let close = head.firstIndex(of: "]") else { continue }
                let version = String(head[head.index(after: head.startIndex)..<close])
                guard version.split(separator: ".").count == 3,
                      version.split(separator: ".").allSatisfy({ Int($0) != nil }) else { continue }
                let rest = head[head.index(after: close)...]
                let date = rest.split(separator: "-", maxSplits: 1).count > 1
                    ? rest.drop(while: { $0 != "-" }).dropFirst().trimmingCharacters(in: .whitespaces)
                    : ""
                out.append((version, date, []))
            } else if line.hasPrefix("### "), !out.isEmpty {
                out[out.count - 1].sections.append((String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces), []))
            } else if line.hasPrefix("- "), !out.isEmpty, !out[out.count - 1].sections.isEmpty {
                let last = out[out.count - 1].sections.count - 1
                out[out.count - 1].sections[last].1.append(String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            }
        }

        return out.prefix(limit).map { entry in
            Release(version: entry.version,
                    date: entry.date,
                    sections: entry.sections.map { Release.Section(title: $0.0, items: $0.1) })
        }
    }
}
