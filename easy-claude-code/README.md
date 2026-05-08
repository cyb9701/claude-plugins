# easy-claude-code

🌐 **English** | [한국어](README.ko.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-orange)](https://github.com/anthropics/claude-code)

> A Claude Code plugin bundling skills for prompt refinement, Firebase Crashlytics automation, and skill discovery.
> **This is a personal project, not an official Anthropic product.**

## Skills

| Skill                      | Invocation                                                 | Purpose                                                                                                                                              |
| -------------------------- | ---------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `prompt-refine`            | `/easy-claude-code:prompt-refine <text>`                   | Rewrites a user prompt into a Claude-optimized form while preserving the original intent.                                                            |
| `crashlytics-to-issue`     | `/easy-claude-code:crashlytics-to-issue`                   | Syncs unresolved Firebase Crashlytics crashes/ANRs into GitHub Issues with automatic regression detection.                                           |
| `crashlytics-issue-to-fix` | `/easy-claude-code:crashlytics-issue-to-fix [<issue#>...]` | Analyzes Crashlytics-linked GitHub Issues in isolated git worktrees and opens one PR per issue for batch review and merge.                           |
| `skill-tree`               | `/easy-claude-code:skill-tree [<lang>] [<query>]`          | Prints a Markdown table of all active plugin, user, and project skills. Supports keyword filtering and ISO language description translation. Runs on `haiku` with `disable-model-invocation: true` — slash-only, no natural-language trigger. The catalog is pre-rendered by a Python script via `` !`<command>` `` syntax so no permission prompts appear. |

## Installation

### From the marketplace (recommended)

Open Claude Code and run inside a session:

```shell
/plugin marketplace add cyb9701/easy-claude-code
/plugin install easy-claude-code@easy-claude-code
/reload-plugins
```

### Local development

```bash
git clone https://github.com/cyb9701/easy-claude-code.git
claude --plugin-dir ./easy-claude-code/easy-claude-code
```

To apply changes without restarting:

```shell
/reload-plugins
```

## Permissions

`/easy-claude-code:skill-tree` uses `disable-model-invocation: true` together with the `` !`<command>` `` pre-execution syntax — the Python script runs before Claude sees the skill content, so no permission prompts appear at all.

The other skills (`crashlytics-*`, `prompt-refine`) follow Claude Code's standard permission flow: pick `Yes, and don't ask again` on the first invocation in a project to silence subsequent prompts.

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
/easy-claude-code:prompt-refine Rewrite this: "please review my code"
```

### Sync Crashlytics crashes to GitHub Issues

```shell
/easy-claude-code:crashlytics-to-issue
```

### Auto-fix Crashlytics issues from GitHub

```shell
# Process all issues found by label
/easy-claude-code:crashlytics-issue-to-fix

# Target specific issues
/easy-claude-code:crashlytics-issue-to-fix 150 151 152
```

### Browse all active skills

`skill-tree` is a slash-only skill (`disable-model-invocation: true`) — the catalog is pre-rendered by a Python script before Claude sees the content, so it must be called explicitly with the full namespace:

```shell
# List every skill across all active plugins, user scope, and project scope
/easy-claude-code:skill-tree

# Filter by keyword
/easy-claude-code:skill-tree crashlytics

# Translate descriptions to a specific language (ISO 639-1/2 code)
/easy-claude-code:skill-tree en
/easy-claude-code:skill-tree ja

# Combine: translate to Japanese and filter by keyword
/easy-claude-code:skill-tree ja prompt
```

`skill-tree` scans three locations and merges the results into a single table:

| Source | Location |
| ------ | -------- |
| Plugin skills | `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/skills/` |
| User skills | `~/.claude/skills/` |
| Project skills | `.claude/skills/` (current working directory) |

When a language code is the first argument, only the **Description** column is translated — plugin and skill names are left as-is so they remain copy-paste-ready for `/` invocations.

## Configuration Storage

Even with a single `user`-scope installation, the two Crashlytics skills persist per-user **and per-project** setup results (Firebase project ID, GitHub repo, label selections, etc.) in a separate location from the bundled defaults. Plugin updates replace the bundled defaults but never overwrite user data, and each project gets its own isolated subdirectory so multiple projects on the same machine never overwrite each other — this is what makes `user`-scope installation safe by default.

| Path                                                                    | Role                                                          | Survives update?   |
| ----------------------------------------------------------------------- | ------------------------------------------------------------- | ------------------ |
| `${CLAUDE_SKILL_DIR}/config.json`                                       | Bundled defaults template (severity thresholds, retry policy) | Replaced on update |
| `${CLAUDE_PLUGIN_DATA}/<skill-name>/projects/<PROJECT_KEY>/config.json` | Per-user + per-project setup results                          | Preserved          |

`${CLAUDE_PLUGIN_DATA}` resolves to `~/.claude/plugins/data/easy-claude-code*/` (suffix varies by marketplace ID).

`<PROJECT_KEY>` is auto-extracted at invocation time, in this priority order:

1. `git remote get-url origin` parsed to `<owner>-<repo>` (e.g., `cyb9701-easy-claude-code`)
2. Fallback: `git rev-parse --show-toplevel` basename
3. Final fallback: `pwd` basename

This per-project keying lets the same user work across multiple projects (company repo, personal repo, OSS forks) without their Crashlytics setups overwriting each other. On first run, if the current project's user store is empty, the skill copies the bundled defaults and starts the interactive setup automatically.

To re-run setup:

```shell
/easy-claude-code:crashlytics-to-issue --reconfigure
/easy-claude-code:crashlytics-issue-to-fix --reconfigure
```

`prompt-refine` has no external config and is unaffected by this section.

## Directory Structure

```
easy-claude-code/
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
    ├── prompt-refine/
    │   ├── SKILL.md
    │   ├── evals/
    │   └── references/
    └── skill-tree/
        ├── SKILL.md        # haiku skill with disable-model-invocation + !`...` inline execution
        └── list-skills.py  # Plugin/user/project skill catalog generator (Python stdlib only)
```

Runtime user data (`~/.claude/plugins/data/easy-claude-code*/`) is not bundled — it is created automatically on first setup.

## License

MIT
