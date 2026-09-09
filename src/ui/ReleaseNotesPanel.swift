import AppKit
import SwiftUI
import DuckCore

/// What changed, laid over the window. The version number in the foot opens it, the arrow
/// and the escape key close it.
///
/// The releases are read from the CHANGELOG.md that make-app.sh copies into the bundle, so
/// there is no network call, nothing to keep in step by hand, and the panel works with no
/// signal. Someone who installed Duck with one line in Terminal, or through Homebrew, never
/// sees a release page; this is the only place they are told what changed.
struct ReleaseNotesPanel: View {
    @ObservedObject var notes: ReleaseNotes
    let close: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            rule
            if notes.releases.isEmpty {
                empty
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Ink.paper)
    }

    // MARK: Head

    private var header: some View {
        HStack(spacing: 8) {
            Back(action: close)
            Text("What's new")
                .font(Type.serif(17))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    // MARK: Body

    /// The newest release has to be the one in view when the panel opens. A ScrollView left
    /// to itself does not always start at the top here, so the top is a named anchor and the
    /// panel scrolls to it as it arrives, with no animation: it should already be there.
    private static let top = "top"

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear
                        .frame(height: 1)
                        .id(Self.top)
                    ForEach(Array(notes.releases.enumerated()), id: \.offset) { index, release in
                        if index > 0 { rule }
                        entry(release)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
            }
            .onAppear {
                DispatchQueue.main.async { proxy.scrollTo(Self.top, anchor: .top) }
            }
        }
    }

    private func entry(_ release: Release) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(release.version)
                    .font(Type.serif(20))
                Spacer(minLength: 8)
                Text(Self.day(release.date))
                    .font(Type.sans(12))
                    .monospacedDigit()
                    .foregroundStyle(Ink.muted)
            }
            ForEach(Array(release.sections.enumerated()), id: \.offset) { _, section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(Type.medium(12.5))
                        .foregroundStyle(Ink.muted)
                    ForEach(Array(section.items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("·")
                                .foregroundStyle(Ink.edge)
                            Text(item)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 16)
    }

    /// Nothing to show is a sentence, not a blank panel. It only happens in a build whose
    /// changelog did not make it into the bundle.
    private var empty: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No notes in this build.")
            Link("The changes are on GitHub",
                 destination: URL(string: "https://github.com/hellodigitworks/Duck/releases")!)
                .font(Type.sans(13))
                .foregroundStyle(Ink.text)
                .underline(true, color: Ink.edge)
                .focusable(false)
        }
        .foregroundStyle(Ink.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 24)
    }

    private var rule: some View {
        Rectangle().fill(Ink.line).frame(height: 1)
    }

    /// "2026-09-09" reads as "9 September 2026". Anything that does not parse is shown as
    /// it was written, so a hand-edited changelog still says something.
    static func day(_ raw: String) -> String {
        let input = DateFormatter()
        input.calendar = Calendar(identifier: .gregorian)
        input.locale = Locale(identifier: "en_US_POSIX")
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: raw) else { return raw }
        let output = DateFormatter()
        output.locale = Locale(identifier: "en_GB")
        output.dateFormat = "d MMMM yyyy"
        return output.string(from: date)
    }
}

/// The way back. A 40 by 40 hit area around a small arrow, so it is reachable without being
/// large, and escape does the same thing.
struct Back: View {
    let action: () -> Void
    @StateObject private var hover = Flag()

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.left")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Ink.text)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(hover.on ? Ink.card : Color.clear))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(hover.on ? Ink.line : Color.clear, lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(Press())
        .focusable(false)
        .keyboardShortcut(.cancelAction)
        .help("Back")
        .onHover { hover.on = $0 }
        .animation(Ink.spring, value: hover.on)
    }
}

/// Press feedback and nothing else: the label shrinks to 0.96 while the mouse is down.
struct Press: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
