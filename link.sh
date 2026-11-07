#!/usr/bin/env bash
# Symlink every skill in skills/ into a Claude Code config dir's skills folder.
# Usage: ./link.sh [config dir]   (default: $CLAUDE_CONFIG_DIR, else ~/.claude)
set -euo pipefail
repo=$(cd "$(dirname "$0")" && pwd)
target="${1:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}/skills"
mkdir -p "$target"
for dir in "$repo"/skills/*/; do
    name=$(basename "$dir")
    link="$target/$name"
    if [[ -L "$link" ]]; then
        [[ "$(readlink -f "$link")" == "$(readlink -f "$dir")" ]] && { echo "ok       $name"; continue; }
        echo "skip     $name: $link points to $(readlink "$link")" >&2
    elif [[ -e "$link" ]]; then
        echo "skip     $name: $link exists and is not a symlink" >&2
    else
        ln -s "${dir%/}" "$link" && echo "linked   $name"
    fi
done
