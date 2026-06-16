# Virn custom tier icons

This fork adds six full-glyph folder icons for the `virn-os` repo's top-level
tiers, on top of upstream Symbols.

| Icon name | Glyph | Used for |
|---|---|---|
| `folder-brain` | brain (pink) | `00-brain` |
| `folder-systems` | gear (blue) | `01-systems` |
| `folder-agents` | robot (green) | `02-agents` |
| `folder-lab` | flask (amber) | `03-lab` |
| `folder-notes` | document (sky) | `04-notes` |
| `folder-archives` | box (slate) | `05-archives` |

SVGs live in `src/icons/folders/`; registered in `src/symbol-icon-theme.json`.

## How it's installed

VS Code loads the **marketplace** Symbols extension, not this fork — so we patch
the icons into the live install instead of replacing it:

```sh
scripts/apply-to-vscode.sh      # copies svgs + registers defs into the install
# then: Cmd+Shift+P -> Reload Window   (REQUIRED — see below)
```

The folder→icon mapping lives in the **workspace** settings of the repo that
uses it (virn-os: `.vscode/settings.json` → `symbols.folders.associations`), and
`apply-to-vscode.sh` reads them and **bakes them straight into the theme's
`folderNames`**.

Why baking matters: the extension regenerates its theme on **any** configuration
change (even switching your color theme), and it only reads *user-scope* settings
reliably — so workspace associations on their own get silently dropped and the
icons "break." Baking them into the theme base makes them survive every
regeneration. A reload is still required after applying so VS Code re-reads the
theme. **Trade-off:** baked `folderNames` match by name in *every* workspace, so
generic names (`core`, `memory`, `operations`, …) will also pick up these icons
in other projects. The numbered tiers (`00-brain` …) are unique and never
collide.

## After a Symbols update

A Symbols update installs a fresh version folder without our patches. Re-run:

```sh
scripts/apply-to-vscode.sh && echo "now reload the window"
```

The script is idempotent and version-agnostic (patches every installed
`miguelsolorio.symbols-*`), validates the theme JSON before/after, and keeps a
pristine `symbol-icon-theme.json.orig` backup per version.

## Troubleshooting

```sh
scripts/verify.sh /path/to/.vscode/settings.json
```

Reports each problem with a fix. Common causes:

- **Icons vanished right after apply/update** → reload the window.
- **Icons vanished after changing color theme / some unrelated setting** → the
  associations weren't baked. Run `apply-to-vscode.sh <settings.json>` + reload.
  `verify.sh` flags this explicitly ("NOT baked into theme folderNames").
- **Still missing after reload** → run `verify.sh`; it pinpoints a missing svg,
  unregistered def, broken reference, unbaked association, or invalid theme.
- **All folders show default icons** → confirm "Symbol Icons" is the active File
  Icon Theme (Cmd+Shift+P → "Preferences: File Icon Theme").

## Syncing upstream's new icons

```sh
git fetch origin && git merge origin/main
scripts/apply-to-vscode.sh   # then reload
```
