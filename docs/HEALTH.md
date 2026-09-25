# Duck health

Status: GREEN, in sync, clean.
Checked: 2026-09-25 17:06 IST, with Swayam, after Duck became a signed, notarised app with a DMG. Live pass, deploy state, release files and branches all checked. Previous checks follow.

Previous: 2026-09-25 00:04 IST, Yard. Nothing changed since 24 September.
25 September: tier 2 by Swayam's decision.

## Release
**Duck 1.1.1 is the latest.** Signed with the Developer ID (Swayam Bhansali, 3NLU2459VW), notarised by Apple and stapled. 1.1.0 went out earlier the same day as the first signed release.

| File | Result | Note |
|---|---|---|
| `Duck.dmg` from releases/latest | 200, 3,668,326 bytes, no login needed | Same file Apple accepted. Gatekeeper: "Notarized Developer ID" with a download tag on it |
| `Duck.zip` from releases/latest | 200, 3,389,277 bytes | What Sparkle and Homebrew fetch |
| Homebrew cask | 1.1.1 | No quarantine workaround any more |
| /Applications/Duck.app on this Mac | 1.1.1, running | Gatekeeper accepts it |

The GitHub repository is public, so anyone can download without an account.

## Live
| Address | Result | Note |
|---|---|---|
| https://duck.hellodigitworks.com/ | 200, 0.4s, 0 console errors | GREEN |
| https://tuck-2nv.pages.dev/ | 200 | GREEN |
| /appcast.xml | 200, 1,102 bytes, offers 1.1.1, `cache-control: public, max-age=0, must-revalidate` | GREEN |

Screenshot looked at, desktop and phone: "A quieter menu bar.", the menu-bar illustration, the Download for Mac button, and "macOS 13 or later, Apple silicon. Free." under it. The button links to the DMG. The Terminal one-liner and the install clip are gone from the page. `install.sh` stays live so old links still work.

## Branches
No branches besides main. Working tree clean.

## Deploy state
**In sync.** Every commit is on origin. The live homepage, `appcast.xml`, `sw.js` and `duck.css` hash identical to the folder's.

## Open issues
- **Exposure font licence.** The app ships `ExposureTrial-30.otf`, the trial. Swayam chose to ship it for now. Buy the licence before Duck gets wider attention.

## Reviewed changes
- `aa6e594` Developer ID signing, hardened runtime, notarising in `make-app.sh --release`, the designed DMG (`make-dmg.sh`, `make-dmg-background.swift`), the DMG download on the page.
- `c5d8e20` The update feed pointed at the notarised 1.1.0 zip.
- `34b6352` Duck 1.1.1: an Icon Composer icon compiled into Assets.car, so macOS 26 and later draw a cream tile in light mode and an ink tile in dark. Before, macOS darkened the old icon itself and the duck disappeared. The install clip was removed from the site.

## How a release goes now
`zsh scripts/make-app.sh --release` signs, sends the app and the DMG to Apple, staples both, and writes `build/Duck.dmg` and `build/Duck.zip`. Notarising uses the keychain profile `duck-notary`, made from the same App Store Connect team key FieldCut uses. No Apple ID password is involved.

## Showcases waiting
None.

## Fixed this session
- The live feed pointed at a 1.1.0 zip that was not on GitHub. The release is up now and the feed offers 1.1.1.
- `zsh scripts/test.sh`: all 32 checks passed.
