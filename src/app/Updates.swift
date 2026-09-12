import AppKit
import Sparkle

/// Sparkle behind one small door, so nothing else in Duck has to know it is there. It owns
/// the signed download, the install and the relaunch, and has to stay alive for as long as
/// Duck runs: an updater that goes out of scope stops mid-download.
final class Updates: ObservableObject {
    static let shared = Updates()

    private let controller: SPUStandardUpdaterController

    /// The daily look, as a switch the window can read. Sparkle keeps the real answer, so
    /// this mirrors it rather than saving a second copy that could drift out of step.
    @Published private(set) var looksDaily: Bool

    private init() {
        controller = SPUStandardUpdaterController(startingUpdater: true,
                                                  updaterDelegate: nil,
                                                  userDriverDelegate: nil)
        looksDaily = controller.updater.automaticallyChecksForUpdates
    }

    /// Reads the answer back out of Sparkle rather than trusting the request, so the switch
    /// shows what is true even if Sparkle declines.
    func setLooksDaily(_ wanted: Bool) {
        controller.updater.automaticallyChecksForUpdates = wanted
        looksDaily = controller.updater.automaticallyChecksForUpdates
    }

    /// Looks now and says so either way, unlike the daily look, which stays quiet unless
    /// there is something to report. Duck has no Dock icon, so Sparkle's window would open
    /// behind whatever is in front: coming forward first puts it where the click was.
    func checkNow() {
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
}
