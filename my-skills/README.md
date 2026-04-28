# my-skills

🌐 **English** | [한국어](README.ko.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-orange)](https://github.com/anthropics/claude-code)

> A Claude Code plugin bundling skills for prompt refinement and Firebase Crashlytics automation.
> **This is a personal project, not an official Anthropic product.**

## Skills

| Skill                      | Invocation                                          | Purpose                                                                                                                    |
| -------------------------- | --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `prompt-refine`            | `/my-skills:prompt-refine <text>`                   | Rewrites a user prompt into a Claude-optimized form while preserving the original intent.                                  |
| `crashlytics-to-issue`     | `/my-skills:crashlytics-to-issue`                   | Syncs unresolved Firebase Crashlytics crashes/ANRs into GitHub Issues with automatic regression detection.                 |
| `crashlytics-issue-to-fix` | `/my-skills:crashlytics-issue-to-fix [<issue#>...]` | Analyzes Crashlytics-linked GitHub Issues in isolated git worktrees and opens one PR per issue for batch review and merge. |

## Installation

### From the marketplace (recommended)

Open Claude Code and run inside a session:

```shell
/plugin marketplace add cyb9701/claude-plugins
/plugin install my-skills@claude-plugins
/reload-plugins
```

### Local development

```bash
git clone https://github.com/cyb9701/claude-plugins.git
claude --plugin-dir ./claude-plugins/my-skills
```

To apply changes without restarting:

```shell
/reload-plugins
```

## Prerequisites

### All skills

- Claude Code (latest version with plugin system support)

### Crashlytics skills (`crashlytics-to-issue`, `crashlytics-issue-to-fix`)

- Firebase MCP tools (`mcp__firebase__*`) enabled
- GitHub CLI (`gh`) authenticated — verify with `gh auth status`
- `git` 2.5+ (required for worktree-based operation in `crashlytics-issue-to-fix`)
- First run triggers an interactive setup to select project, app, repository, and labels

See each skill's `references/installation.md` for detailed setup instructions.

### `prompt-refine`

No external dependencies — closed-form text transformer using only `AskUserQuestion`.

## Usage

### Refine a prompt

```shell
/my-skills:prompt-refine Rewrite this: "please review my code"
```

### Sync Crashlytics crashes to GitHub Issues

```shell
/my-skills:crashlytics-to-issue
```

### Auto-fix Crashlytics issues from GitHub

```shell
# Process all issues found by label
/my-skills:crashlytics-issue-to-fix

# Target specific issues
/my-skills:crashlytics-issue-to-fix 150 151 152
```

## Configuration Storage

Even with a single `user`-scope installation, the two Crashlytics skills persist per-user **and per-project** setup results (Firebase project ID, GitHub repo, label selections, etc.) in a separate location from the bundled defaults. Plugin updates replace the bundled defaults but never overwrite user data, and each project gets its own isolated subdirectory so multiple projects on the same machine never overwrite each other — this is what makes `user`-scope installation safe by default.

| Path                                                                    | Role                                                          | Survives update?   |
| ----------------------------------------------------------------------- | ------------------------------------------------------------- | ------------------ |
| `${CLAUDE_SKILL_DIR}/config.json`                                       | Bundled defaults template (severity thresholds, retry policy) | Replaced on update |
| `${CLAUDE_PLUGIN_DATA}/<skill-name>/projects/<PROJECT_KEY>/config.json` | Per-user + per-project setup results                          | Preserved          |

`${CLAUDE_PLUGIN_DATA}` resolves to `~/.claude/plugins/data/my-skills*/` (suffix varies by marketplace ID).

`<PROJECT_KEY>` is auto-extracted at invocation time, in this priority order:

1. `git remote get-url origin` parsed to `<owner>-<repo>` (e.g., `cyb9701-claude-plugins`)
2. Fallback: `git rev-parse --show-toplevel` basename
3. Final fallback: `pwd` basename

This per-project keying lets the same user work across multiple projects (company repo, personal repo, OSS forks) without their Crashlytics setups overwriting each other. On first run, if the current project's user store is empty, the skill copies the bundled defaults and starts the interactive setup automatically.

To re-run setup:

```shell
/my-skills:crashlytics-to-issue --reconfigure
/my-skills:crashlytics-issue-to-fix --reconfigure
```

`prompt-refine` has no external config and is unaffected by this section.

## Directory Structure

```
my-skills/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── README.ko.md
└── skills/
    ├── crashlytics-issue-to-fix/
    │   ├── SKILL.md
    │   ├── config.json
    │   └── references/
    ├── crashlytics-to-issue/
    │   ├── SKILL.md
    │   ├── config.json
    │   └── references/
    └── prompt-refine/
        ├── SKILL.md
        ├── evals/
        └── references/
```

Runtime user data (`~/.claude/plugins/data/my-skills*/`) is not bundled — it is created automatically on first setup.

## License

MIT
