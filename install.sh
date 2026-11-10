#!/bin/bash
# Installs Mavis on this Mac:   curl -fsSL https://mouaddotmd.github.io/mavis-releases/install.sh | bash
#
# Downloads the newest Mavis, checks it was signed by Mavis's own certificate (anything else is refused), puts it in
# Applications and opens it. Installed this way, macOS doesn't stop it with "Apple could not verify": that check is
# only for files a browser downloads. Mavis updates itself after that.
set -euo pipefail

feed="https://github.com/Mouaddotmd/mavis-releases/releases/latest/download/update.json"
# Mavis's signing certificate. An app signed by anyone else is never installed.
requirement='identifier "com.m7v.mavis-shell" and certificate leaf = H"f6f79e377ceb0e90acfc4e2f33162bd45598274d"'

say() { printf '%s\n' "$*"; }
fail() { printf 'Mavis wasn'"'"'t installed: %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == Darwin ]] || fail "Mavis is for Mac."
[[ "$(uname -m)" == arm64 ]] || fail "Mavis needs a Mac with Apple silicon (M1 or later)."
major="$(sw_vers -productVersion | cut -d. -f1)"
(( major >= 26 )) || fail "Mavis needs macOS 26 or later. This Mac has $(sw_vers -productVersion)."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

say "Downloading Mavis…"
curl -fsSL -o "$work/update.json" "$feed" || fail "couldn't reach the download. Check your connection and try again."
url="$(plutil -extract url raw -o - "$work/update.json")" || fail "the download information is unreadable."
version="$(plutil -extract version raw -o - "$work/update.json")"
curl -fsSL -o "$work/Mavis.zip" "$url" || fail "the download stopped. Try again."
ditto -x -k "$work/Mavis.zip" "$work/out" || fail "the download is damaged. Try again."
app="$work/out/Mavis.app"
[[ -d "$app" ]] || fail "the download is damaged. Try again."

say "Checking it's the real Mavis…"
codesign --verify --deep --strict -R="$requirement" "$app" 2>/dev/null \
  || fail "this copy isn't signed by Mavis, so it was not installed."

# Into Applications, or your own Applications folder when this account can't write to the shared one.
target="/Applications"
[[ -w "$target" ]] || { target="$HOME/Applications"; mkdir -p "$target"; }

if pgrep -qx Mavis; then
  say "Closing the open Mavis…"
  # A graceful quit, but never let it block the install (it can raise an Automation prompt): give it a moment, then stop it.
  ( osascript -e 'quit app id "com.m7v.mavis-shell"' >/dev/null 2>&1 & osa=$!; sleep 5; kill "$osa" 2>/dev/null ) &
  for _ in {1..24}; do pgrep -qx Mavis || break; sleep 0.25; done
  pgrep -qx Mavis && { pkill -x Mavis 2>/dev/null || true; sleep 1; }
fi
if [[ -e "$target/Mavis.app" ]]; then
  mv "$target/Mavis.app" "$HOME/.Trash/Mavis $(date +%Y-%m-%d\ %H.%M.%S).app" || fail "couldn't replace the Mavis already in $target."
fi
ditto "$app" "$target/Mavis.app" || fail "couldn't copy Mavis into $target."

say "Mavis $version is installed in $target. Opening it…"
open "$target/Mavis.app"
