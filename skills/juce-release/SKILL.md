---
name: juce-release
description: Set up GitHub Actions CI and release builds (Windows, macOS, Linux) for a JUCE plug-in repo from the bundled template, and prepare and publish releases of plug-ins that use it (Drum Strip, Gated Scatter Verb and later plug-ins). Use when asked to add CI, GitHub Actions or release builds to a JUCE plug-in, or to release, cut, tag or publish a new version of one.
---

# JUCE plug-in CI and releases

This skill has two parts:

- **Part A: set up CI** in a JUCE plug-in repo from the template in `template/` (next to this file).
- **Part B: make a release** of a plug-in that already uses it.

The template builds, tests, validates and packages a CMake-based JUCE plug-in on GitHub Actions: a Linux build and
tests on every push, and on a `v*` tag Windows (installer and zip), macOS (universal zip) and Linux (zip) release
builds that publish a GitHub Release when all three pass. `references/template-README.md` is the full explanation:
what each file and stage does, costs, and the gotchas behind each design choice. Read it before Part A.

Costs: in a private repo, Windows minutes count double and macOS minutes ten times (a macOS release run is about
150 quota minutes). Never start workflows, push tags or add Windows/macOS jobs to `ci.yml` without asking.

## Part A: set up CI in a JUCE plug-in repo

### A1. Inspect the repo

- It must build with CMake (JUCE via `FetchContent` or a subdirectory). A Projucer-only project needs converting
  first: stop and say so.
- Read `CMakeLists.txt`: the `juce_add_plugin()` call (target, `PRODUCT_NAME`, `COMPANY_NAME`, `FORMATS`,
  `PLUGIN_CODE`, `PLUGIN_MANUFACTURER_CODE`, `IS_SYNTH`, `NEEDS_MIDI_INPUT`), the `project()` line, any test target,
  CLAP support, and copy-after-build settings.
- Check what already exists: `.github/workflows/`, `CMakePresets.json`, `.gitattributes`, `CLAUDE.md`,
  `.claude/settings.json`, `packaging/`, `tools/`, `cmake/`.
- Check `git status`, and that the repo is personal or work as expected. Personal repos need the private git
  identity (see the user's CLAUDE.md) before any commit.

### A2. Copy the template

Copy everything in `template/` into the repo root, keeping the folder structure, without overwriting:
`cp -rn <skill dir>/template/. <repo>/`. For each file that already existed, merge by hand:

- `CMakePresets.json`: the workflows need presets named `debug` and `release` with `binaryDir`
  `${sourceDir}/build/${presetName}`. Keep the project's other presets.
- `.gitattributes`, `CLAUDE.md`, `.claude/settings.json`: merge the template's content into the existing file.
- Existing workflows: list them and ask whether to replace or keep them alongside.

`examples/CMakeLists-snippets.cmake` is a reference for A4. Delete `examples/` from the repo once merged.

### A3. Fill in `packaging/plugin.env`

Take every value from `juce_add_plugin()`. Plain `KEY=value`, no quotes.

- `PLUGIN_TARGET` is the target name, `PRODUCT_NAME` the bundle name, `PACKAGE_NAME` the same without spaces.
- `AU_TYPE`: `aufx` for an effect, `aumu` for an instrument, `aumf` for an effect that takes MIDI.
- `INSTALLER_APP_ID`: a new GUID from `uuidgen`, uppercase, no braces. Never change it after the first release.
- `TEST_TARGET` empty when there are no tests. `BUILD_CLAP=true` only if CLAP is actually built.

### A4. Adapt `CMakeLists.txt`

Follow `examples/CMakeLists-snippets.cmake`. Show the diff before writing. The workflows depend on:

- `CMAKE_OSX_ARCHITECTURES "arm64;x86_64"` and `CMAKE_OSX_DEPLOYMENT_TARGET` set **before** `project()` and not
  inside `if(APPLE)` (which is never true before `project()`, giving a silently single-architecture build).
- `project(<Name> VERSION x.y.z ...)` on one line.
- The version target that runs `cmake/BuildVersion.cmake` and writes `generated/BuildVersion.h`
  (`PLUGIN_VERSION`, `PLUGIN_VERSION_FULL`, `PLUGIN_DEV_BUILD`).
- AU in `FORMATS` on Apple only; copy-after-build off for Release builds (or forced off via `CMAKE_EXTRA_ARGS`).

Recommended, not in the snippets: strict warnings on the project's own sources only, so local builds catch what
MSVC and Apple Clang flag (JUCE's module sources are compiled in the same targets and must not get `-Werror`).
Gated Scatter Verb does it like this:

```cmake
if(MSVC)
    set(MY_WARNINGS /W4 /WX)
else()
    set(MY_WARNINGS -Wall -Wextra -Wpedantic -Werror)
endif()
set_source_files_properties(${MY_SOURCES} PROPERTIES COMPILE_OPTIONS "${MY_WARNINGS}")
```

### A5. Check locally

```
git update-index --chmod=+x tools/run-pluginval.sh tools/claude-pre-commit-check.sh   # after git add
cmake --preset release && cmake --build --preset release && ctest --preset release
tools/run-pluginval.sh "build/release/<PLUGIN_TARGET>_artefacts/Release/VST3/<PRODUCT_NAME>.vst3"
set -a; eval "$(grep -vE '^[[:space:]]*(#|$)' packaging/plugin.env | sed -E 's/^([A-Z_]+)=(.*)$/\1="\2"/')"; set +a
ls "build/release/${PLUGIN_TARGET}_artefacts/Release/VST3/${PRODUCT_NAME}.vst3"   # the path the workflows use
```

Fix every warning in the code. Also configure a clang build in `build/clang` if clang is installed: the
pre-commit hook uses it, and it is closer to Apple Clang.

### A6. Hand over

Summarise what was copied, merged and changed, and give the commit and push commands (with the private git
identity lines first for a personal repo). The workflows must reach the default branch before *Run workflow*
appears. Suggest a dry run per platform (Actions → *Release (Windows)* → *Run workflow*, then macOS and Linux)
but don't start one without asking. Mention `CHANGELOG.md` in Keep a Changelog style: a `## [x.y.z]` section
becomes the release notes.

## Part B: make a release

Read the repo's `CLAUDE.md` and the "Releasing" section of its `README.md` first.

### B1. Version

- Ask for the version if not given. Suggest one from `CHANGELOG.md` under Semantic Versioning: a minor bump for
  `Added` or `Changed` entries, a patch for `Fixed` only.
- Check that the tag `v<version>` doesn't exist yet (`git tag -l`).

### B2. Check the tree

- `git status`: the working tree must be clean apart from the release changes. Uncommitted changes that aren't
  part of the release (for example, from Claude Design in drum-strip) are a reason to stop and ask.
- You must be on `main`, up to date with `origin/main`.
- The release workflows (`release.yml` and `release-{windows,macos,linux}.yml`) must exist on `origin/main`
  (`git ls-tree origin/main .github/workflows/`).

### B3. Build and test locally

Run what CI runs, stricter where possible:

- `tools/claude-pre-commit-check.sh` checks: every `*.sh` is executable in git, and `build/clang` or
  `build/release` builds with no warnings. Run the same checks by hand, and build from scratch if the build folder
  is old, since an incremental build only recompiles changed files.
- `cmake --preset release && cmake --build --preset release && ctest --preset release`
- `tools/run-pluginval.sh "build/release/<PLUGIN_TARGET>_artefacts/Release/VST3/<PRODUCT_NAME>.vst3"` (names are
  in `packaging/plugin.env`).
- Fix every warning and failure in the code. Don't weaken warnings or tests. The known Apple Clang-only failures
  (`-Wshadow-uncaptured-local`, `-Wfloat-equal`) are listed in the template's `CLAUDE.md`. Quote the exact compiler
  message before fixing anything.

### B4. Release changes

- Bump the version in `project(<Name> VERSION x.y.z ...)`, which must stay on one line. The tag must equal
  `v` + that version, or every job stops.
- `CHANGELOG.md` (Keep a Changelog): rename `## [Unreleased]` to `## [x.y.z] - YYYY-MM-DD` with today's date, and
  add a new empty `## [Unreleased]` above it. Check that the entries are written for users and complete; compare
  with `git log v<previous>..HEAD`.
- Update the README wherever it states the released version (for example, the Status section).

### B5. Commit, tag and push: ask first

Show the diff and the planned commands, and wait for a go-ahead. The tag publishes a public release and costs
CI minutes. Never push a tag without explicit approval in this session.

```
git commit -am "Release x.y.z: <one-line summary>"
git tag vx.y.z
git push origin main
git push origin vx.y.z
```

### B6. Watch the runs

- `gh run list --workflow release.yml --limit 3`, then `gh run watch <id> --exit-status`.
- On a failure: `gh run view <id> --log-failed`. Quote the exact error, find the root cause, fix it on `main`
  and ask before re-tagging (delete the tag locally and on origin, then tag the fixed commit). A macOS job stuck in
  *Queued* is a GitHub runner shortage: cancel and re-run.

### B7. Report

Only after all three platforms and the publish job have passed: give the release URL
(`gh release view vx.y.z --json url -q .url`) and list the assets. Don't call the release done before that.

## Keeping the template in step

`template/` is a copy of `~/avajadisandbox/juce-github-ci` (minus its README, which is
`references/template-README.md`). A fix made in a plug-in repo's CI files belongs in the template too; check
with `diff -r` against the repo.
