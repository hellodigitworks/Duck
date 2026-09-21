# Duck health

Status: GREEN, in sync, clean. Nothing landed but Yard's own health record.
Checked: 2026-09-22 00:22 IST, Yard. Branches, the live pass, shots at both widths opened by eye, gates, chats and the Open checks.

## Live
| Address | Result | Note |
|---|---|---|
| https://duck.hellodigitworks.com/ | 200, 6.9 KB | GREEN |
| https://tuck-2nv.pages.dev/ | 200, 6.9 KB | GREEN |

The live pass flagged this app RED on its first attempt, with five asset checks timing out on DNS resolution. Re-checked every one by hand: the share image, the manifest and all three icons answer 200, the share image at 123,039 bytes. It was this Mac's network, not the site. Screenshots looked at, both widths: the page draws with "A quieter menu bar", the menu-bar illustration and the Install for Mac button, 0 console errors.

## Branches
No branches besides main. Working tree clean.

## Deploy state
**In sync.** 8 ahead of origin, all Yard's own health records. `/appcast.xml` is live and 1.1.0 can be released whenever you want.

## Open issues
None open.

## Reviewed changes
`e699cdd`, Yard's health record from last night. Nothing else.

## Showcases waiting
None.

## Fixed by Yard
Nothing needed. The `zsh scripts/test.sh` gate was not run: nothing under `src/` or `tests/` changed and the gate builds Swift.
