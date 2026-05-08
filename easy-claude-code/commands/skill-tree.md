---
description: >
  활성 플러그인 + user + project 영역의 스킬을 트리로 표시.
  첫 인자로 언어 코드(en, ko, ja, zh, fr ...) 전달 시 Description을 해당 언어로 번역.
argument-hint: "[lang(en|ko|ja|...)] [검색어]"
allowed-tools: Bash(bash:*)
---

Arguments: "$ARGUMENTS"

다음 순서로 처리하세요:

1. **인자 파싱** — "$ARGUMENTS"의 첫 단어가 2~3자리 ISO 언어 코드(en, ko, ja, zh, fr, de, es, pt, ru, it, ar 등)이면 `LANG`으로 분리하고 나머지를 `QUERY`로 사용. 아니면 전체를 `QUERY`로 처리.

2. **스크립트 실행** — 결정된 QUERY로 Bash 도구를 사용해 실행:
   ```bash
   SCRIPT=$(ls -d ~/.claude/plugins/cache/easy-claude-code/easy-claude-code/*/scripts/skill-tree.sh 2>/dev/null | sort -V | tail -1)
   if [ -z "$SCRIPT" ]; then
     echo "Error: easy-claude-code 플러그인이 설치되어 있지 않습니다. 먼저 플러그인을 설치해주세요." >&2
     exit 1
   fi
   bash "$SCRIPT" "QUERY"
   ```

3. **출력 처리**:
   - `LANG` 없음: 스크립트 출력을 그대로 표시.
   - `LANG` 있음: 마크다운 테이블의 **Description 컬럼 값만** 해당 언어로 번역. Plugin, Skill 컬럼은 원문 유지. 번역된 테이블을 표시.

4. 추가 코멘트나 분석 없이 테이블만 표시하세요.
