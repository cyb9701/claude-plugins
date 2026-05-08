---
description: >
  활성 플러그인 + user + project 영역의 스킬을 트리로 표시.
  첫 인자로 언어 코드(en, ko, ja, zh, fr ...) 전달 시 Description을 해당 언어로 번역.
argument-hint: "[lang(en|ko|ja|...)] [검색어]"
allowed-tools: Read, Glob
---

Arguments: "$ARGUMENTS"

다음 절차를 따라 skill 트리를 마크다운 테이블로 출력하세요. **Bash 도구는 사용하지 말고 Read와 Glob 도구만 사용**하세요. 이는 권한 prompt를 발생시키지 않기 위함입니다.

## 1. 인자 파싱

"$ARGUMENTS"의 첫 단어(공백 분리)가 다음 ISO 언어 코드 중 하나면 `LANG`으로 분리하고 나머지를 `QUERY`로 사용:
`en, ko, ja, zh, fr, de, es, pt, ru, it, ar`

매칭 안 되면 `LANG=""`, `QUERY="$ARGUMENTS"` (전체).

## 2. 데이터 수집

### 2-1. 활성 플러그인 식별

- Read `~/.claude/settings.json` → JSON으로 파싱 → `enabledPlugins`에서 value가 `true`인 모든 키 추출 (형식: `plugin@marketplace`)
- (있다면) Read `./.claude/settings.local.json` → 동일하게 추출 → 합쳐서 unique한 목록 생성

### 2-2. 플러그인의 SKILL.md 파일 수집

각 `plugin@marketplace`에 대해:
- Glob 패턴: `/Users/cyb/.claude/plugins/cache/<marketplace>/<plugin>/*/skills/**/SKILL.md`
- 만약 여러 버전 디렉토리가 매칭되면 디렉토리 이름이 가장 큰(latest) 것의 파일들만 사용

### 2-3. User 스킬

Glob 패턴: `/Users/cyb/.claude/skills/**/SKILL.md`

### 2-4. Project 스킬

Glob 패턴: `./.claude/skills/**/SKILL.md`

## 3. 각 SKILL.md frontmatter 파싱

각 SKILL.md 파일을 Read (효율을 위해 첫 30줄로 제한). YAML frontmatter에서 추출:
- `name` (없으면 해당 파일은 skip)
- `description` (없으면 빈 문자열)

## 4. QUERY 필터링

QUERY가 비어있지 않으면, name 또는 description에 QUERY를 case-insensitive로 포함하는 항목만 유지.

## 5. 마크다운 테이블 생성

다음 형식으로 출력:

```
# Skill Tree (X plugins, Y user, Z project, total: N skills)
(Search: "QUERY")          ← QUERY가 있을 때만 이 줄 표시

## 🔌 Active Plugins
| Plugin | Skill | Description |
|--------|-------|-------------|
| **plugin-name** | skill-name | description 첫 80자 (초과시 ...) |
|  | another-skill | ... |
| **another-plugin** | skill-name | ... |

## 👤 User  &  📁 Project Skills
| Scope | Skill | Description |
|-------|-------|-------------|
| User | skill-path | ... |
|  | another-user-skill | ... |
| Project | skill-path | ... |

**Total: X plugins, P plugin skills + Y user skills + Z project skills = N skills**
```

### 출력 규칙

- 각 플러그인 그룹의 **첫 번째 행에만** `**plugin-name**` 볼드 표시. 같은 플러그인의 두 번째 행부터는 Plugin 컬럼 빈 셀.
- User 영역도 마찬가지로 첫 행에만 `User`, 이후는 빈 셀. Project도 동일.
- description은 80자 초과 시 `...`를 붙임.
- description 안의 `|` 문자는 `\|`로 escape.
- Skill 이름 정렬: 알파벳 오름차순.
- 활성 플러그인이 없거나 매칭이 0개면 `(no matches)` 또는 `(no active plugin skills)` 표시.

## 6. LANG 처리 (선택)

`LANG`이 비어있지 않으면 마크다운 테이블의 **Description 컬럼 값만** 해당 언어로 번역. Plugin/Skill/Scope 컬럼은 원문 유지.

## 7. 최종 출력

추가 코멘트나 분석 없이 위 마크다운 테이블만 표시.
