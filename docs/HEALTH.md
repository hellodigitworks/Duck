# Duck health

Status: AMBER. The app is healthy and the pending deploy is gone: the new mark shipped 22 hours ago and the live site now serves it, with every icon, the manifest and the share image answering at the versions the page asks for. One thing is left and it is not a fault: its tier here is still Code Review's reading, not his.
Checked: 2026-09-08 00:55 IST, daily

## Live
| Address | Result | Note |
|---|---|---|
| https://duck.hellodigitworks.com/ | 200, 7 KB, html | 0 console errors, 0 failed requests, desktop and phone |
| https://duck.hellodigitworks.com/images/og.png?v=5 | 200, 123,039 B, image/png | the new mark, at the version the page asks for |
| https://duck.hellodigitworks.com/images/favicon.svg?v=4 | 200, 3,239 B, image/svg+xml | ok |
| https://duck.hellodigitworks.com/images/favicon-32.png?v=3 | 200, 963 B, image/png | ok |
| https://duck.hellodigitworks.com/images/apple-touch-icon.png?v=3 | 200, 10,181 B, image/png | ok |
| https://duck.hellodigitworks.com/site.webmanifest?v=3 | 200, 516 B, manifest+json | ok |
| https://duck.hellodigitworks.com/css/duck.css?v=3 | 200, 6,100 B, text/css | ok |
| https://duck.hellodigitworks.com/media/install.mp4?v=3 | 200, 2,161,687 B, video/mp4 | the install clip, real video and not the fallback page |
| https://duck.hellodigitworks.com/install.sh | 200, 2,161 B, x-sh | the real script, not the fallback page |
| https://tuck-2nv.pages.dev/ | 200, 7 KB, html | the project address, identical |

## Deploy state

- In sync for everything that publishes. Production is `5a5059b3`, commit `dd98acf`, 22 hours old. Four commits sit on top of it and not one touches `site/`: they are the Swift app, the README and a cask script, none of which the website deploy carries.
- Last commit: 2026-09-07, 8f261d5 The mark carries the line
- Last deploy: 22 hours before this run, commit `dd98acf`, read from `wrangler pages deployment list --project-name tuck`
- Uncommitted: none. Local main is 3 ahead of origin/main
- Deploys by: `npx wrangler pages deploy site --project-name tuck --branch main`

## Open issues
| # | Sev | What | Where | Since | Proposed fix | Decision |
|---|---|---|---|---|---|---|
| 1 | AMBER | The app was not in the registry, so from the day it went live nothing checked it. It was found tonight only because it appeared as a row on lab. Its tier here is Code Review's reading, not a decision he has made | Code Review/apps.json | 2026-09-05 | Added to the registry tonight as tier 1, so it is in the daily from now on. He confirms or changes the tier | needs Swayam |
| 2 | low | Five commits are built and not deployed: a new hand-drawn mark, the app icon made from it, a display typeface swap, and every icon and share image regenerated at `?v=3` and `?v=4`. Live still serves the previous set at `?v=2` | site/, icons/ | 2026-09-06 | A deploy, when he wants it. Never Code Review's to run for a change this size | closed 2026-09-07, not by Code Review: deployed at `dd98acf`, and the live page's own `?v=` versions were fetched one by one and all answer |

## Reviewed changes
- 2026-09-07: nine commits. `8711941` adds a Homebrew cask list, `0a91b98` says when icons are out of reach, `c92c586` moves the five items together, `8f261d5` carries the line through the mark; earlier in the day `fae816b` and `dd98acf` shipped 1.4.1 and 1.4.2, the approved window layout and a Dock tile that follows dark mode, and `9309398`, `f9703c8` and `7556af7` put the install clip on the page at 4K. ok as a set. Four of the nine changed `site/` and were deployed; the last four are Swift, README and the cask script and change nothing the website serves, so the site is not waiting on anything. Open issue 2 closes: the mark, its icons and its share image are live, checked by fetching each one at the exact version the page asks for

- 2026-09-06: five commits, none deployed. `8a47b50` draws the mark by hand and builds the app icon from it. `fa84d56` adds a Show in Dock preference, off by default. `faa4cd7` swaps the display typeface into the window title, the page headline and the pictures. `0c5ccc4` removes the old typeface and its licence file from both the app and the site, and cuts the font builder down to one family. `2783cba` remakes every icon, favicon and share image from the new mark and bumps the page to `?v=3` and `?v=4`, with the service worker bumped alongside. ok as a set: the version stamps and the service worker moved together, the removed font is gone from the CSS as well as the folder, and the page in the folder is consistent with the files in the folder. The live site is consistent with itself at the older version, so nothing is broken while the deploy waits
- 2026-09-06: baseline read of the folder. No secret in a tracked file, no real client or person name, no console.log in the shipping page, every internal href in the page resolves to a file that exists both in the folder and live at the version that page asks for. The download link points at the GitHub release rather than anything hosted here

## Showcases waiting
| Branch | Preview | Shots | What to test | Asked |
|---|---|---|---|---|

## Fixed by Code Review
| Date | What | Commit | Pushed | Deployed | Verified live |
|---|---|---|---|---|---|
