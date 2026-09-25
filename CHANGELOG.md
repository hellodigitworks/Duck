# Changelog

Every release of Duck, newest first.

## [Unreleased]

## [1.1.0] - 2026-09-25
### Added
- Duck is signed with hdw's Apple Developer ID and notarised by Apple. It opens straight away, with no warning and no trip to Privacy & Security.
- Duck now comes as a disk image. Open it and drag Duck into Applications.
- Duck updates itself. It looks for a newer release once a day, says so only when there is one, and downloads, checks and installs it once you agree. Choose Check for Updates from its menu to look right away.
- Look for updates daily, in Preferences, with Check now under it. Turn the daily look off and Duck only ever looks when you ask.

## [1.0.1] - 2026-09-12
### Fixed
- Duck now honours the chosen auto-hide delay after login. It no longer hides Wi-Fi, battery, and other menu bar controls immediately while macOS is still starting them.
- Duck retries auto-hide for up to 30 seconds when a temporary system control, such as the brightness slider, has the menu bar moving. It closes after the control is finished instead of staying open.

## [1.0.0] - 2026-09-09
### Added
- Duck hides the menu bar icons you are not using right now. Drag an icon to the left of Duck's mark, click the mark, and it is out of sight. Click again and it is back.
- Nothing is removed. The icons are out of view, not gone.
- Five marks to pick from: plus, chevron, dot, line, corner. Each shows one shape while the icons are hidden and another while they are showing.
- Hide again automatically, after a delay you choose.
- Start at login.
- Show in Dock, off by default.
- A Homebrew list of its own: `brew install --cask hellodigitworks/duck/duck`.
- What changed, in the window: the version in the foot opens the notes.
- An update check that says when a newer Duck is out, and never downloads anything by itself.
