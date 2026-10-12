#!/usr/bin/env bash
# Installs (or removes) the Always-On Bookmarks Bar mod into a Zen profile.
#
#   ./install.sh                     install into the profile Zen opens by default
#   ./install.sh --profile <dir>     install into a specific profile folder
#   ./install.sh --uninstall         remove the mod again
#
# Also works without cloning the repo:
#   curl -fsSL https://raw.githubusercontent.com/TheTrueFerret/zen-always-on-bookmarks-bar/main/install.sh | bash
set -euo pipefail

CSS_URL="https://raw.githubusercontent.com/TheTrueFerret/zen-always-on-bookmarks-bar/main/chrome.css"
CSS_NAME="always-on-bookmarks-bar.css"
IMPORT_LINE="@import url(\"$CSS_NAME\");"
PREF_LINE='user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);'

die() { echo "error: $*" >&2; exit 1; }

uninstall=false
profile=""
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) uninstall=true ;;
    --profile) [ $# -ge 2 ] || die "--profile needs a folder"; profile="$2"; shift ;;
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
  shift
done

# Prints the profile folder Zen opens by default for the given Zen data folder.
# The [Install...] section is what Zen actually uses; `Default=1` on a
# [Profile] section is only the fallback for older setups.
default_profile() {
  local root="$1" ini="$1/profiles.ini" rel
  [ -f "$ini" ] || return 1
  rel=$(awk -F= '/^\[Install/ { inst = 1; next } /^\[/ { inst = 0 }
                 inst && $1 == "Default" { print substr($0, 9); exit }' "$ini")
  if [ -z "$rel" ]; then
    rel=$(awk -F= '/^\[/ { if (def && path != "") { print path; exit } path = ""; def = 0 }
                   $1 == "Path" { path = substr($0, 6) }
                   $1 == "Default" && $2 == "1" { def = 1 }
                   END { if (def && path != "") print path }' "$ini" | head -n 1)
  fi
  [ -n "$rel" ] || return 1
  case "$rel" in
    /*) echo "$rel" ;;
    *) echo "$root/$rel" ;;
  esac
}

if [ -z "$profile" ]; then
  for root in \
    "$HOME/.zen" \
    "$HOME/.config/zen" \
    "$HOME/.var/app/app.zen_browser.zen/.zen" \
    "$HOME/Library/Application Support/zen"; do
    if profile=$(default_profile "$root"); then break; fi
    profile=""
  done
  [ -n "$profile" ] || die "couldn't find a Zen profile; pass one with --profile <dir> (see about:support > Profile Folder)"
fi
[ -d "$profile" ] || die "profile folder does not exist: $profile"

chrome="$profile/chrome"
user_chrome="$chrome/userChrome.css"

if $uninstall; then
  rm -f "$chrome/$CSS_NAME"
  if [ -f "$user_chrome" ]; then
    grep -vxF "$IMPORT_LINE" "$user_chrome" > "$user_chrome.tmp" || true
    mv "$user_chrome.tmp" "$user_chrome"
  fi
  echo "Removed Always-On Bookmarks Bar from: $profile"
  echo "Restart Zen to apply."
  exit 0
fi

mkdir -p "$chrome"

# Use the local copy when run from a clone, otherwise download it.
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)
if [ -n "$script_dir" ] && [ -f "$script_dir/chrome.css" ]; then
  cp "$script_dir/chrome.css" "$chrome/$CSS_NAME"
else
  command -v curl >/dev/null || die "curl is required to download the mod"
  curl -fsSL "$CSS_URL" -o "$chrome/$CSS_NAME"
fi

# @import has to come before any other rule, so prepend it.
if ! grep -qxF "$IMPORT_LINE" "$user_chrome" 2>/dev/null; then
  { echo "$IMPORT_LINE"; cat "$user_chrome" 2>/dev/null || true; } > "$user_chrome.tmp"
  mv "$user_chrome.tmp" "$user_chrome"
fi

# Zen only loads userChrome.css with this pref enabled.
if ! grep -qF 'toolkit.legacyUserProfileCustomizations.stylesheets", true' "$profile/user.js" 2>/dev/null; then
  echo "$PREF_LINE" >> "$profile/user.js"
fi

echo "Installed Always-On Bookmarks Bar into: $profile"
echo "Restart Zen to apply. Make sure the bookmarks toolbar is set to"
echo "'Always Show' (Ctrl+Shift+B, or right-click the top bar > Bookmarks Toolbar)."
