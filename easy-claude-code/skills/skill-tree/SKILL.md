---
name: skill-tree
description: Use when 사용자가 활성 플러그인 + user + project 영역의 모든 스킬 카탈로그를 트리로 조회하거나 키워드로 검색하고자 할 때. "skill tree", "skill list", "스킬 트리", "스킬 목록", "스킬 카탈로그", "/skill-tree" 등의 요청에 사용. 첫 인자로 ISO 언어 코드(en, ko, ja, zh, fr, de, es, pt, ru, it, ar) 전달 시 description을 해당 언어로 번역하여 출력.
allowed-tools: Bash(python3 *)
---

# Skill Tree

아래 카탈로그는 스킬 호출 시점에 하네스가 미리 실행한 Python 스크립트의 출력입니다. 추가 도구 호출은 절대 하지 마세요.

!`python3 "${CLAUDE_SKILL_DIR}/list-skills.py" $ARGUMENTS`

## 출력 규칙

- `$ARGUMENTS`의 첫 단어가 ISO 언어 코드(`en`, `ko`, `ja`, `zh`, `fr`, `de`, `es`, `pt`, `ru`, `it`, `ar`) 중 하나면 → 위 마크다운 테이블의 **Description 컬럼 값만** 그 언어로 번역해 다시 출력하세요. Plugin / Skill / Scope 컬럼·헤더·합계 줄은 원문 유지.
- 그 외에는 위 출력을 한 글자도 변경하지 말고 **그대로** 표시하세요.
- 추가 코멘트, 요약, 분석, 사용 안내 텍스트 일절 금지.
- 어떤 도구도 추가로 호출하지 마세요. 결과는 이미 위에 박혀 있습니다.
