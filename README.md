# claude-plugins

🌐 **English** | [한국어](README.ko.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-orange)](https://github.com/anthropics/claude-code)

> A personal marketplace of plugins for Claude Code.
> **This is a personal project, not an official Anthropic product.**

Each plugin lives in its own top-level directory with an independent `plugin.json` manifest, and is installable on its own.

## Plugins

| Plugin                       | Description                                                                                                                                                          |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [**my-skills**](./my-skills) | A bundle of Claude Code skills — prompt refinement and Firebase Crashlytics ↔ GitHub Issue automation (registration, regression detection, worktree-based auto-fix). |

## Skills inside `my-skills`

| Skill                      | Invocation                                          | Purpose                                                                                          |
| -------------------------- | --------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| `prompt-refine`            | `/my-skills:prompt-refine <text>`                   | Rewrites a user prompt into a Claude-optimized form while preserving the original intent.        |
| `crashlytics-to-issue`     | `/my-skills:crashlytics-to-issue`                   | Syncs unresolved Firebase Crashlytics crashes/ANRs into GitHub Issues with regression detection. |
| `crashlytics-issue-to-fix` | `/my-skills:crashlytics-issue-to-fix [<issue#>...]` | Analyzes Crashlytics-linked GitHub Issues in isolated git worktrees and opens one PR per issue.  |

## Quick Start

Open Claude Code and run the following commands inside a session:

```shell
# 1. Add this marketplace
/plugin marketplace add cyb9701/claude-plugins

# 2. Install the plugin
/plugin install my-skills@claude-plugins

# 3. Reload plugins to activate
/reload-plugins
```

After installation, skills are available under the `my-skills` namespace:

```shell
/my-skills:prompt-refine <text>
/my-skills:crashlytics-to-issue
/my-skills:crashlytics-issue-to-fix
```

See [`my-skills/README.md`](./my-skills/README.md) for full prerequisites and usage examples.

## License

MIT
