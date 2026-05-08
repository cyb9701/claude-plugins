---
description: List all skills across active plugins, user, and project as a markdown table. First argument may be an ISO language code (en, ko, ja, zh, fr, de, es, pt, ru, it, ar) to translate descriptions; remaining arguments filter by keyword.
allowed-tools: Bash(python3 *)
---

!`python3 "${CLAUDE_PLUGIN_ROOT}/scripts/list-skills.py" $ARGUMENTS`

위 출력은 이미 완성된 마크다운 테이블입니다.

- `$ARGUMENTS`의 첫 단어가 ISO 언어 코드(`en`, `ko`, `ja`, `zh`, `fr`, `de`, `es`, `pt`, `ru`, `it`, `ar`) 중 하나면 → 위 테이블의 **Description 컬럼 값만** 그 언어로 번역해서 다시 출력하세요. Plugin/Skill/Scope 컬럼·헤더·합계 줄은 원문 유지.
- 그 외에는 위 출력을 **한 글자도 바꾸지 말고 그대로** 표시하세요.
- 어떤 도구도 추가로 호출하지 마세요 (결과는 이미 위에 박혀 있습니다).
- 추가 코멘트, 요약, 분석, 사용 안내 텍스트 일절 금지.
