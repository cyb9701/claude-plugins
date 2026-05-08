---
name: skill-tree
description: Use when 사용자가 활성 플러그인 + user + project 영역의 모든 스킬 카탈로그를 트리로 조회하거나 키워드로 검색하고자 할 때. "skill tree", "skill list", "스킬 트리", "스킬 목록", "스킬 카탈로그", "/skill-tree" 등의 요청에 사용. 첫 인자로 ISO 언어 코드(en, ko, ja, zh, fr, de, es, pt, ru, it, ar) 전달 시 description을 해당 언어로 번역하여 출력.
model: sonnet
allowed-tools: Bash(python3 *)
---

# Skill Tree

활성 플러그인·user·project 영역의 모든 스킬을 마크다운 테이블로 출력합니다. 모든 스캔·파싱·정렬·필터링은 동봉된 Python 스크립트가 처리합니다. 이 스킬은 **Bash 한 번** 외의 도구를 절대 호출하지 마세요.

Arguments: $ARGUMENTS

## 흐름

### 1. 인자 분리

`$ARGUMENTS`의 첫 단어가 ISO 언어 코드(`en`, `ko`, `ja`, `zh`, `fr`, `de`, `es`, `pt`, `ru`, `it`, `ar`) 중 하나면 `LANG`으로 분리하고, 나머지를 `QUERY`로 둡니다. 매칭이 안 되면 `LANG=""`, `QUERY="$ARGUMENTS"`.

### 2. 카탈로그 생성 (단 한 번의 도구 호출)

다음 Bash 명령을 정확히 한 번만 실행하고 stdout을 받습니다. **다른 도구나 다른 명령은 절대 호출하지 마세요.**

```bash
python3 "${CLAUDE_SKILL_DIR}/list-skills.py" "<QUERY>"
```

`<QUERY>`는 1단계에서 추출한 값으로 치환합니다 (빈 문자열도 그대로 전달). 셸 인용 부호 안에 들어가므로 공백·특수문자 그대로 사용해도 안전합니다.

### 3. 출력

- `LANG`이 비어 있으면 → stdout을 **그대로** 표시합니다. 추가 코멘트, 요약, 분석 금지.
- `LANG`이 있으면 → stdout 마크다운 테이블의 **Description 컬럼 값만** `LANG` 언어로 번역해서 출력합니다. Plugin / Skill / Scope 컬럼, 헤더, 합계 줄은 원문 유지. 번역은 텍스트 변환일 뿐 추가 도구 호출이 필요하지 않습니다.

## 절대 금지

- ❌ `Bash(python3 ...)` 외의 도구 호출 (Read, Glob, Grep, Agent, find, ls, cat 모두 금지).
- ❌ 위 Bash 명령 외에 다른 셸 명령 추가 실행.
- ❌ stdout을 임의로 잘라내거나 요약.
- ❌ 분석 결과나 사용 안내 같은 부가 텍스트 덧붙이기.

이 스킬의 모든 로직은 Python 스크립트 하나에 응축되어 있습니다. SKILL.md의 역할은 **단일 명령을 한 번 실행하고 출력을 그대로 보여주는 것** 뿐입니다.
