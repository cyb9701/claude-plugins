# claude-plugins

🌐 **English** | [한국어](README.ko.md)

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-orange)](https://github.com/anthropics/claude-code)

> A personal plugin marketplace for Claude Code.
> **This is a personal project, not an official Anthropic product.**

## Plugins

| Plugin                                   | Description                                                                         | Docs                                                                                |
| ---------------------------------------- | ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| [`easy-claude-code`](./easy-claude-code) | Skills for prompt refinement, Firebase Crashlytics automation, and skill discovery. | [English](./easy-claude-code/README.md) · [한국어](./easy-claude-code/README.ko.md) |

## Quick Start

Open Claude Code and add the marketplace once:

```shell
/plugin marketplace add cyb9701/claude-plugins
```

Install a plugin from the table above, then reload:

```shell
/plugin install <plugin>@cyb9701-claude-plugins
/reload-plugins
```

For example, this command installs `easy-claude-code`:

```shell
/plugin install easy-claude-code@cyb9701-claude-plugins
```

Plugin skills use the `/<plugin>:<skill>` format. Each plugin README lists its skills, prerequisites, and usage examples.

## Repository Layout

```text
.
├── .claude-plugin/
│   └── marketplace.json    # Marketplace catalog
└── <plugin>/
    ├── .claude-plugin/
    │   └── plugin.json     # Plugin manifest
    ├── skills/
    ├── README.md
    └── README.ko.md
```

## Adding a Plugin

1. Create a `<plugin>/` folder with the layout above. Name the plugin for what it does. A plugin name cannot start with `claude-`.
2. Set `name`, `description`, `version`, and `author` in `<plugin>/.claude-plugin/plugin.json`.
3. Add the plugin to the `plugins` array in `.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "<plugin>",
     "source": "./<plugin>",
     "description": "<one-line description>"
   }
   ```

4. Add a row to the [Plugins](#plugins) table in `README.md` and `README.ko.md`.
5. Run `claude plugin validate .` from the repository root. Fix all errors before you commit.

## License

MIT
