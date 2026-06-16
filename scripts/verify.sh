#!/usr/bin/env bash
# Health-check the live Symbols install against this fork's custom tier icons.
# Run anytime icons look off, or after a Symbols update + apply, to confirm the
# patch is intact and wired.
#
# Usage:
#   scripts/verify.sh                         # check the install (svgs, defs, files)
#   scripts/verify.sh path/to/.vscode/settings.json   # also check that every
#                                             # symbols.folders.associations value
#                                             # resolves to a real icon definition
#
# Exit code 0 = healthy, 1 = problems found (each printed with a fix hint).
set -uo pipefail

FORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SETTINGS="${1:-}"

FORK_DIR="$FORK_DIR" SETTINGS="$SETTINGS" python3 <<'PY'
import os, glob, json, sys
import xml.dom.minidom as MD

fork = os.environ["FORK_DIR"]; settings = os.environ.get("SETTINGS", "")
CUSTOM = ["folder-brain","folder-systems","folder-agents","folder-lab","folder-notes","folder-archives"]
fails = []

home = os.path.expanduser("~")
exts = sorted(glob.glob(f"{home}/.vscode/extensions/miguelsolorio.symbols-*"),
              key=os.path.getmtime, reverse=True)
if not exts:
    print("✗ no Symbols install found under ~/.vscode/extensions/")
    print("  fix: install the Symbols extension, then run scripts/apply-to-vscode.sh")
    sys.exit(1)
ext = exts[0]
print(f"checking: {ext}")
if len(exts) > 1:
    print(f"note: {len(exts)} Symbols versions installed; checking the newest. "
          "stale ones are harmless but you can remove them.")

def strip_jsonc(s):
    out = []; i = 0; n = len(s); instr = False; esc = False
    while i < n:
        c = s[i]
        if instr:
            out.append(c)
            if esc: esc = False
            elif c == "\\": esc = True
            elif c == '"': instr = False
            i += 1; continue
        if c == '"': instr = True; out.append(c); i += 1; continue
        if c == "/" and i+1 < n and s[i+1] == "/":
            i += 2
            while i < n and s[i] != "\n": i += 1
            continue
        if c == "/" and i+1 < n and s[i+1] == "*":
            i += 2
            while i+1 < n and not (s[i] == "*" and s[i+1] == "/"): i += 1
            i += 2; continue
        out.append(c); i += 1
    return "".join(out)

# theme validity
src = f"{ext}/src/symbol-icon-theme.json"
theme = None
try:
    theme = json.load(open(src))
    print("✓ source theme is valid JSON")
except Exception as e:
    fails.append(("source theme invalid JSON: %s" % e,
                  "re-run scripts/apply-to-vscode.sh; if it persists, reinstall Symbols"))

defs = theme.get("iconDefinitions", {}) if theme else {}

# custom svgs present + valid + defs + def->file
for n in CUSTOM:
    svg = f"{ext}/src/icons/folders/{n}.svg"
    if not os.path.exists(svg):
        fails.append((f"{n}.svg missing from install", "run scripts/apply-to-vscode.sh + reload")); continue
    try: MD.parse(svg)
    except Exception as e: fails.append((f"{n}.svg invalid XML: {e}", "fix the SVG in the fork, re-apply"))
    if n not in defs:
        fails.append((f"{n} not registered in iconDefinitions", "run scripts/apply-to-vscode.sh + reload"))
    else:
        ip = defs[n].get("iconPath","")
        fp = os.path.normpath(os.path.join(ext, "src", ip.lstrip("./")))
        if not os.path.exists(fp):
            fails.append((f"{n} -> {ip} points at a missing file", "run scripts/apply-to-vscode.sh"))

# duplicate-def smell
raw = open(src).read() if theme else ""
for n in CUSTOM:
    if raw.count(f'"{n}":') > 1:
        fails.append((f"{n} defined {raw.count(chr(34)+n+chr(34)+':')}x (duplicate)",
                      "restore symbol-icon-theme.json.orig, then re-apply"))

# generated theme (if present) must be valid
mod = f"{ext}/src/symbol-icon-theme.modified.json"
if os.path.exists(mod):
    try: json.load(open(mod)); print("✓ generated theme (modified.json) is valid JSON")
    except Exception as e: fails.append((f"modified.json invalid: {e}", "delete it + reload to regenerate"))
else:
    print("note: modified.json absent — the extension regenerates it on next reload (expected right after apply)")

# optional: association -> def resolution
if settings:
    if not os.path.exists(settings):
        fails.append((f"settings file not found: {settings}", "pass a correct path"))
    else:
        try:
            cfg = json.loads(strip_jsonc(open(settings).read()))
            assoc = cfg.get("symbols.folders.associations", {})
            fnames = theme.get("folderNames", {}) if theme else {}
            print(f"✓ settings parsed; checking {len(assoc)} folder associations")
            for folder, icon in assoc.items():
                if icon not in defs:
                    fails.append((f"association {folder} -> {icon} has no matching icon definition",
                                  "fix the icon name in settings, or add/register the icon"))
                elif fnames.get(folder) != icon:
                    # the bug that breaks on a color-theme / settings change: declared
                    # in settings but not baked into the theme, so a regen drops it.
                    fails.append((f"{folder} -> {icon} is NOT baked into theme folderNames "
                                  "(will vanish on the next config change)",
                                  f"scripts/apply-to-vscode.sh {settings}  + reload"))
        except Exception as e:
            fails.append((f"could not parse settings JSONC: {e}", "check for trailing commas / syntax"))

print()
if fails:
    print(f"✗ {len(fails)} problem(s):")
    for msg, fix in fails:
        print(f"  - {msg}\n      fix: {fix}")
    sys.exit(1)
print("✓ all checks passed — install is healthy")
print("  (if icons still don't show: reload the window, and confirm 'Symbol Icons' is the active File Icon Theme)")
PY
