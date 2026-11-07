#!/usr/bin/env bash
# Claude Code PreToolUse hook (see .claude/settings.json): before Claude runs `git commit` or `git push`,
# check what CI would otherwise catch first. Exit 2 blocks the command and shows stderr to Claude.
#
#   1. Every *.sh tracked in git has the executable bit (CI fails with "Permission denied" otherwise).
#   2. The local build is up to date and compiles cleanly. Own sources build with -Werror, so a warning
#      fails the build. Uses build/clang (clang, closer to Apple Clang) if configured, else build/release.
#      The build is incremental: only files changed since the last build are recompiled and checked.
set -uo pipefail

cmd=$(jq -r '.tool_input.command // empty')
grep -qE '(^|[[:space:];&|(])git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+(commit|push)\b' <<<"$cmd" || exit 0

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

bad=$(git ls-files -s -- '*.sh' | awk '$1 != "100755" { print $4 }')
if [[ -n "$bad" ]]; then
    echo "These scripts are not executable in git; CI will fail with 'Permission denied':" >&2
    echo "$bad" | sed 's/^/  /' >&2
    echo "Fix with: git update-index --chmod=+x <file>" >&2
    exit 2
fi

build_dir=""
for d in build/clang build/release; do
    [[ -f "$d/CMakeCache.txt" ]] && { build_dir=$d; break; }
done
if [[ -z "$build_dir" ]]; then
    echo "No configured build in build/clang or build/release; skipping the build check." >&2
    exit 0
fi

if ! out=$(cmake --build "$build_dir" 2>&1); then
    echo "Local build in $build_dir fails; fix it before committing or pushing:" >&2
    grep -E ': (error|warning):' <<<"$out" | head -30 >&2 || tail -30 <<<"$out" >&2
    exit 2
fi
warnings=$(grep -E ': warning:' <<<"$out" | grep -v '/_deps/' || true)
if [[ -n "$warnings" ]]; then
    echo "Local build in $build_dir has compiler warnings; MSVC or Apple Clang may fail on them:" >&2
    head -30 <<<"$warnings" >&2
    exit 2
fi
exit 0
