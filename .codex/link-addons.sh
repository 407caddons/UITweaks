#!/usr/bin/env bash
# Usage: bash .codex/link-addons.sh "/other/install/Interface/AddOns"
set -euo pipefail

if [[ $# -ne 1 || "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Usage: bash .codex/link-addons.sh /path/to/other/Interface/AddOns"
    echo "Close WoW first. Existing files and conflicting links are never overwritten."
    [[ $# -eq 1 && ( "$1" == "--help" || "$1" == "-h" ) ]] && exit 0
    exit 1
fi

SOURCE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
if [[ ! -d "$1" ]]; then
    echo "Error: destination directory does not exist: $1" >&2
    exit 1
fi
DEST=$(cd -- "$1" && pwd -P)
addons=(LunaUITweaks LunaUITweaks_Config LunaUITweaks_Games)
sources=("$SOURCE" "$SOURCE/LunaUITweaks_Config" "$SOURCE/LunaUITweaks_Games")

# Validate everything before creating any links, including dangling symlinks.
for i in "${!addons[@]}"; do
    name=${addons[$i]}
    source=${sources[$i]}
    target="$DEST/$name"
    if [[ ! -f "$source/$name.toc" ]]; then
        echo "Error: source addon is missing: $source/$name.toc" >&2
        exit 1
    fi
    if [[ -e "$target" || -L "$target" ]]; then
        if [[ -L "$target" && "$target" -ef "$source" ]]; then
            continue
        fi
        echo "Error: destination already exists: $target" >&2
        echo "Move it somewhere safe first; nothing has been changed." >&2
        exit 1
    fi
done

for i in "${!addons[@]}"; do
    target="$DEST/${addons[$i]}"
    source=${sources[$i]}
    if [[ -L "$target" && "$target" -ef "$source" ]]; then
        echo "Already linked: $target"
    else
        ln -sT -- "$source" "$target"
        echo "Created: $target -> $source"
    fi
done

echo "Done. Both installations now use the same addon source; WTF settings remain separate."
echo "Avoid addon-manager updates to these links: they may overwrite your shared source."
