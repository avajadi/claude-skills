---
name: juce-release
description: Prepare and publish a release of a JUCE plug-in that uses the juce-github-ci template (Drum Strip, Gated Scatter Verb and later plug-ins). Use when asked to release, cut, tag or publish a new version of a JUCE plug-in.
---

# Releasing a JUCE plug-in

These repos use the CI template in `~/avajadisandbox/juce-github-ci`. Pushing a `v*` tag runs `release.yml`,
which builds Windows, macOS and Linux and publishes a **public** GitHub Release when all three pass. A macOS run
costs about 150 quota minutes, so problems must be found locally first. Read the repo's `CLAUDE.md` and the
"Releasing" section of its `README.md` before starting.

## 1. Version

- Ask for the version if not given. Suggest one from `CHANGELOG.md` under Semantic Versioning: a minor bump for
  `Added` or `Changed` entries, a patch for `Fixed` only.
- Check that the tag `v<version>` doesn't exist yet (`git tag -l`).

## 2. Check the tree

- `git status`: the working tree must be clean apart from the release changes. Uncommitted changes that aren't
  part of the release (for example, from Claude Design in drum-strip) are a reason to stop and ask.
- You must be on `main`, up to date with `origin/main`.
- The release workflows (`release.yml` and `release-{windows,macos,linux}.yml`) must exist on `origin/main`
  (`git ls-tree origin/main .github/workflows/`).

## 3. Build and test locally

Run what CI runs, stricter where possible:

- `tools/claude-pre-commit-check.sh` checks: every `*.sh` is executable in git, and `build/clang` (clang, closest
  to Apple Clang) or `build/release` builds with no warnings. Run the same checks by hand, and also build from
  scratch if the build folder is old, since an incremental build only recompiles changed files.
- `cmake --preset release && cmake --build --preset release && ctest --preset release`
- `tools/run-pluginval.sh "build/release/<PLUGIN_TARGET>_artefacts/Release/VST3/<PRODUCT_NAME>.vst3"` (names are
  in `packaging/plugin.env`).
- Fix every warning and failure in the code. Don't weaken warnings or tests. The known Apple Clang-only failures
  (`-Wshadow-uncaptured-local`, `-Wfloat-equal`) are listed in the template's `CLAUDE.md`. Quote the exact compiler
  message before fixing anything.

## 4. Release changes

- Bump the version in `project(<Name> VERSION x.y.z ...)`, which must stay on one line. The tag must equal
  `v` + that version, or every job stops.
- `CHANGELOG.md` (Keep a Changelog): rename `## [Unreleased]` to `## [x.y.z] - YYYY-MM-DD` with today's date, and
  add a new empty `## [Unreleased]` above it. Check that the entries are written for users and complete; compare
  with `git log v<previous>..HEAD`.
- Update the README wherever it states the released version (for example, the Status section).

## 5. Commit, tag and push: ask first

Show the diff and the planned commands, and wait for a go-ahead. The tag publishes a public release and costs
CI minutes. Never push a tag without explicit approval in this session.

```
git commit -am "Release x.y.z: <one-line summary>"
git tag vx.y.z
git push origin main
git push origin vx.y.z
```

## 6. Watch the runs

- `gh run list --workflow release.yml --limit 3`, then `gh run watch <id> --exit-status`.
- On a failure: `gh run view <id> --log-failed`. Quote the exact error, find the root cause, fix it on `main`
  and ask before re-tagging (delete the tag locally and on origin, then tag the fixed commit). A macOS job stuck in
  *Queued* is a GitHub runner shortage: cancel and re-run.

## 7. Report

Only after all three platforms and the publish job have passed: give the release URL
(`gh release view vx.y.z --json url -q .url`) and list the assets. Don't call the release done before that.
