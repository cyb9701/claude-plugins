---
description: >
  활성 플러그인 + user + project 영역의 스킬을 트리로 표시.
  첫 인자로 언어 코드(en, ko, ja, zh, fr ...) 전달 시 Description을 해당 언어로 번역.
argument-hint: "[lang(en|ko|ja|...)] [검색어]"
---

!ARGS="$ARGUMENTS"; FIRST="${ARGS%% *}"; case "$FIRST" in en|ko|ja|zh|fr|de|es|pt|ru|it|ar) LANG_CODE="$FIRST"; REST="${ARGS#"$FIRST"}"; QUERY="${REST# }";; *) LANG_CODE=""; QUERY="$ARGS";; esac; SCRIPT=$(ls -d ~/.claude/plugins/cache/easy-claude-code/easy-claude-code/*/scripts/skill-tree.sh 2>/dev/null | sort -V | tail -1); if [ -z "$SCRIPT" ]; then echo "Error: easy-claude-code 플러그인이 설치되어 있지 않습니다. 먼저 플러그인을 설치해주세요."; else [ -n "$LANG_CODE" ] && echo "LANG=$LANG_CODE"; bash "$SCRIPT" "$QUERY"; fi

위 출력 처리 규칙:

- 첫 줄이 `LANG=<코드>` 이면: 마크다운 테이블의 **Description 컬럼 값만** 해당 언어로 번역해서 표시. Plugin, Skill 컬럼은 원문 유지. `LANG=<코드>` 줄 자체는 출력하지 말 것.
- 첫 줄이 `LANG=<코드>` 가 아니면: 위 출력을 그대로 표시.

추가 코멘트나 분석 없이 테이블만 표시하세요.
