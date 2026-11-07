#!/usr/bin/env bash
# Builds the stand-alone template package (juce-github-ci.zip) for people who want the files rather than the skill:
# the files from template/, references/template-README.md as README.md, TEMPLATE-LICENSE as LICENSE, and
# optionally a PDF of the README.
#
# Usage: package.sh [output.zip]     (default: ./juce-github-ci.zip)
#
# Set MD2PDF to a Markdown-to-PDF command to include README.pdf. It is called as `$MD2PDF <dir>/README.md` and must
# write README.pdf next to it. Without MD2PDF (or with MD2PDF=none) the package has no PDF.
set -euo pipefail

skill="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$(realpath -m "${1:-juce-github-ci.zip}")"
md2pdf="${MD2PDF:-none}"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pkg="$work/juce-github-ci"

cp -a "$skill/template" "$pkg"
cp "$skill/references/template-README.md" "$pkg/README.md"
cp "$skill/TEMPLATE-LICENSE" "$pkg/LICENSE"

if [[ "$md2pdf" != none ]]; then
    "$md2pdf" "$pkg/README.md"
    rm -f "$pkg/README.html"
    [[ -f "$pkg/README.pdf" ]] || { echo "$md2pdf made no README.pdf" >&2; exit 1; }
else
    echo "MD2PDF not set: packaging without README.pdf" >&2
fi

rm -f "$out"
(cd "$work" && zip -qrX "$out" juce-github-ci)
echo "Wrote $out"
unzip -l "$out" | tail -1
