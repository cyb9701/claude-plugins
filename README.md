# easy-claude-code

🌐 **English** | [한국어](README.ko.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-orange)](https://github.com/anthropics/claude-code)

> Practical tools for getting more out of Claude Code.
> **This is a personal project, not an official Anthropic product.**

## Skills

| Skill                      | Invocation                                          | Purpose                                                                                                                    |
| -------------------------- | --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `prompt-refine`            | `/easy-claude-code:prompt-refine <text>`            | Rewrites a user prompt into a Claude-optimized form while preserving the original intent.                                  |
| `crashlytics-to-issue`     | `/easy-claude-code:crashlytics-to-issue`            | Syncs unresolved Firebase Crashlytics crashes/ANRs into GitHub Issues with automatic regression detection.                 |
| `crashlytics-issue-to-fix` | `/easy-claude-code:crashlytics-issue-to-fix [<issue#>...]` | Analyzes Crashlytics-linked GitHub Issues in isolated git worktrees and opens one PR per issue for batch review and merge. |

## Commands

| Command      | Invocation                                         | Purpose                                                                                                    |
| ------------ | -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `skill-tree` | `/easy-claude-code:skill-tree [<lang>] [<query>]`  | Lists all active plugin, user, and project skills in a table. Supports keyword filtering and translation.  |

## Quick Start

Open Claude Code and run inside a session:

```shell
/plugin marketplace add cyb9701/easy-claude-code
/plugin install easy-claude-code@easy-claude-code
/reload-plugins
```

After installation, skills are available under the `easy-claude-code` namespace:

```shell
/easy-claude-code:prompt-refine <text>
/easy-claude-code:crashlytics-to-issue
/easy-claude-code:crashlytics-issue-to-fix
```

For full prerequisites and usage examples, see [`easy-claude-code/README.md`](./easy-claude-code/README.md).

## License

MIT
