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

The folder→icon mapping itself lives in the **workspace** settings of the repo
that uses it (virn-os: `.vscode/settings.json` → `symbols.folders.associations`).
The extension injects those associations into its generated theme **only on
activate** — which is why a reload is always required after applying.

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
- **Still missing after reload** → run `verify.sh`; it pinpoints a missing svg,
  unregistered def, broken reference, or invalid theme.
- **All folders show default icons** → confirm "Symbol Icons" is the active File
  Icon Theme (Cmd+Shift+P → "Preferences: File Icon Theme").

## Syncing upstream's new icons

```sh
git fetch origin && git merge origin/main
scripts/apply-to-vscode.sh   # then reload
```
