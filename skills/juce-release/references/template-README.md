---
version: 1.2.0
---
# GitHub Actions CI for JUCE plug-ins

A drop-in GitHub Actions setup that builds a JUCE plug-in for **Windows, macOS and Linux** on GitHub's own
machines. It validates the plug-in with pluginval and auval and packages it for users: a Windows installer, a
Windows zip, a universal macOS zip (Apple silicon and Intel in one binary) and a Linux zip. Push a version tag and it
publishes them all as a GitHub Release. You don't need a Mac or a Windows box.

I use it for my own plug-ins (Drum Strip and Gated Scatter Verb), and it's running green on both platforms. This
copy is generalised: everything specific to one plug-in lives in a single settings file, `packaging/plugin.env`.

## What's in the package

| File | What it does |
|---|---|
| `.github/workflows/ci.yml` | On every push to `main` and on pull requests: Linux debug build and unit tests. Cheap and fast. |
| `.github/workflows/release.yml` | On a `v*` tag: runs the three platform workflows, then publishes a GitHub Release if all pass. |
| `.github/workflows/release-windows.yml` | Windows x64: build, tests, pluginval, Inno Setup installer, zip. |
| `.github/workflows/release-macos.yml` | macOS universal: build, tests, ad-hoc signing, pluginval, auval, zip. |
| `.github/workflows/release-linux.yml` | Linux x64: build, tests, glibc check, pluginval, zip. |
| `packaging/plugin.env` | **The settings: your plug-in's names and codes.** The only file you have to edit. |
| `packaging/windows/installer.iss` | Inno Setup script. Installs VST3 (and CLAP) into `Common Files`. |
| `packaging/{windows,macos,linux}/INSTALL.txt` | Instructions shipped inside the zips. `@PRODUCT_NAME@` is filled in during the build. |
| `tools/run-pluginval.sh` | Runs pluginval at strictness 8 and downloads it when it isn't installed. Works locally too. |
| `cmake/BuildVersion.cmake` | Writes a version header with the version and commit hash on every build. |
| `CMakePresets.json` | `debug` and `release` presets (Ninja), used by the Linux and macOS jobs. |
| `examples/CMakeLists-snippets.cmake` | The parts of a `CMakeLists.txt` the workflows rely on, with comments. |
| `.gitattributes` | Keeps LF line endings for scripts and settings on Windows checkouts. |
| `CLAUDE.md` | Instructions for Claude Code: how the CI fits together, what not to break, how to debug a failed run. |
| `.claude/settings.json` | Claude Code hook: runs `tools/claude-pre-commit-check.sh` before Claude runs `git commit` or `git push`. |
| `tools/claude-pre-commit-check.sh` | The hook's checks: every `*.sh` is executable in git, and the local build (`build/clang`, else `build/release`) compiles cleanly. Blocks Claude's commit or push when either fails. |

## How it fits together

```
push / pull request ─────▶ CI (Linux): build + tests

tag v1.2.0 ──▶ Release ─┬─▶ Release (Windows) ─┐
                        ├─▶ Release (macOS) ───┼─▶ publish: GitHub Release v1.2.0
                        └─▶ Release (Linux) ───┘    ├ MyPlugin-1.2.0-windows-x64-setup.exe
                                                    ├ MyPlugin-1.2.0-windows-x64.zip
                                                    ├ MyPlugin-1.2.0-macos-universal.zip
                                                    └ MyPlugin-1.2.0-linux-x64.zip

Run workflow (by hand) ──▶ one Release (platform) workflow alone
                           package kept as a run artifact for 14 days
```

The platform workflows are *reusable*. `release.yml` calls them for a tag, and each can also be started by hand
from the Actions tab. A manual run gives you a test build to download without making a release.

## Setting it up

The workflows assume a JUCE project built with CMake, with JUCE pulled in by `FetchContent` or as a subdirectory.
Projucer-only projects need converting to CMake first.

1. **Copy the files** into the root of your repository, keeping the folder structure. If you already have a
   `CMakePresets.json`, `.gitattributes`, `CLAUDE.md` or `.claude/settings.json`, merge them. (`CLAUDE.md`,
   `.claude/settings.json` and `tools/claude-pre-commit-check.sh` only matter if you use Claude Code; delete them
   otherwise.) The workflows only need presets named `debug` and `release`
   whose build folder is `build/<preset name>`.

2. **Fill in `packaging/plugin.env`.** Most values come straight from your `juce_add_plugin()` call. Generate a new
   GUID for `INSTALLER_APP_ID` (`uuidgen`, or `[guid]::NewGuid()` in PowerShell) and never change it afterwards:
   Windows uses it to recognise upgrades. Write the values without quotes.

3. **Merge the CMake parts** from `examples/CMakeLists-snippets.cmake` into your `CMakeLists.txt`. The ones that
   matter:
   - `CMAKE_OSX_ARCHITECTURES` and `CMAKE_OSX_DEPLOYMENT_TARGET` set **before `project()`**, or you get an
     Apple-silicon-only build (see the gotchas below).
   - `project(<Name> VERSION x.y.z ...)` on one line. The workflows read the version from it.
   - The version target that runs `cmake/BuildVersion.cmake`. The workflows name the packages from the
     `PLUGIN_VERSION_FULL` it writes to `build/<preset>/generated/BuildVersion.h`.
   - AU added to `FORMATS` on Apple only.
   - Copy-after-build off for Release builds.

4. **Make the scripts executable in git** (copying the files doesn't always keep the bit):

   ```
   git add tools/run-pluginval.sh tools/claude-pre-commit-check.sh
   git update-index --chmod=+x tools/run-pluginval.sh tools/claude-pre-commit-check.sh
   ```

   The workflows call `run-pluginval.sh` through `bash` so it works either way, but this keeps it runnable as
   `tools/run-pluginval.sh`. The Claude Code hook runs `claude-pre-commit-check.sh` directly, so it needs the bit.

5. **Commit and push to the default branch.** GitHub only shows *Run workflow* for workflows on the default branch,
   so a workflow that exists only on another branch can't be started by hand yet.

6. **Do a dry run**: Actions → *Release (Windows)* → *Run workflow*, then the same for macOS and Linux. The finished run has
   the package under *Artifacts*. You can also fetch it with `gh run download <run id>`.

Optionally, keep a `CHANGELOG.md` in [Keep a Changelog](https://keepachangelog.com) style. When a `## [1.2.0]` section
exists for the tagged version, it becomes the release notes. Otherwise GitHub generates notes from the commits.

## Making a release

1. Bump the version in `project(... VERSION 1.2.0 ...)` and commit.
2. Tag that commit and push the tag:

   ```
   git tag v1.2.0
   git push origin v1.2.0
   ```

Every platform builds again from the tag. The tag must match the CMake version exactly (`v` + version), or every
job stops at its first step. That way you can't publish a `v1.2.0` that reports itself as 1.1.0. A build from the
tagged, unmodified commit reports a clean `1.2.0`. Any other build reports `1.2.0-dev+<commit>`, so a test build
can't be mistaken for the release.

## What each stage does, and why

**Universal macOS build.** One binary contains both arm64 and x86_64 code, for macOS 11 and later. The signing step
runs `lipo -archs` on every bundle and prints `x86_64 arm64` in the log, so you can check both are there.

**Ad-hoc signing.** Apple silicon refuses to load unsigned code, so every bundle gets an ad-hoc signature
(`codesign --sign -`). It's free and needs no Apple account. Because the plug-in isn't *notarised*, users have to
clear the quarantine flag once with `xattr`. The macOS `INSTALL.txt` in the zip explains how.

**pluginval at strictness 8.** Loads the VST3 and puts it through Tracktion's validation: state save/restore,
different sample rates and block sizes, parameter fuzzing, threading. It runs on both platforms because bugs
sometimes show up on only one.

**auval.** Apple's own AU validator. Logic refuses AUs that fail it. The AU has to be installed before auval can
find it, so the job copies it into `~/Library/Audio/Plug-Ins/Components` and restarts the AU registrar first.

**Windows installer.** Inno Setup puts the VST3 (and CLAP, if built) into `C:\Program Files\Common Files\VST3` and
`\CLAP`, which every host scans. When CLAP is on, users can choose which formats to install. The zip is for
people who prefer to copy files themselves.

**Linux build on an older Ubuntu.** A Linux binary needs at least the glibc version it was built against, so
the release build runs on Ubuntu 22.04 rather than the newest image. The plug-in then loads on anything from about
2022 onwards (Ubuntu 22.04, Debian 12, Fedora 36). The job prints the highest glibc version the binary uses, so you
can see the requirement in the log. pluginval runs under Xvfb, a virtual X display, because it opens the editor.
When GitHub retires the 22.04 image, move to the next oldest and update `packaging/linux/INSTALL.txt`.

**Static MSVC runtime.** Users don't need the Visual C++ redistributable installed.

**Linux CI.** A debug build and the tests on every push. It catches most compile errors and test failures for a fraction of
the cost, so the expensive platforms only run when you ask for them.

## What it costs

Public repositories get the runners free. Private repositories get a monthly allowance of minutes (2000 on the free
plan), and Windows minutes count **double**, macOS minutes **ten times**. With my plug-ins, a macOS run takes about
15 minutes, which is around 150 minutes of allowance, and a full release with all three platforms about 210. That's why the platform builds
run only on tags or by hand, never on every push. The `build/_deps` cache keeps the Linux job short by not
downloading JUCE again each time.

## Gotchas I ran into

- **`if(APPLE)` before `project()` never matches.** CMake doesn't know the platform until `project()` has run.
  So the macOS architecture settings are set unconditionally. Other platforms ignore them.
- **The macOS build can fail when Linux and Windows pass.** JUCE's recommended warning flags on Apple Clang include
  warnings GCC and MSVC don't have, for example `-Wshadow-uncaptured-local` (a lambda parameter with the same
  name as a captured variable) and `-Wfloat-equal` (that includes a defaulted `operator==` on a struct with floats).
  If you build with `-Werror`, expect a round of fixes the first time. The macOS build uses `-k 0`, so one run
  reports all the errors at once.
- **"Permission denied" on a script** means the executable bit isn't in git. See setup step 4.
- **A macOS job stuck in *Queued*** for a long time is GitHub running short of Mac runners, not your
  configuration. Cancel it and re-run.
- **CRLF on Windows.** Windows runners check out text with CRLF line endings. The workflows strip `\r` when they read
  `plugin.env`, and `.gitattributes` keeps LF for the scripts.
- **Linux plug-ins depend on the build machine's glibc.** Built on a new distribution, they fail to load on older
  ones with a "version `GLIBC_2.xx' not found" error. That's why the release build uses the oldest Ubuntu image.
- **A new CI file isn't listed under Actions** until it's on the default branch, as noted in setup step 5.

## Not included

- **Apple Developer ID signing and notarisation.** That needs a paid Apple developer account. With it, you would
  import the certificate from repository secrets, sign with `--options runtime` and run `xcrun notarytool submit
  --wait`, and users would no longer need the `xattr` step.
- **Windows code signing.** Without it, SmartScreen warns about the installer ("More info" → "Run anyway"). The
  Windows `INSTALL.txt` mentions this.
- **A macOS `.pkg` installer.** The zip and `INSTALL.txt` cover it. `pkgbuild`/`productbuild` would be the next
  step.
- **Linux ARM, distribution packages (.deb, Flatpak) and LV2.** The Linux zip is x64 VST3 and CLAP.

## Trying things locally

Most of the pipeline runs on your own machine too:

```
cmake --preset release
cmake --build --preset release
ctest --preset release
tools/run-pluginval.sh "build/release/MyPlugin_artefacts/Release/VST3/My Plugin.vst3"
```

`run-pluginval.sh` uses `$PLUGINVAL` or a `pluginval` on your `PATH` if there is one. Otherwise it downloads the
latest release into `build/_tools`.
