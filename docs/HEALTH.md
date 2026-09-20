# Duck health

Status: GREEN. The update feed is live. `/appcast.xml` answers 200 `application/xml`, 1,272 bytes, so the seven-night standing item is closed and 1.1.0 can be released whenever Swayam wants. Download page draws at both widths, 0 console errors.
Checked: 2026-09-21 00:22 IST, Yard. Ran on time and inside the budget: branches, live pass, shots at both widths opened by eye, chats and Open checks.

## Live
| Address | Result | Note |
|---|---|---|
| https://duck.hellodigitworks.com/ | 200, GREEN, no flags | 0 console errors, 0 failed requests, desktop and phone. "A quieter menu bar." page renders with the menu bar illustration and the "Install for Mac" button |

## Branches
None besides main. The working tree is clean.

## Deploy state
- **In sync.** `site/` last changed in `2363360` (Duck 1.1.0) and that work is live, proved by `/appcast.xml` answering 200 `application/xml` tonight.
- The folder is seven commits ahead of origin, every one of them a Yard health record, never pushed by design.
- Deploys by: `npx wrangler pages deploy site --project-name tuck --branch main`

## Open issues
| # | Sev | What | Where | Since | Proposed fix | Decision |
|---|---|---|---|---|---|---|
| 1 | AMBER | The app was not in the registry, so from the day it went live nothing checked it. It was found tonight only because it appeared as a row on lab. Its tier here is Code Review's reading, not a decision he has made | Yard/apps.json | 2026-09-05 | Added to the registry as tier 1, so it is in the nightly run from now on. He confirms or changes the tier | needs Swayam |
| 2 | low | Five commits are built and not deployed: a new hand-drawn mark, the app icon made from it, a display typeface swap, and every icon and share image regenerated at `?v=3` and `?v=4`. Live still serves the previous set at `?v=2` | site/, icons/ | 2026-09-06 | A deploy, when he wants it | closed 2026-09-07, not by Code Review: deployed at `dd98acf`, and the live page's own `?v=` versions were fetched one by one and all answer |

Not a new finding, just kept on record: the registry still lists Duck at tier 1 on the worker's own reading, not a decision he made, and the Cloudflare Pages project is still called `tuck` from the app's earlier name while the domain is `duck`. Neither should be renamed without him.

## Reviewed changes
- 2026-09-21: no code commits since the last run. The standing finding is closed: `https://duck.hellodigitworks.com/appcast.xml` now answers 200 `application/xml` with 1,272 bytes, where for seven nights it answered 200 `text/html` with the home page. Somebody deployed `site/` since the last run. The gate `zsh scripts/test.sh` was not run, because nothing under `src/` or `tests/` changed and the gate builds Swift, which is slow. Live re-checked: both addresses 200, 0 console errors and 0 failed requests at both widths.
- 2026-09-13: three commits. `e45d317` fixes auto-hide timing after launch, with a test. ok. `2363360` "Duck 1.1.0: it brings its own next version" replaces the home-made update check with a feed at `https://duck.hellodigitworks.com/appcast.xml` (set in `scripts/make-app.sh:93`), adds the feed under `site/` with a no-cache rule, and removes `src/data/UpdateCheck.swift` with its tests. **Concern:** the feed must be live before 1.1.0 is released, or every 1.1.0 install checks for updates against an HTML page. `5fb020b` puts a switch on the daily look in Preferences. ok. No secret, no real name. homebrew-duck gained `0b31db4`, the cask moved to 1.0.1 with its checksum. ok
- 2026-09-11: three commits. `8e410aa` "The line stands out past the icons": changes `src/app/Seating.swift`, `src/app/StatusBarController.swift`, `src/ui/Mark.swift`, `src/ui/PreferencesView.swift` and the README. ok. `6b6c06d` "Duck 1.5.0: the version in the foot opens what changed": adds `src/data/ReleaseNotes.swift`, `src/ui/ReleaseNotesPanel.swift`, `src/data/Preferences.swift`, a new `VERSION` file and 44 lines of new tests. ok, and the new behaviour is covered by tests. `be758c7` "Duck 1.0.0: the number starts where the launch does": takes `VERSION` from 1.5.0 down to 1.0.0 and trims the changelog to one entry. The version number going down is deliberate and the commit message says why. ok. Worth keeping on record: `tests/DuckChecks.swift` still uses 1.5.0 and 1.5.1 as its example strings, which is correct, because those tests check the comparison logic and not the shipped number. No secret, no real name and no stray print statement in any of the three

- 2026-09-07: nine commits. `8711941` adds a Homebrew cask list, `0a91b98` says when icons are out of reach, `c92c586` moves the five items together, `8f261d5` carries the line through the mark; earlier in the day `fae816b` and `dd98acf` shipped 1.4.1 and 1.4.2, the approved window layout and a Dock tile that follows dark mode, and `9309398`, `f9703c8` and `7556af7` put the install clip on the page at 4K. ok as a set. Four of the nine changed `site/` and were deployed; the last four are Swift, README and the cask script and change nothing the website serves, so the site is not waiting on anything. Open issue 2 closes: the mark, its icons and its share image are live, checked by fetching each one at the exact version the page asks for

- 2026-09-06: five commits, none deployed. `8a47b50` draws the mark by hand and builds the app icon from it. `fa84d56` adds a Show in Dock preference, off by default. `faa4cd7` swaps the display typeface into the window title, the page headline and the pictures. `0c5ccc4` removes the old typeface and its licence file from both the app and the site, and cuts the font builder down to one family. `2783cba` remakes every icon, favicon and share image from the new mark and bumps the page to `?v=3` and `?v=4`, with the service worker bumped alongside. ok as a set: the version stamps and the service worker moved together, the removed font is gone from the CSS as well as the folder, and the page in the folder is consistent with the files in the folder. The live site is consistent with itself at the older version, so nothing is broken while the deploy waits
- 2026-09-06: baseline read of the folder. No secret in a tracked file, no real client or person name, no console.log in the shipping page, every internal href in the page resolves to a file that exists both in the folder and live at the version that page asks for. The download link points at the GitHub release rather than anything hosted here

## Showcases waiting
| Branch | Preview | Shots | What to test | Asked |
|---|---|---|---|---|

## Fixed by Yard
| Date | What | Commit | Pushed | Deployed | Verified live |
|---|---|---|---|---|---|

Nothing tonight.
