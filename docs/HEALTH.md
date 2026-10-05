# Duck health
Updated 2026-10-06 by Yard
Status: GREEN, in sync. Duck 1.1.2 and a private stats page arrived on 4 October, deployed the same afternoon.
Checked: 2026-10-06 00:04 IST, Yard. Live pass: no RED from the address check, the accepted AMBERs unchanged. Screenshots opened by eye at both widths as two contact sheets: nothing blank or broken. The Open checks run: 15 pass, 2 fail, both waiting on Swayam, no regressions. No new commits. The two merged agent worktrees and their branch refs were removed tonight.
Previous: 2026-10-05 00:04 IST, Yard.
25 September: tier 2 by Swayam's decision.

## Release
**Duck 1.1.2 is the latest** (`af73383`, 4 October: the mark stays where you put it). The table below is from the 1.1.1 release and was not re-checked tonight. Signed with the Developer ID (Swayam Bhansali, 3NLU2459VW), notarised by Apple and stapled. 1.1.0 went out earlier the same day as the first signed release.

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
No branches besides main. `claude/active-users-devices-dashboard-a31160` (tip `2d4b1b9`) and `claude/icon-position-inconsistency-dd9674` (tip `ce0ee89`) were removed by Yard on 6 October: both fully contained in main, both worktrees clean, and no process had its working folder in either. `git worktree remove`, then `git branch -d`.

## Deploy state
**In sync.** Production deployment `3b080b6f` is at `2d4b1b9`, local main's tip, about 14:45 IST on 4 October. Working tree clean.

## Open issues
- **Exposure font licence.** The app ships `ExposureTrial-30.otf`, the trial. Swayam chose to ship it for now. Buy the licence before Duck gets wider attention.

## Reviewed changes
Seven commits on 4 October.

- `8cfb86d` keep the mark in place across restarts, sleep and monitor changes. **ok**, Swift, not built tonight.
- `af73383` 1.1.2 version and changelog. **ok.**
- `ce0ee89` update feed offers 1.1.2. **ok.**
- `7ddfb8d`, `eed612b` a stats database: each update check is counted as a hash of the address and browser with a salt that is thrown away every day, so yesterday's Macs cannot be traced. **ok.** No address is stored.
- `415123d` the stats page moves off the live site into `admin/stats.html`, reading `/api/stats` with a key. **ok.** The key is compared in constant time, lives only in a Pages secret and a gitignored local file, and is never printed. `site/sw.js` cache bumped.
- `2d4b1b9` the DMG is the only way to get Duck: `install.sh` and the Homebrew cask script removed. **ok.** Old links to `install.sh` now 404, by his choice.

No `console.log`, no secret, no wrong host.

## How a release goes now
`zsh scripts/make-app.sh --release` signs, sends the app and the DMG to Apple, staples both, and writes `build/Duck.dmg` and `build/Duck.zip`. Notarising uses the keychain profile `duck-notary`, made from the same App Store Connect team key FieldCut uses. No Apple ID password is involved.

## Showcases waiting
None.

## Fixed this session
- The live feed pointed at a 1.1.0 zip that was not on GitHub. The release is up now and the feed offers 1.1.1.
- `zsh scripts/test.sh`: all 32 checks passed.
