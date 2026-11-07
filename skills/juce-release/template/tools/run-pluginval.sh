#!/usr/bin/env bash
# Validate a plugin with pluginval at strictness level 8.
#
#   tools/run-pluginval.sh <path to .vst3 / .component>
#
# Uses $PLUGINVAL if set, then pluginval on PATH, otherwise downloads the latest release into build/_tools.
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "usage: $0 <plugin path>" >&2
    exit 2
fi

plugin="$1"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tools_dir="$repo_root/build/_tools"

find_pluginval() {
    if [[ -n "${PLUGINVAL:-}" ]]; then
        echo "$PLUGINVAL"
    elif command -v pluginval >/dev/null 2>&1; then
        command -v pluginval
    else
        case "$(uname -s)" in
            Linux)  local zip=pluginval_Linux.zip exe="$tools_dir/pluginval" ;;
            Darwin) local zip=pluginval_macOS.zip exe="$tools_dir/pluginval.app/Contents/MacOS/pluginval" ;;
            *)      local zip=pluginval_Windows.zip exe="$tools_dir/pluginval.exe" ;;
        esac
        if [[ ! -x "$exe" ]]; then
            mkdir -p "$tools_dir"
            echo "Downloading pluginval into $tools_dir" >&2
            curl -fsSL -o "$tools_dir/$zip" "https://github.com/Tracktion/pluginval/releases/latest/download/$zip"
            unzip -o -q "$tools_dir/$zip" -d "$tools_dir"
            chmod +x "$exe"
        fi
        echo "$exe"
    fi
}

pluginval_exe="$(find_pluginval)"
"$pluginval_exe" --version || true

# --validate-in-process gives readable crash output; the timeout covers the slower debug builds.
exec "$pluginval_exe" \
    --strictness-level 8 \
    --validate-in-process \
    --timeout-ms 600000 \
    --validate "$plugin"
