# Claude Code skills

Eddie's personal Claude Code skills. The originals live here; Claude Code finds them through symlinks in
`~/.claude/skills/`.

| Skill | What it does |
|---|---|
| [`juce-release`](skills/juce-release/SKILL.md) | Sets up GitHub Actions CI and release builds (Windows, macOS, Linux) for a JUCE plug-in repo from the bundled template, and prepares and publishes releases. |

## Installing

```sh
./link.sh                    # links every skill into ~/.claude/skills (or $CLAUDE_CONFIG_DIR/skills)
./link.sh ~/.claude-rise     # into another Claude Code profile
```

The script only adds symlinks. It never replaces an existing skill folder or a link that points elsewhere; it
reports those and skips them. Run it again after adding a skill.

## Adding a skill

Create `skills/<name>/SKILL.md` with `name` and `description` frontmatter, run `./link.sh`, and start a new Claude
Code session. Edit skills here, not through the symlink's target path elsewhere.
