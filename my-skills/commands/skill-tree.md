---
description: 활성 플러그인 + user + project 영역의 스킬을 트리로 표시
argument-hint: "[검색어]"
allowed-tools: Bash(bash:*), Bash(jq:*), Bash(find:*), Bash(ls:*), Bash(awk:*), Bash(sort:*)
---

활성 플러그인의 스킬과 user/project 영역의 스킬 목록을 출력합니다.

다음 스크립트를 실행하고, 출력 결과를 그대로(추가 코멘트나 분석 없이) 사용자에게 보여주세요.

!`bash ~/.claude/plugins/cache/choi-claude-plugins/my-skills/$(ls -v ~/.claude/plugins/cache/choi-claude-plugins/my-skills 2>/dev/null | tail -1)/scripts/skill-tree.sh "$ARGUMENTS"`
