#!/bin/zsh
# Signs a Duck.zip release and writes the public update feed Sparkle reads.
# Run after uploading build/Duck.zip to GitHub, then deploy site/ to Cloudflare Pages.
set -e
cd "$(dirname "$0")/.."

ARCHIVE="${1:-build/Duck.zip}"
[ -f "$ARCHIVE" ] || { echo "Missing update archive: $ARCHIVE" >&2; exit 1; }

VERSION="$(tr -d ' \n' < VERSION)"
SIGN="$HOME/Library/Caches/duck-build/artifacts/sparkle/Sparkle/bin/sign_update"
[ -x "$SIGN" ] || { echo "Build Duck once first: zsh scripts/make-app.sh --release" >&2; exit 1; }

SIGNATURE="$($SIGN "$ARCHIVE" | sed -n 's/.*edSignature="\([^"]*\)".*/\1/p')"
[ -n "$SIGNATURE" ] || { echo "Could not sign $ARCHIVE" >&2; exit 1; }
LENGTH="$(stat -f%z "$ARCHIVE")"
URL="https://github.com/hellodigitworks/Duck/releases/download/v$VERSION/Duck.zip"
DATE="$(LC_ALL=C date -u '+%a, %d %b %Y %H:%M:%S +0000')"

# The notes Sparkle shows in its own window, lifted from this version's CHANGELOG entry so
# the feed and the What's new panel can never disagree. The ### headings are scaffolding for
# the file, not for a person reading an update, so only the bullets travel.
NOTES="$(awk -v v="## [$VERSION]" '
  index($0, v) == 1 { on = 1; next }
  on && /^## \[/ { exit }
  on && /^- / { sub(/^- /, ""); print "      <li>" $0 "</li>" }
' CHANGELOG.md)"
[ -n "$NOTES" ] || { echo "No CHANGELOG.md entry for $VERSION" >&2; exit 1; }

# sparkle:version is compared against the installed copy's CFBundleVersion, which
# make-app.sh writes from the same VERSION file. Both sides stay one string.
mkdir -p site
cat > site/appcast.xml <<FEED
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Duck updates</title>
    <item>
      <title>Duck $VERSION</title>
      <pubDate>$DATE</pubDate>
      <sparkle:version>$VERSION</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>13.0</sparkle:minimumSystemVersion>
      <description><![CDATA[
    <ul>
$NOTES
    </ul>
      ]]></description>
      <enclosure url="$URL" length="$LENGTH" type="application/octet-stream" sparkle:edSignature="$SIGNATURE" />
    </item>
  </channel>
</rss>
FEED
print "Wrote site/appcast.xml for Duck $VERSION"
