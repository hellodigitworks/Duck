#!/usr/bin/env python3
"""Writes the Homebrew cask for Duck, from whatever the latest release is.

Homebrew is the app store Mac developers already have, and it runs in Terminal.
Its official list only takes apps with 75 GitHub stars, which Duck does not have,
so Duck keeps its own small list, called a tap. A tap is just a GitHub repository
named homebrew-<something> with a Casks folder in it. Ours is:

    github.com/hellodigitworks/homebrew-duck   ->   ../homebrew-duck

and it installs with:

    brew install --cask hellodigitworks/duck/duck

This script reads the newest release through the GitHub CLI, downloads the zip to
check it, and writes ../homebrew-duck/Casks/duck.rb with that version and that
checksum. Run it after every release:

    python3 scripts/make-cask.py

Nothing here publishes. Commit and push the tap yourself.
"""
import hashlib
import json
import pathlib
import subprocess
import sys
import tempfile
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parent.parent
TAP = ROOT.parent / "homebrew-duck"
CASK = TAP / "Casks" / "duck.rb"
REPO = "hellodigitworks/Duck"


def latest():
    """The newest release: its tag, its version, and the URL of its zip."""
    out = subprocess.run(
        ["gh", "release", "view", "--repo", REPO, "--json", "tagName,assets"],
        capture_output=True, text=True, check=True,
    ).stdout
    data = json.loads(out)
    tag = data["tagName"]
    for asset in data["assets"]:
        if asset["name"] == "Duck.zip":
            return tag, tag.lstrip("v"), asset["url"]
    sys.exit("The latest release has no Duck.zip on it.")


def checksum(url):
    """Homebrew refuses to install a file whose checksum has changed, so the cask
    carries the one this script saw. Downloading it here is also the only way to
    know the release is really there."""
    with tempfile.TemporaryDirectory() as tmp:
        dest = pathlib.Path(tmp) / "Duck.zip"
        urllib.request.urlretrieve(url, dest)
        return hashlib.sha256(dest.read_bytes()).hexdigest(), dest.stat().st_size


def main():
    if not TAP.is_dir():
        sys.exit(f"The tap is not beside the app: expected {TAP}")
    tag, version, url = latest()
    sha, size = checksum(url)

    CASK.parent.mkdir(parents=True, exist_ok=True)
    CASK.write_text(f'''# Duck, for Homebrew. Written by scripts/make-cask.py in the Duck repo.
# Do not edit by hand: make a release, then run that script again.
cask "duck" do
  version "{version}"
  sha256 "{sha}"

  url "https://github.com/{REPO}/releases/download/v#{{version}}/Duck.zip"
  name "Duck"
  desc "Hides the menu bar icons you are not using right now"
  homepage "https://duck.hellodigitworks.com/"

  depends_on macos: :ventura
  depends_on arch: :arm64

  app "Duck.app"

  # Duck is free and open source, and is not signed with an Apple developer
  # certificate, which costs 99 dollars a year. macOS tags anything Homebrew
  # downloads and then refuses to open what it cannot verify, so the tag comes
  # off here and the caveats below say so. The one-line installer on the site
  # never picks the tag up in the first place: macOS only tags what a browser
  # saved, and curl is not a browser.
  postflight_steps do
    run "/usr/bin/xattr",
        args:  ["-dr", "com.apple.quarantine", "Duck.app"],
        chdir: "."
  end

  uninstall quit: "com.hdw.duck"

  zap trash: [
    "~/Library/Preferences/com.hdw.duck.plist",
    "~/Library/Caches/com.hdw.duck",
  ]

  caveats <<~EOS
    Duck is not signed with an Apple developer certificate, so this cask
    removes the quarantine tag macOS puts on downloads. Read the app's source
    at https://github.com/{REPO} before you trust it, the same as any
    unsigned app.
  EOS
end
''')
    print(f"  {CASK.relative_to(TAP.parent)}")
    print(f"  version {version}  ({tag})  {size:,} bytes")
    print(f"  sha256  {sha}")
    print("\nTest it locally, without publishing anything:")
    print(f"  brew tap hellodigitworks/duck {TAP}")
    print("  brew install --cask hellodigitworks/duck/duck")


if __name__ == "__main__":
    main()
