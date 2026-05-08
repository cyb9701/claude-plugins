#!/usr/bin/env bash
# Skill tree printer.
#
# Scans SKILL.md files from active plugins + user area + project area
# and prints a markdown table. If a keyword argument is given, only
# skills whose name, description, or label contain the keyword are shown.
#
# Usage:
#   bash <this-script> [search-query]

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
PROJECT_SETTINGS="$PWD/.claude/settings.local.json"
CACHE="$HOME/.claude/plugins/cache"
USER_SKILLS="$HOME/.claude/skills"
PROJECT_SKILLS="$PWD/.claude/skills"
QUERY="${1:-}"

# Common function: read SKILL.md and print tab-separated "label\tdesc".
# Returns 0 on match, 1 if filtered out or name field is missing.
print_skill() {
  local skill_md="$1"
  local label="$2"

  local name desc short
  name=$(awk '/^name:/{ sub(/^name: */,""); gsub(/^"|"$/,""); print; exit }' "$skill_md")
  desc=$(awk '/^description:/{ sub(/^description: */,""); gsub(/^"|"$/,""); print; exit }' "$skill_md")
  [ -z "$name" ] && return 1

  if [ -n "$QUERY" ] && ! printf '%s' "$name $desc $label" | grep -Fqi -- "$QUERY"; then
    return 1
  fi

  short=$(printf '%s' "$desc" | cut -c1-80)
  [ "${#desc}" -gt 80 ] && short="$short..."
  # Escape pipe characters so they don't break the markdown table.
  short=$(printf '%s' "$short" | sed 's/|/\\|/g')
  printf '%s\t%s\n' "$label" "$short"
  return 0
}

# Section 1: Merge enabledPlugins from global and project settings.
enabled=$(
  {
    jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$SETTINGS" 2>/dev/null || true
    [ -f "$PROJECT_SETTINGS" ] && jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$PROJECT_SETTINGS" 2>/dev/null || true
  } | sort -u
)

plugin_rows=""
plugin_count=0
plugin_skill_count=0
plugin_group_added=false

while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  plugin="${entry%@*}"
  marketplace="${entry#*@}"
  base_dir="$CACHE/$marketplace/$plugin"
  [ -d "$base_dir" ] || continue

  latest=$(ls -v "$base_dir" 2>/dev/null | tail -1)
  [ -z "$latest" ] && continue
  root="$base_dir/$latest"

  meta="$root/.claude-plugin/plugin.json"
  version=""
  if [ -f "$meta" ]; then
    version=$(jq -r '.version // ""' "$meta" 2>/dev/null || true)
  fi
  # Fall back to directory name only when plugin.json has no version field.
  if [ -z "$version" ] && [ "$latest" != "unknown" ]; then
    version="$latest"
  fi

  [ -d "$root/skills" ] || continue

  # ② @marketplace 제거 — 플러그인명만 표시
  if [ -n "$version" ]; then
    plugin_display="$plugin (v$version)"
  else
    plugin_display="$plugin"
  fi

  count=0
  group_rows=""
  while IFS= read -r skill_md; do
    skill_label=$(basename "$(dirname "$skill_md")")
    if row=$(print_skill "$skill_md" "$skill_label"); then
      skill_name=$(printf '%s' "$row" | cut -f1)
      skill_desc=$(printf '%s' "$row" | cut -f2-)
      # ① 첫 행에만 플러그인명 볼드 표시; 이후 행은 빈 셀.
      if [ "$count" -eq 0 ]; then
        plugin_col="**$plugin_display**"
      else
        plugin_col=""
      fi
      group_rows+="| $plugin_col | $skill_name | $skill_desc |"$'\n'
      count=$((count + 1))
    fi
  done < <(find "$root/skills" -mindepth 2 -maxdepth 2 -name "SKILL.md" -type f 2>/dev/null | sort)

  if [ "$count" -gt 0 ]; then
    plugin_rows+="$group_rows"
    plugin_group_added=true
    plugin_count=$((plugin_count + 1))
    plugin_skill_count=$((plugin_skill_count + count))
  fi
done <<< "$enabled"

# Section 2: User skills (~/.claude/skills/).
user_rows=""
user_count=0
user_has_skills=false
if [ -d "$USER_SKILLS" ]; then
  while IFS= read -r skill_md; do
    user_has_skills=true
    rel="${skill_md#"$USER_SKILLS/"}"
    rel="${rel%/SKILL.md}"
    if row=$(print_skill "$skill_md" "$rel"); then
      skill_name=$(printf '%s' "$row" | cut -f1)
      skill_desc=$(printf '%s' "$row" | cut -f2-)
      scope_col=$([ "$user_count" -eq 0 ] && echo "User" || echo "")
      user_rows+="| $scope_col | $skill_name | $skill_desc |"$'\n'
      user_count=$((user_count + 1))
    fi
  done < <(find "$USER_SKILLS" -name "SKILL.md" -type f 2>/dev/null | sort)
fi

# Section 3: Project skills (.claude/skills/).
project_rows=""
project_count=0
project_has_skills=false
if [ -d "$PROJECT_SKILLS" ]; then
  while IFS= read -r skill_md; do
    project_has_skills=true
    rel="${skill_md#"$PROJECT_SKILLS/"}"
    rel="${rel%/SKILL.md}"
    if row=$(print_skill "$skill_md" "$rel"); then
      skill_name=$(printf '%s' "$row" | cut -f1)
      skill_desc=$(printf '%s' "$row" | cut -f2-)
      scope_col=$([ "$project_count" -eq 0 ] && echo "Project" || echo "")
      project_rows+="| $scope_col | $skill_name | $skill_desc |"$'\n'
      project_count=$((project_count + 1))
    fi
  done < <(find "$PROJECT_SKILLS" -name "SKILL.md" -type f 2>/dev/null | sort)
fi

# Assemble output.
total=$((plugin_skill_count + user_count + project_count))
echo "# Skill Tree ($plugin_count plugins, $user_count user, $project_count project, total: $total skills)"
[ -n "$QUERY" ] && echo "(Search: \"$QUERY\")"

echo ""
echo "## 🔌 Active Plugins"
if [ -n "$plugin_rows" ]; then
  echo "| Plugin | Skill | Description |"
  echo "|--------|-------|-------------|"
  printf '%s' "$plugin_rows"
elif [ -n "$enabled" ]; then
  echo "(no matches)"
else
  echo "(no active plugin skills)"
fi

echo ""
echo "## 👤 User  &  📁 Project Skills"
other_rows="$user_rows$project_rows"
if [ -n "$other_rows" ]; then
  echo "| Scope | Skill | Description |"
  echo "|-------|-------|-------------|"
  printf '%s' "$other_rows"
elif $user_has_skills || $project_has_skills; then
  echo "(no matches)"
else
  echo "(no user or project skills)"
fi

echo ""
echo "**Total: $plugin_count plugins, $plugin_skill_count plugin skills + $user_count user skills + $project_count project skills = $total skills**"
