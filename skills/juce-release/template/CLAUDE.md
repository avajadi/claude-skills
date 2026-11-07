# CI and release builds

This project builds, validates and packages its JUCE plug-in with GitHub Actions, from the generic JUCE CI template
(see the template's README.md). If this file sits next to an existing CLAUDE.md, merge the two.

## Layout

- `packaging/plugin.env`: every plug-in-specific value (target and product names, AU codes, installer GUID, CLAP on
  or off, test target, extra CMake arguments). The workflows load it into their environment.
- `.github/workflows/ci.yml`: Linux debug build and tests on pushes to `main` and on pull requests.
- `.github/workflows/release-{windows,macos,linux}.yml`: one platform each. They run by hand (`workflow_dispatch`)
  or are called by `release.yml` (`workflow_call`).
- `.github/workflows/release.yml`: on a `v*` tag, runs all three and publishes a GitHub Release when all pass.
- `packaging/windows/installer.iss` (Inno Setup), `packaging/*/INSTALL.txt` (shipped in the zips; `@PRODUCT_NAME@`
  and `@COMPANY_NAME@` are filled in at build time), `tools/run-pluginval.sh`, `cmake/BuildVersion.cmake`.
- `.claude/settings.json` and `tools/claude-pre-commit-check.sh`: a hook that blocks your `git commit` and
  `git push` when a `*.sh` isn't executable in git or the local build (`build/clang`, else `build/release`) fails.
  When it blocks, fix the cause it reports; don't bypass it.

## Rules

- **Plug-in-specific values go in `plugin.env`, not in the workflows.** Keep the workflow files generic so they
  stay comparable with the template. `plugin.env` is plain `KEY=value` lines with no quotes (quotes would become
  part of the value); comments and blank lines are filtered out before it reaches `$GITHUB_ENV`.
- **Don't change `INSTALLER_APP_ID`** once a version has shipped. Windows uses it to recognise upgrades.
- **The workflows depend on these parts of `CMakeLists.txt`.** Keep them when editing it:
  - `CMAKE_OSX_ARCHITECTURES "arm64;x86_64"` and `CMAKE_OSX_DEPLOYMENT_TARGET` set *before* `project()`, and not
    inside `if(APPLE)`. `APPLE` isn't defined before `project()`, so such a block never runs and the macOS build
    silently covers only one architecture.
  - `project(<Name> VERSION x.y.z ...)` on one line. The workflows read the version from it with sed, and a tag must
    equal `v<version>`.
  - The version target running `cmake/BuildVersion.cmake`, which writes `generated/BuildVersion.h` with
    `PLUGIN_VERSION`, `PLUGIN_VERSION_FULL` and `PLUGIN_DEV_BUILD`. The workflows name packages from
    `PLUGIN_VERSION_FULL`; don't rename the macros.
  - The `juce_add_plugin()` target, `PRODUCT_NAME` and codes must match `plugin.env`. Built plug-ins are found at
    `<build dir>/<PLUGIN_TARGET>_artefacts/Release/<format>/<PRODUCT_NAME>.<ext>`.
  - AU only in `FORMATS` on Apple. Copy-after-build off for Release builds, or forced off through `CMAKE_EXTRA_ARGS`.
- **Shell steps run in bash on every OS** (Git Bash on Windows), except the Windows installer and zip steps, which
  are PowerShell. Use `[[:space:]]`, not `\s`, in `sed -E`: macOS has BSD sed. Strip `\r` from anything read on
  Windows, since the runners check out with CRLF line endings.
- **Mind the cost before triggering runs.** In a private repo, Windows minutes count double and macOS minutes ten
  times (a macOS release run is about 150 quota minutes). Don't start release workflows, push tags or add Windows or
  macOS jobs to `ci.yml` without asking. Prefer checking changes locally first (below).
- **Never push a `v*` tag unless asked.** A tag publishes a public GitHub Release.

## Checking locally

```
cmake --preset release
cmake --build --preset release
ctest --preset release
tools/run-pluginval.sh "build/release/<PLUGIN_TARGET>_artefacts/Release/VST3/<PRODUCT_NAME>.vst3"
```

Local GCC and clang 14 miss warnings that MSVC and Apple Clang flag on CI. Before pushing C++ changes, also build
with clang and strict warnings (`-Wall -Wextra -Wshadow -Wshadow-all -Wshadow-uncaptured-local -Wfloat-equal
-Werror`, where the compiler supports them) and fix every warning, especially shadowing in lambda parameters and
constructor arguments. Check that every script the workflows call is executable in git (`git ls-files -s` shows
`100755`).

To check a workflow's shell logic, load the settings the way the workflows do:

```
set -a; eval "$(grep -vE '^[[:space:]]*(#|$)' packaging/plugin.env | sed -E 's/^([A-Z_]+)=(.*)$/\1="\2"/')"; set +a
```

## Running and debugging on GitHub

- Start a platform build: `gh workflow run release-macos.yml --ref <branch>`. GitHub only accepts this when a
  workflow with that file name exists on the default branch. A brand-new workflow must reach `main` first, or be
  triggered by a temporary `push:` trigger on a throwaway branch.
- Follow a run: `gh run watch <id> --exit-status`. Read failures with `gh run view <id> --log-failed`. Download
  packages with `gh run download <id>`.
- Known failure causes:
  - **macOS compile errors that Linux and Windows don't show.** Apple Clang with JUCE's recommended warnings and
    `-Werror` flags things such as `-Wshadow-uncaptured-local` (a lambda parameter named like a captured variable)
    and `-Wfloat-equal` (including a defaulted `operator==` on a struct with floats). Fix the code; don't weaken the
    warnings.
  - **"Permission denied" on a script:** the executable bit is missing in git. Fix it with
    `git update-index --chmod=+x <file>`.
  - **A macOS job stuck in *Queued*:** GitHub is short of runners. Cancel it and re-run; it isn't a configuration
    problem.
  - **A Linux plug-in that won't load on a user's machine** (`GLIBC_2.xx not found`): the release build must stay on
    the oldest available Ubuntu image. The *Check glibc requirement* step prints what the binary needs, and
    `packaging/linux/INSTALL.txt` states it.
