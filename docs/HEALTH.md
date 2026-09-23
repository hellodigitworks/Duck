# Duck health

Status: GREEN, in sync, clean.
Checked: 2026-09-24 00:04 IST, Yard. Nothing changed since 23 September: same live results, same branches, same deploy state, screenshots opened by eye at both widths again. Previous checks follow.
Previous: 2026-09-23 00:04 IST, Yard. Branches, the live pass, shots at both widths opened by eye, the Open checks.

## Live
| Address | Result | Note |
|---|---|---|
| https://duck.hellodigitworks.com/ | 200, 1.3s desktop, 0.9s phone, 0 console errors | GREEN |
| https://tuck-2nv.pages.dev/ | 200 | GREEN |
| /appcast.xml | 200, 1,272 bytes, `cache-control: public, max-age=0, must-revalidate` | GREEN |

Screenshot looked at, both widths: the page draws "A quieter menu bar.", the menu-bar illustration with the red cross on one icon, and Install for Mac. Nothing broken on screen.

## Branches
No branches besides main. Working tree clean.

## Deploy state
**In sync.** The last deployment was two days ago. Nine commits sit ahead of origin, but the live `site/index.html` and `site/appcast.xml` both hash identical to the folder's. The one file that differs is `site/_headers`, which adds an explicit no-stale rule for `/appcast.xml` — and the live server already answers that address with `max-age=0, must-revalidate`, so nothing a person can see is waiting. The update feed is live and current.

## Open issues
None open.

## Reviewed changes
Nothing new since the last run. `7107560` is Yard's own health record from last night.

## Showcases waiting
None.

## Fixed by Yard
Nothing needed. The `zsh scripts/test.sh` gate was not run: nothing under `src/` or `tests/` changed since the last run and that gate builds Swift.
