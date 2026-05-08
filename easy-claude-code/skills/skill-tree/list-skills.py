#!/usr/bin/env python3
"""skill-tree: 활성 플러그인 + user + project 스킬 카탈로그를 마크다운 테이블로 출력."""

from __future__ import annotations

import json
import re
import sys
from collections.abc import Iterable
from itertools import groupby
from pathlib import Path

LANGS = {"en", "ko", "ja", "zh", "fr", "de", "es", "pt", "ru", "it", "ar"}
DESC_LIMIT = 80
HOME = Path.home()


def extract_query(argv: list[str]) -> str:
    """Drop a leading ISO-language token (handled by the model) and join the rest as the query.

    Re-tokenizes via join+split so quoted single-string argv (e.g. `["ko crashlytics"]`) and
    shell-split argv (e.g. `["ko", "crashlytics"]`) both work the same way.
    """
    tokens = " ".join(argv).split()
    rest = tokens[1:] if tokens and tokens[0] in LANGS else tokens
    return " ".join(rest).strip()


def load_enabled_plugins(*paths: Path) -> list[str]:
    enabled: set[str] = set()
    for path in paths:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError, OSError):
            continue
        for key, value in (data.get("enabledPlugins") or {}).items():
            if value:
                enabled.add(key)
    return sorted(enabled)


def parse_frontmatter(path: Path) -> dict[str, str] | None:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return None
    match = re.match(r"---\s*\n(.*?)\n---", text, re.DOTALL)
    if not match:
        return None
    block = match.group(1)
    name_match = re.search(r"^name:\s*(.+)$", block, re.MULTILINE)
    if not name_match:
        return None
    desc_match = re.search(r"^description:\s*(.+)$", block, re.MULTILINE)
    return {
        "name": name_match.group(1).strip().strip("\"'"),
        "description": desc_match.group(1).strip().strip("\"'") if desc_match else "",
    }


def latest_version_dir(plugin_dir: Path) -> Path | None:
    if not plugin_dir.is_dir():
        return None
    return max(
        (p for p in plugin_dir.iterdir() if p.is_dir()),
        key=lambda p: p.name,
        default=None,
    )


def collect_plugin_skills(enabled_plugins: Iterable[str]) -> list[tuple[str, str, str]]:
    cache_root = HOME / ".claude" / "plugins" / "cache"
    rows: list[tuple[str, str, str]] = []
    for key in enabled_plugins:
        if "@" not in key:
            continue
        plugin_name, marketplace = key.split("@", 1)
        plugin_root = cache_root / marketplace / plugin_name
        latest = latest_version_dir(plugin_root)
        if latest is None:
            continue
        skills_root = latest / "skills"
        if not skills_root.is_dir():
            continue
        for skill_path in skills_root.glob("**/SKILL.md"):
            fm = parse_frontmatter(skill_path)
            if fm:
                rows.append((plugin_name, fm["name"], fm["description"]))
    return rows


def collect_dir_skills(root: Path) -> list[tuple[str, str]]:
    if not root.is_dir():
        return []
    rows: list[tuple[str, str]] = []
    for skill_path in root.glob("**/SKILL.md"):
        fm = parse_frontmatter(skill_path)
        if fm:
            rows.append((fm["name"], fm["description"]))
    return rows


def matches(query: str, *fields: str) -> bool:
    if not query:
        return True
    needle = query.lower()
    return any(needle in field.lower() for field in fields)


def truncate(text: str, limit: int = DESC_LIMIT) -> str:
    cleaned = text.replace("|", r"\|").replace("\n", " ").strip()
    return cleaned if len(cleaned) <= limit else cleaned[:limit].rstrip() + "..."


def render(plugin_rows, user_rows, project_rows, query: str) -> str:
    n_plugins = len({p for p, _, _ in plugin_rows})
    total = len(plugin_rows) + len(user_rows) + len(project_rows)

    lines: list[str] = []
    if query:
        lines.append(f'(Search: "{query}")')
        lines.append("")

    if plugin_rows:
        for plugin_name, group in groupby(plugin_rows, key=lambda r: r[0]):
            lines.append(f"### 🟢 {plugin_name}")
            lines.append("")
            lines.append("| Skill | Description |")
            lines.append("|-------|-------------|")
            for _, skill_name, description in group:
                lines.append(f"| {skill_name} | {truncate(description)} |")
            lines.append("")
    else:
        lines.append("(no matches)")
        lines.append("")

    lines.append("### 🟢 user & project")
    lines.append("")
    lines.append("| Scope | Skill | Description |")
    lines.append("|-------|-------|-------------|")
    if user_rows or project_rows:
        for scope, rows in (("User", user_rows), ("Project", project_rows)):
            for i, (skill_name, description) in enumerate(rows):
                label = scope if i == 0 else ""
                lines.append(f"| {label} | {skill_name} | {truncate(description)} |")
    else:
        lines.append("| (no matches) |  |  |")
    lines.append("")

    lines.append(
        f"**Total: {n_plugins} plugins, {len(plugin_rows)} plugin skills + "
        f"{len(user_rows)} user skills + {len(project_rows)} project skills "
        f"= {total} skills**"
    )
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    query = extract_query(argv[1:])

    enabled = load_enabled_plugins(
        HOME / ".claude" / "settings.json",
        Path(".claude") / "settings.local.json",
    )

    plugin_rows = [
        row for row in collect_plugin_skills(enabled) if matches(query, row[1], row[2])
    ]
    plugin_rows.sort(key=lambda r: (r[0], r[1]))

    user_rows = [
        row for row in collect_dir_skills(HOME / ".claude" / "skills") if matches(query, *row)
    ]
    user_rows.sort()

    project_rows = [
        row for row in collect_dir_skills(Path(".claude") / "skills") if matches(query, *row)
    ]
    project_rows.sort()

    print(render(plugin_rows, user_rows, project_rows, query))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
