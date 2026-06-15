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

  # 1. copy custom SVGs
  for n in "${CUSTOM[@]}"; do
    cp "$FORK_DIR/src/icons/folders/$n.svg" "$ext/src/icons/folders/$n.svg"
  done

  # 2. insert iconDefinitions into the source theme (idempotent; keeps a pristine .orig)
  theme="$ext/src/symbol-icon-theme.json"
  [ -f "$theme.orig" ] || cp "$theme" "$theme.orig"
  FORK_DIR="$FORK_DIR" THEME="$theme" python3 - "${CUSTOM[@]}" <<'PY'
import os, re, sys
custom = sys.argv[1:]
theme = os.environ["THEME"]
txt = open(theme).read()
missing = [n for n in custom if f'"{n}"' not in txt]
if not missing:
    print("  defs already present")
else:
    block = "".join(f'\t\t"{n}": {{ "iconPath": "./icons/folders/{n}.svg" }},\n' for n in missing)
    txt2 = re.sub(r'("iconDefinitions"\s*:\s*\{\s*\n)', r'\1' + block, txt, count=1)
    assert txt2 != txt, "iconDefinitions anchor not found"
    open(theme, "w").write(txt2)
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
