import Foundation

/// The timing rules for Duck hiding after launch or after a temporary menu bar change.
/// Kept outside AppKit so they can be checked without changing the real menu bar.
public enum AutoHideSchedule {
    public static let retryDelay: TimeInterval = 0.5
    public static let maximumRetries = 60

    /// A used copy of Duck honours the person's auto-hide setting at login. A new copy
    /// stays open until its first deliberate hide, so its controls are discoverable.
    public static func shouldScheduleAfterLaunch(hasHiddenBefore: Bool, autoHideEnabled: Bool) -> Bool {
        hasHiddenBefore && autoHideEnabled
    }

    /// A slider or another system popover can make the menu bar momentarily unreadable.
    /// Retrying for 30 seconds lets Duck hide after that interaction ends without looping
    /// forever if macOS never gives it a usable layout.
    public static func shouldRetry(after attempt: Int) -> Bool {
        attempt < maximumRetries
    }
}
