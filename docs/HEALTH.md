# Duck health

Status: GREEN, in sync, clean.
Checked: 2026-09-26 12:17 IST, Yard. A daytime run: the Mac slept for about fifty minutes partway through, so the screenshots were taken again once the network was back. Live pass, shots at both widths opened by eye, the Open checks, four new commits reviewed. `zsh scripts/test.sh`: all 32 checks pass. Live `appcast.xml` hashes identical to the folder, production deployment is `34b6352`.
Previous: 2026-09-25 17:06 IST, with Swayam.
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
Four commits since the last run, all made with Swayam on 25 September.

- `aa6e594` signed with Developer ID, notarised, a designed DMG. **ok.** `site/sw.js` cache bumped to `duck-v7`.
- `c5d8e20` the update feed points at the notarised 1.1.0 zip. **ok.**
- `34b6352` 1.1.1, an icon macOS 26 draws in dark mode, and the unused install clip is gone from the site. **ok.** Answers his report of 25 September, now the `duck` check in `checks.md`, passing.
- `c51a801` health record. **ok.**

No secret-looking string. Notarising uses a keychain profile, no password in the repo.

## How a release goes now
`zsh scripts/make-app.sh --release` signs, sends the app and the DMG to Apple, staples both, and writes `build/Duck.dmg` and `build/Duck.zip`. Notarising uses the keychain profile `duck-notary`, made from the same App Store Connect team key FieldCut uses. No Apple ID password is involved.

## Showcases waiting
None.

## Fixed this session
- The live feed pointed at a 1.1.0 zip that was not on GitHub. The release is up now and the feed offers 1.1.1.
- `zsh scripts/test.sh`: all 32 checks passed.
