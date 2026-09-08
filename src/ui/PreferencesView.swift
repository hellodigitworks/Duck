import SwiftUI
import DuckCore

/// The look: cream paper, ink text. Exposure for the name, Inter for the rest. Rows a
/// hairline apart, chips with soft corners, a spring on everything that moves.
enum Ink {
    static let paper = Color(red: 0.957, green: 0.937, blue: 0.902)
    static let card = Color(red: 0.984, green: 0.973, blue: 0.953)
    static let text = Color(red: 0.078, green: 0.071, blue: 0.059)
    static let muted = Color(red: 0.435, green: 0.404, blue: 0.361)
    static let line = Color(red: 0.902, green: 0.875, blue: 0.827)
    static let edge = Color(red: 0.812, green: 0.776, blue: 0.722)
    static let accent = Color(red: 1, green: 0.18, blue: 0)
    static let shadow = Color(red: 0.25, green: 0.18, blue: 0.08).opacity(0.07)
    static let spring = Animation.spring(response: 0.32, dampingFraction: 0.72)
}

/// The two faces. Both ship inside the app; if one is missing the system font steps in.
enum Type {
    static func serif(_ size: CGFloat) -> Font { .custom("ExposureTrial--30", size: size) }
    static func sans(_ size: CGFloat) -> Font { .custom("Inter-Regular", size: size) }
    static func medium(_ size: CGFloat) -> Font { .custom("Inter-Medium", size: size) }
}

struct PreferencesView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var login: LoginItemModel
    @ObservedObject var updates: UpdateCheck

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 0) {
            // The rows. Each one a hairline apart, the way a ledger is set.
            VStack(spacing: 0) {
                row("Start at login") { Toggle(isOn: launchBinding) { EmptyView() } }
                if let message = login.message {
                    note(message)
                }
                rule
                row("Show in Dock") { Toggle(isOn: $preferences.showInDock) { EmptyView() } }
                rule
                row("Hide again automatically") { Toggle(isOn: $preferences.autoHide) { EmptyView() } }
                rule
                stack("After") {
                    HStack(spacing: 6) {
                        ForEach(Preferences.autoHideChoices, id: \.self) { seconds in
                            Chip(label(for: seconds), selected: preferences.autoHideSeconds == seconds) {
                                withAnimation(Ink.spring) { preferences.autoHideSeconds = seconds }
                            }
                        }
                    }
                    .opacity(preferences.autoHide ? 1 : 0.35)
                    .disabled(!preferences.autoHide)
                    .animation(Ink.spring, value: preferences.autoHide)
                }
                rule
                stack("Mark") {
                    HStack(spacing: 6) {
                        ForEach(MarkStyle.allCases, id: \.self) { style in
                            MarkChip(style: style, selected: preferences.markStyle == style) {
                                withAnimation(Ink.spring) { preferences.markStyle = style }
                            }
                        }
                    }
                }
            }
            .toggleStyle(Check())
            .padding(.horizontal, 22)
            .padding(.top, 34)

            Spacer(minLength: 14)

            // The foot: the duck, its name (the way to the site), its version. Quit.
            rule
            HStack(spacing: 9) {
                if let duck = Self.duck {
                    Image(nsImage: duck)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 22)
                }
                Link("Duck", destination: URL(string: "https://duck.hellodigitworks.com")!)
                    .font(Type.serif(17))
                    .foregroundStyle(Ink.text)
                    .underline(true, color: Ink.edge)
                    .focusable(false)
                Text(version)
                    .font(Type.sans(12))
                    .foregroundStyle(Ink.muted)
                    .monospacedDigit()
                if let newer = updates.newer {
                    Link("\(newer.version) is out", destination: newer.url)
                        .font(Type.medium(12))
                        .foregroundStyle(Ink.text)
                        .underline()
                        .focusable(false)
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(Type.medium(12.5))
                    .foregroundStyle(Ink.text)
                    .focusable(false)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
        }
        .font(Type.sans(13))
        .foregroundStyle(Ink.text)
        .tint(Ink.text)
        .frame(minWidth: 360, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity, alignment: .top)
        .background(Ink.paper)
        .onAppear { login.refresh() }
    }

    /// The duck, from the bundle. Drawn by the same file the icon comes from.
    private static let duck: NSImage? = {
        guard let url = Bundle.main.url(forResource: "duck", withExtension: "svg") else { return nil }
        return NSImage(contentsOf: url)
    }()

    private var rule: some View {
        Rectangle().fill(Ink.line).frame(height: 1)
    }

    /// A label on the left, its control on the right.
    private func row<Control: View>(_ label: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            Text(label)
            Spacer(minLength: 0)
            control()
        }
        .padding(.vertical, 12)
    }

    /// A label, then its chips beneath it.
    private func stack<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(label)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private var launchBinding: Binding<Bool> {
        Binding(
            get: { login.isEnabled },
            set: { wanted in login.set(wanted) })
    }

    private func label(for seconds: Double) -> String {
        seconds >= 60 ? "1 min" : "\(Int(seconds)) s"
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(Type.sans(12))
            .foregroundStyle(Ink.muted)
            .padding(.bottom, 10)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A chip for one look of the mark: its hidden shape, then its showing shape. Ink-filled
/// when it is the one in use.
struct MarkChip: View {
    let style: MarkStyle
    let selected: Bool
    let action: () -> Void
    @StateObject private var hover = Flag()
    private var hovering: Bool { hover.on }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                glyph(0)
                glyph(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? Ink.text : Ink.card))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? Ink.text : (hovering ? Ink.text : Ink.line), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(hovering && !selected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .help(style.name)
        .onHover { hover.on = $0 }
        .animation(Ink.spring, value: selected)
        .animation(Ink.spring, value: hovering)
    }

    private func glyph(_ fraction: CGFloat) -> some View {
        Image(nsImage: Mark.image(style: style, fraction: fraction))
            .renderingMode(.template)
            .resizable()
            .frame(width: 14, height: 14)
            .foregroundStyle(selected ? Ink.paper : Ink.text)
    }
}

// MARK: - Surfaces and controls

/// A checkbox: an outlined square that fills with ink when it is on.
struct Check: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(Ink.spring) { configuration.isOn.toggle() }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(configuration.isOn ? Ink.text : Color.clear)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(configuration.isOn ? Ink.text : Ink.edge, lineWidth: 1)
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Ink.paper)
                        .opacity(configuration.isOn ? 1 : 0)
                        .scaleEffect(configuration.isOn ? 1 : 0.4)
                }
                .frame(width: 20, height: 20)
                configuration.label
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focusable(false)
    }
}

/// A chip with the window's 12 point corners. Ink-filled when it is the one picked.
struct Chip: View {
    let title: String
    let selected: Bool
    let action: () -> Void
    @StateObject private var hover = Flag()
    private var hovering: Bool { hover.on }

    init(_ title: String, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.selected = selected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Type.medium(12))
                .monospacedDigit()
                .foregroundStyle(selected ? Ink.paper : Ink.text)
                .padding(.horizontal, 13)
                .padding(.vertical, 7)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(selected ? Ink.text : Ink.card))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(selected ? Ink.text : (hovering ? Ink.text : Ink.line), lineWidth: 1))
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .scaleEffect(hovering && !selected ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .onHover { hover.on = $0 }
        .animation(Ink.spring, value: selected)
        .animation(Ink.spring, value: hovering)
    }
}

/// An outlined button that fills with ink while pressed.
struct Outline: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        Label(configuration: configuration)
    }

    private struct Label: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled
        @StateObject private var hover = Flag()
        private var hovering: Bool { hover.on }

        var body: some View {
            configuration.label
                .font(Type.medium(13))
                .foregroundStyle(configuration.isPressed ? Ink.paper : Ink.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(configuration.isPressed ? Ink.text : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(hovering || configuration.isPressed ? Ink.text : Ink.edge, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .opacity(isEnabled ? 1 : 0.35)
                .onHover { hover.on = $0 }
                .animation(Ink.spring, value: hovering)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}

/// One published bool. Views keep small state in these because the command line tools
/// ship SwiftUI without the plugin that `@State` needs; `@StateObject` works everywhere.
final class Flag: ObservableObject {
    @Published var on = false
}

/// Mirrors the system's start-at-login switch so the checkbox can show the real state.
final class LoginItemModel: ObservableObject {
    @Published var isEnabled = LoginItem.isEnabled
    @Published var message: String?

    func refresh() {
        isEnabled = LoginItem.isEnabled
    }

    func set(_ wanted: Bool) {
        message = LoginItem.setEnabled(wanted)
        isEnabled = LoginItem.isEnabled
        if wanted, message == nil, LoginItem.needsApproval {
            message = "Approve Duck in System Settings → General → Login Items & Extensions."
        }
    }
}
