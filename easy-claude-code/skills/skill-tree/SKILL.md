---
name: skill-tree
description: Use when 사용자가 활성 플러그인 + user + project 영역의 모든 스킬 카탈로그를 트리로 조회하거나 키워드로 검색하고자 할 때. "skill tree", "skill list", "스킬 트리", "스킬 목록", "스킬 카탈로그", "/skill-tree" 등의 요청에 사용. 첫 인자로 ISO 언어 코드(en, ko, ja, zh, fr, de, es, pt, ru, it, ar) 전달 시 description을 해당 언어로 번역하여 출력.
model: haiku
allowed-tools: Read, Glob
---

# Skill Tree

활성 플러그인 + user + project 영역의 모든 SKILL.md를 수집하여 마크다운 테이블로 출력하는 스킬.

# ⚠️ 절대 지켜야 할 제약 (위반 시 권한 prompt 발생)

**다음 도구는 절대 호출하지 마세요:**

1. ❌ **Bash 도구** — `find`, `ls`, `cat` 등 어떤 shell 명령도 사용 금지
2. ❌ **Agent / Task / Subagent 호출** — Explore, general-purpose, Plan 등 모든 서브에이전트 위임 금지. 서브에이전트가 자체적으로 Bash를 사용해 권한 prompt가 발생합니다.
3. ❌ **find 명령** (Bash의 일종)

**오직 다음 도구만 직접 사용:**

- ✅ **Read** — 단일 파일 내용 읽기
- ✅ **Glob** — 파일 패턴 매칭

24개 정도의 SKILL.md 파일은 Read와 Glob만으로 충분히 처리 가능합니다. "더 효율적인 방법이 있을 것 같다"는 생각이 들어도 위 제약을 반드시 지키세요.

---

Arguments: "$ARGUMENTS"

# 단계

## 1. 인자 파싱

"$ARGUMENTS"의 첫 단어(공백 분리)가 다음 ISO 언어 코드 중 하나면 `LANG`으로 분리하고 나머지를 `QUERY`로 사용:
`en, ko, ja, zh, fr, de, es, pt, ru, it, ar`

매칭 없으면 `LANG=""`, `QUERY="$ARGUMENTS"` (전체).

## 2. 활성 플러그인 식별 (Read 도구만 사용)

- **Read** `/Users/cyb/.claude/settings.json` → JSON으로 파싱 → `enabledPlugins`에서 value가 `true`인 모든 키 추출 (형식: `plugin@marketplace`)
- (파일이 있다면) **Read** `./.claude/settings.local.json` → 동일하게 추출 → 합쳐서 unique한 목록 생성

## 3. SKILL.md 파일 경로 수집 (Glob 도구만 사용)

### 3-1. 활성 플러그인 스킬
각 `plugin@marketplace`에 대해:
- **Glob** 패턴: `/Users/cyb/.claude/plugins/cache/<marketplace>/<plugin>/*/skills/**/SKILL.md`
- 여러 버전 디렉토리가 매칭되면 디렉토리 이름이 가장 큰(latest) 것의 파일들만 채택

### 3-2. User 스킬
- **Glob** 패턴: `/Users/cyb/.claude/skills/**/SKILL.md`

### 3-3. Project 스킬
- **Glob** 패턴: `./.claude/skills/**/SKILL.md`

## 4. 각 SKILL.md frontmatter 파싱 (Read 도구만 사용)

각 SKILL.md 파일에 대해 **Read** 호출 (효율을 위해 limit=30 옵션 사용 권장). YAML frontmatter에서 추출:
- `name` (없으면 해당 파일 skip)
- `description` (없으면 빈 문자열)

여러 파일을 읽어야 하므로, 가능하면 한 번에 여러 Read 호출을 병렬로 보내세요.

## 5. QUERY 필터링

QUERY가 비어있지 않으면, name 또는 description에 QUERY를 case-insensitive로 포함하는 항목만 유지.

## 6. 마크다운 테이블 출력

```
# Skill Tree (X plugins, Y user, Z project, total: N skills)
(Search: "QUERY")          ← QUERY가 있을 때만 이 줄 표시

## 🔌 Active Plugins
| Plugin | Skill | Description |
|--------|-------|-------------|
| **plugin-name** | skill-name | description 첫 80자 (초과 시 ...) |
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

- 각 플러그인 그룹의 **첫 번째 행에만** `**plugin-name**` 볼드. 같은 플러그인의 두 번째 행부터는 Plugin 컬럼 빈 셀.
- User/Project 영역도 첫 행에만 라벨, 이후는 빈 셀.
- description 80자 초과 시 `...` 추가.
- description 안의 `|` 는 `\|` 로 escape.
- Skill 이름 정렬: 알파벳 오름차순.
- 매칭 0개면 `(no matches)` 표시.

## 7. LANG 처리

`LANG`이 비어있지 않으면 마크다운 테이블의 **Description 컬럼 값만** 해당 언어로 번역. Plugin/Skill/Scope 컬럼은 원문 유지.

## 8. 최종 출력

추가 코멘트나 분석 없이 위 마크다운 테이블만 표시.
