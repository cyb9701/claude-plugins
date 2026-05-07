#!/usr/bin/env bash
# 보유 스킬 트리 출력기.
#
# 활성 플러그인 + user 영역 + project 영역의 SKILL.md를 스캔해서
# 마크다운 트리로 출력한다. 키워드 인자가 있으면 이름·설명에 포함된 스킬만 필터.
#
# 사용:
#   bash <이 스크립트> [검색어]

set -euo pipefail

SETTINGS="$HOME/.claude/settings.json"
PROJECT_SETTINGS="$PWD/.claude/settings.local.json"
CACHE="$HOME/.claude/plugins/cache"
USER_SKILLS="$HOME/.claude/skills"
PROJECT_SKILLS="$PWD/.claude/skills"
QUERY="${1:-}"

# 공통 함수: SKILL.md를 읽어 한 줄 출력 (필터 통과 시).
# stdout에 마크다운 라인 한 줄을 쓰고, 통과 시 0, 차단 시 1을 반환.
print_skill() {
  local skill_md="$1"
  local label="$2"

  local name desc short
  name=$(awk '/^name:/{ sub(/^name: */,""); gsub(/^"|"$/,""); print; exit }' "$skill_md")
  desc=$(awk '/^description:/{ sub(/^description: */,""); gsub(/^"|"$/,""); print; exit }' "$skill_md")
  [ -z "$name" ] && return 1

  if [ -n "$QUERY" ] && ! printf '%s' "$name $desc $label" | grep -qi -- "$QUERY"; then
    return 1
  fi

  short=$(printf '%s' "$desc" | cut -c1-100)
  [ "${#desc}" -gt 100 ] && short="$short..."
  printf -- "- **%s** — %s\n" "$label" "$short"
  return 0
}

# 영역 1: 활성 플러그인의 enabledPlugins 머지.
enabled=$(
  {
    jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$SETTINGS" 2>/dev/null || true
    [ -f "$PROJECT_SETTINGS" ] && jq -r '.enabledPlugins // {} | to_entries[] | select(.value == true) | .key' "$PROJECT_SETTINGS" 2>/dev/null || true
  } | sort -u
)

plugin_block=""
plugin_count=0
plugin_skill_count=0

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
  # plugin.json에 버전이 없을 때만 디렉토리명 사용. "unknown"은 정보 가치가 없으니 빈 값 유지.
  if [ -z "$version" ] && [ "$latest" != "unknown" ]; then
    version="$latest"
  fi

  [ -d "$root/skills" ] || continue

  block=""
  count=0
  while IFS= read -r skill_md; do
    skill_label=$(basename "$(dirname "$skill_md")")
    if line=$(print_skill "$skill_md" "$skill_label"); then
      block+="$line"$'\n'
      count=$((count + 1))
    fi
  done < <(find "$root/skills" -mindepth 2 -maxdepth 2 -name "SKILL.md" -type f 2>/dev/null | sort)

  if [ "$count" -gt 0 ]; then
    if [ -n "$version" ]; then
      header="### $plugin@$marketplace (v$version)"
    else
      header="### $plugin@$marketplace"
    fi
    plugin_block+=$'\n'"$header"$'\n'"$block"
    plugin_count=$((plugin_count + 1))
    plugin_skill_count=$((plugin_skill_count + count))
  fi
done <<< "$enabled"

# 영역 2: user 영역 스킬 (~/.claude/skills/ 깊이 가변).
user_block=""
user_count=0
if [ -d "$USER_SKILLS" ]; then
  while IFS= read -r skill_md; do
    rel="${skill_md#"$USER_SKILLS/"}"
    rel="${rel%/SKILL.md}"
    if line=$(print_skill "$skill_md" "$rel"); then
      user_block+="$line"$'\n'
      user_count=$((user_count + 1))
    fi
  done < <(find "$USER_SKILLS" -name "SKILL.md" -type f 2>/dev/null | sort)
fi

# 영역 3: 현재 프로젝트의 .claude/skills/ 스킬.
project_block=""
project_count=0
if [ -d "$PROJECT_SKILLS" ]; then
  while IFS= read -r skill_md; do
    rel="${skill_md#"$PROJECT_SKILLS/"}"
    rel="${rel%/SKILL.md}"
    if line=$(print_skill "$skill_md" "$rel"); then
      project_block+="$line"$'\n'
      project_count=$((project_count + 1))
    fi
  done < <(find "$PROJECT_SKILLS" -name "SKILL.md" -type f 2>/dev/null | sort)
fi

# 출력 조립.
total=$((plugin_skill_count + user_count + project_count))
echo "# 보유 스킬 트리 ($plugin_count plugins, $user_count user, $project_count project, total: $total skills)"
[ -n "$QUERY" ] && echo "(검색어: \"$QUERY\")"

echo ""
echo "## 🔌 Plugins (활성)"
if [ -n "$plugin_block" ]; then
  printf '%s' "$plugin_block"
else
  echo "(매칭 결과 없음)"
fi

echo ""
echo "## 👤 User Skills (~/.claude/skills/)"
if [ -n "$user_block" ]; then
  printf '%s' "$user_block"
else
  echo "(매칭 결과 없음)"
fi

echo ""
echo "## 📁 Project Skills ($PWD/.claude/skills/)"
if [ -n "$project_block" ]; then
  printf '%s' "$project_block"
else
  echo "(현재 프로젝트에 스킬이 없습니다.)"
fi

echo ""
echo "**총: $plugin_count plugins, $plugin_skill_count plugin skills + $user_count user skills + $project_count project skills = $total skills**"
