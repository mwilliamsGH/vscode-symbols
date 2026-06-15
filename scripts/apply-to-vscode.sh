#!/usr/bin/env bash
# Apply this fork's custom tier icons into the live, marketplace-installed
# Symbols extension (miguelsolorio.symbols).
#
# Why a patch script (not a replace): the marketplace extension is the one
# VS Code actually loads. A Symbols update installs a fresh versioned folder
# and wipes anything we added — so we re-run this afterward. Same model as
# SlashMD's scripts/slashmd-font.sh.
#
# What it does (idempotent, version-agnostic):
#   1. copies our custom SVGs into the install's icons/folders/
#   2. inserts our iconDefinitions into the install's source theme (if missing)
#   3. clears the generated theme files so the extension regenerates from source
#
# Usage:  scripts/apply-to-vscode.sh
# Then: Cmd+Shift+P -> "Reload Window" (the extension may also prompt you).
set -euo pipefail

FORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CUSTOM=(folder-brain folder-systems folder-agents folder-lab folder-notes folder-archives)

found=0
for ext in "$HOME"/.vscode/extensions/miguelsolorio.symbols-*; do
  [ -d "$ext" ] || continue
  found=1
  echo "applying to: $ext"

  # layout guard — if a future Symbols release moves these, skip loudly instead
  # of corrupting something or failing cryptically mid-copy.
  if [ ! -d "$ext/src/icons/folders" ] || [ ! -f "$ext/src/symbol-icon-theme.json" ]; then
    echo "  !! unexpected extension layout (icons/folders or theme json missing) — skipping" >&2
    continue
  fi

  # 1. copy custom SVGs (each must exist in the fork)
  for n in "${CUSTOM[@]}"; do
    svg="$FORK_DIR/src/icons/folders/$n.svg"
    [ -f "$svg" ] || { echo "  !! fork SVG missing: $svg" >&2; exit 1; }
    cp "$svg" "$ext/src/icons/folders/$n.svg"
  done

  # 2. insert iconDefinitions into the source theme (idempotent; keeps a pristine .orig).
  #    Parse-and-write (not text/regex) so it's robust to upstream reformatting,
  #    write to a temp file, re-validate, then swap in — original is never left
  #    half-written, and the .orig backup remains for manual restore.
  theme="$ext/src/symbol-icon-theme.json"
  [ -f "$theme.orig" ] || cp "$theme" "$theme.orig"
  THEME="$theme" python3 - "${CUSTOM[@]}" <<'PY'
import os, json, sys, shutil
custom = sys.argv[1:]
theme = os.environ["THEME"]
try:
    data = json.load(open(theme))
except Exception as e:
    sys.exit(f"  !! theme is not valid JSON ({e}); aborting, nothing changed")
defs = data.setdefault("iconDefinitions", {})
missing = [n for n in custom if n not in defs]
if not missing:
    print("  defs already present")
else:
    for n in missing:
        defs[n] = {"iconPath": f"./icons/folders/{n}.svg"}
    tmp = theme + ".tmp"
    json.dump(data, open(tmp, "w"), indent=2)
    try:
        json.load(open(tmp))                      # re-validate before swapping in
    except Exception as e:
        os.remove(tmp); sys.exit(f"  !! patched theme failed validation ({e}); original untouched")
    shutil.move(tmp, theme)
    print("  inserted:", ", ".join(missing))
PY

  # 3. clear the generated theme files. The extension regenerates them from the
  #    patched source AND re-injects your per-workspace folder associations from
  #    settings on its next activate — do NOT pre-write them here, or the version
  #    without associations sticks until a reload and the icons look "missing".
  rm -f "$ext/src/symbol-icon-theme.modified.json" "$ext/src/symbol-icon-theme.bkp.json"
done

[ "$found" = 1 ] || { echo "No Symbols install found under ~/.vscode/extensions/"; exit 1; }
echo "Done. RELOAD the VS Code window (Cmd+Shift+P -> Reload Window) — required for"
echo "the extension to wire the icons to your folder associations."
