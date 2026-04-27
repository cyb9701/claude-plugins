---
name: crashlytics-to-issue
description: Use when Firebase Crashlytics의 미해결 크래시·ANR을 GitHub Issue로 등록·동기화하거나 이미 close된 이슈의 회귀(regression)를 자동 감지할 때. "crashlytics 이슈 등록", "크래시 GitHub 동기화", "크래시 회귀 감지", "open crashes to issues", "crashlytics regression" 요청에 반드시 사용. Sentry·Bugsnag 등 비-Crashlytics 에러 트래커에는 사용 금지.
model: sonnet
effort: medium
disable-model-invocation: false
---

# crashlytics-to-issue

Firebase Crashlytics의 최근 미해결 오류를 조회해, 아직 GitHub에 등록되지 않은 오류만 Issue로 자동 생성한다. 이미 등록된 오류 중 GitHub 이슈가 close된 후에 새 이벤트가 관측된 경우는 **회귀(regression)** 로 재등록한다.

**배포용 범용 스킬** — 특정 서비스·회사·언어·프레임워크에 종속된 값이 이 문서와 `references/*`에 들어있지 않다. 모든 프로젝트 고유 값은 `config.json`으로 외부화한다.

## Prerequisites

- Firebase MCP 도구군 (`mcp__firebase__*`)
- GitHub CLI (`gh`) 인증 완료
- 첫 실행 시 자동 셋업 대화 진입 — 상세 내용은 `references/installation.md`

## Workflow

총 5단계. 단계 간에는 결과 의존성이 있어 순차 실행이지만, 단계 **내부**에서는 한 어시스턴트 턴 안에 다중 tool_use를 발행해 백엔드 병렬화를 최대한 활용한다.

### Step 1. Firebase MCP 환경 점검

1. `mcp__firebase__*` 도구 가용성 확인. 미가용 시 `references/installation.md`의 설치 가이드로 안내 후 종료.
2. `mcp__firebase__firebase_get_environment` 호출.
   - 이미 인증된 상태면 **재인증하지 않는다** (토큰 TTL 최대화).
   - 만료·미인증 상태일 때만 `mcp__firebase__firebase_login` 호출.

### Step 2. 프로젝트·앱 선택 (첫 실행 + 재설정)

스킬 디렉토리의 `config.json`을 읽는다. 다음 중 하나라도 해당하면 대화형 셋업으로 진입, 그렇지 않으면 바로 Step 3로 건너뛴다.

- `firebase.project_id == null`
- `firebase.apps`가 빈 배열
- 사용자가 `--reconfigure` 플래그 명시

셋업 대화 순서:

1. `mcp__firebase__firebase_list_projects` → AskUserQuestion 단일 선택으로 `project_id` 결정.
2. `mcp__firebase__firebase_list_apps(project_id)` → AskUserQuestion `multiSelect: true`로 조회 대상 앱을 다중 선택 (iOS/Android 복수 대응).
3. AskUserQuestion:
   - `github.repo` — 기본값은 `git remote get-url origin` 파싱 결과. 파싱 실패 시 사용자 입력.
4. 선택된 각 앱에 대해 `app_id`, `platform` (`ios` 또는 `android`), `display_name`, `bundle_id` 또는 `package_name`을 `firebase.apps[]`에 객체로 저장.
5. `last_updated_at`을 현재 ISO 8601 (로컬 타임존 포함)로 기록.

저장 후 Step 3로 진행.

### Step 3. 앱별 서브에이전트 병렬 디스패치 (조회)

선택된 각 앱마다 `Agent({ subagent_type: "general-purpose" })`로 독립 서브에이전트를 병렬 디스패치한다. 동시 실행 상한은 `concurrency.max_parallel_apps` (기본 5). 앱 수가 상한을 초과하면 배치 분할.

메인 세션은 조회 로직을 직접 실행하지 않고 결과 수집만 한다 — 이렇게 해야 앱 수에 비례해 latency가 늘지 않고 context 사용량도 절약된다.

서브에이전트는 단순 fetcher가 아니라 **조회+모듈 추론+심각도 계산+본문 렌더**까지 수행한다. full stack trace와 raw notes는 서브에이전트 컨텍스트에만 남고, 메인은 `{rendered_title, rendered_body, module, severity, tracking_note_number, ...}` 형태의 압축 payload만 받는다.

프롬프트 템플릿·반환 JSON 스키마·통합/회귀 시 body 재가공 규칙은 `references/subagent-contract.md`에 있다. 메인 세션은 그 스키마를 그대로 Step 3.5 분류와 Step 4 발행에 전달한다.

### Step 3.5. 메인 세션 필터링 (등록 대상 선정)

서브에이전트 결과를 모아 `references/filter-rules.md`의 의사코드에 따라 6개 라벨 중 하나로 분류한다: `REGISTER(new)`, `REGISTER(regression)`, `SKIP(already_registered)`, `SKIP(already_fixed)`, `SKIP(closed_not_planned)`, `SKIP(legacy_linked)`. 판정 조건·경계 케이스·`grace` 경계는 전부 해당 reference에 있다.

`grace`는 `config.regression.grace_hours` (기본 1).

**앱 간 통합**: 서로 다른 앱의 이슈 중 `display_name`이 동일하면 GitHub 이슈 1건으로 통합한다(집계·사유 우선순위 규칙은 filter-rules.md의 "Unified Issues" 섹션). 메모는 앱별로 **각각** 기록한다.

### Step 4. GitHub Issue 생성 + Crashlytics 메모 기록

등록 대상마다 아래를 수행한다. 제목·본문·모듈·심각도는 서브에이전트가 이미 렌더해 `rendered_title`, `rendered_body`, `module`, `severity`로 넘겨 준 상태다(상세: `references/subagent-contract.md`). 메인 세션은 통합·회귀일 때만 body를 재가공한다.

1. **통합 이슈 재가공**: 앱 간 통합 대상이면 앱별 `rendered_body`를 합쳐 `event_count`·`impacted_users_count`·버전 범위를 집계·유니온. 메타 주석 블록은 앱별로 append(`<!-- crashlytics_issue_id: ... -->` 복수 줄). 규칙 상세: `references/issue-template.md`의 **Unified Issues**.
2. **회귀 prepend**: `REGISTER(regression)`이면 `rendered_body` 상단에 회귀 경고 블록을 prepend. 필드: `previous_issue_number`, `previous_issue_url`, `closed_at`, `last_seen_at`. 상세: `references/issue-template.md`의 **Regression Rendering**.
3. **라벨 구성**: `default_labels` + `os:{platform}` + `severity:{severity}` + 회귀면 `state:regression`. 조합 규칙·통합 이슈 양쪽 `os:*` 부여·사전 등록 필요 라벨 목록은 `references/issue-template.md`의 **Labels** 섹션.

4. **Issue Type**: `config.github.issue_type`이 `null`이 아니면 `--type` 플래그로 전달(기본 `"Bug"`). `gh v2.63+` 요구, 422는 즉시 실패(조용한 fallback 금지) 등 상세 규약은 `references/issue-template.md`의 **Issue Type** 섹션.

5. **`gh issue create` 병렬 발행** (한 어시스턴트 턴 내 다중 Bash tool_use):

```bash
gh issue create \
  --repo <config.github.repo> \
  --title "<rendered_title>" \
  --body "<rendered_body>" \
  --type "<config.github.issue_type>" \
  --label source:crashlytics \
  --label os:<platform> \
  --label severity:<severity>
  # 회귀 시 추가: --label state:regression
  # 통합 이슈: --label os:ios --label os:android 둘 다
```

6. 응답 URL에서 이슈 번호를 추출해 다음 단계에 전달.
7. **`mcp__firebase__crashlytics_create_note` 앱별 병렬 발행**: 통합 이슈는 앱 수만큼 발행. 메모 본문은 `references/note-schema.md`의 1줄 포인터 포맷: `[crashlytics-to-issue] #<issue_number> <issue_url>`. 회귀 재등록은 새 이슈 번호로 새 메모를 append(과거 메모는 보존).

**부분 실패 복구**:

- `gh issue create` 실패 → `config.retry.max_attempts` 까지 `config.retry.backoff_seconds`로 지연 후 재시도. **재시도 직전에만** 멱등 가드 실행: `gh issue list --repo <repo> --state all --search "\"crashlytics_issue_id: <issue_id>\" in:body" --json number,url --limit 1`. 매칭되면 기존 이슈를 재사용해 중복 생성을 막는다(제목 문자열·시간 창 의존 없음). 정상 경로에는 이 가드가 걸리지 않아 비용 0.
- 이슈 생성은 성공했는데 메모 기록 실패 → 메모만 재시도. 최종 실패해도 GitHub 이슈는 유지되므로 데이터 손실 없음. 요약표에 `note_failed` 경고.
- 회귀 재등록 시 기존 이슈에 대한 처리는 하지 않는다 (새 이슈 본문 상단에 "Regression from #N" 섹션으로만 참조).

### Step 5. 결과 요약 보고서

프로즈 1~2줄로 전체를 요약:

> 프로젝트 `<project_id>`의 N개 앱을 조회했습니다. 총 M개 미해결 오류 중 신규 a건, 회귀 b건 등록, c건 스킵, 실패 d건.

이어서 마크다운 표로 개별 결과를 나열:

| 상태       | Crashlytics ID | 앱                   | OS      | 오류 요약   | GitHub Issue | 스킵/실패 사유                                  |
| ---------- | -------------- | -------------------- | ------- | ----------- | ------------ | ----------------------------------------------- |
| registered | `<id>`         | `<app_display_name>` | ios     | `<summary>` | [#N](url)    | -                                               |
| regression | `<id>`         | `<app_display_name>` | android | `<summary>` | [#N](url)    | prev #M closed 2026-04-10, last seen 2026-04-20 |
| skipped    | `<id>`         | `<app_display_name>` | ios     | `<summary>` | [#M](url)    | already_registered                              |
| failed     | `<id>`         | `<app_display_name>` | android | `<summary>` | -            | gh 5xx after 3 retries                          |

## 명령행 플래그

| 플래그                | 동작                                                                                                                                |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `--dry-run`           | Step 4 생성·기록을 건너뛰고 등록 예정 이슈의 제목·라벨·본문 요약만 출력. 회귀·필터 판정 로직은 전부 실행됨.                         |
| `--reconfigure`       | 기존 `config.json`의 `firebase.*` 및 `github.*` 값을 무시하고 Step 2 대화형 셋업 재실행. 심각도·모듈 매핑 등 사용자 튜닝 값은 보존. |
| `--repo <owner/repo>` | `config.github.repo` 일회성 오버라이드. config 파일은 수정하지 않음.                                                                |

## 사용 도구

| 도구                                                                | 용도                             |
| ------------------------------------------------------------------- | -------------------------------- |
| `mcp__firebase__firebase_get_environment`                           | 인증 상태 점검                   |
| `mcp__firebase__firebase_login`                                     | 미인증·만료 시 로그인            |
| `mcp__firebase__firebase_list_projects`                             | 프로젝트 목록 조회 (첫 실행 시)  |
| `mcp__firebase__firebase_list_apps`                                 | 앱 목록 조회 (첫 실행 시)        |
| `mcp__firebase__crashlytics_list_events` / `crashlytics_get_report` | 오류 이벤트·리포트 조회          |
| `mcp__firebase__crashlytics_get_issue`                              | 이슈 상세 조회                   |
| `mcp__firebase__crashlytics_list_notes`                             | 메모 조회 (중복·회귀 판정)       |
| `mcp__firebase__crashlytics_create_note`                            | 메모 기록 (Public Contract 포맷) |
| `gh issue create` / `gh issue list`                                 | GitHub 이슈 생성·중복 검색       |
| `Agent(subagent_type: "general-purpose")`                           | 앱별 병렬 조회 서브에이전트      |
| `AskUserQuestion`                                                   | 첫 실행 셋업 대화                |

## 참조 리소스

| 파일                              | 내용                                                |
| --------------------------------- | --------------------------------------------------- |
| `references/installation.md`      | 설치 위치 선택, 첫 실행, 커스터마이징, 트러블슈팅   |
| `references/issue-template.md`    | GitHub 이슈 제목·본문 템플릿, 통합/회귀 렌더링      |
| `references/note-schema.md`       | Crashlytics 메모 **공개 계약(Public Contract)**     |
| `references/severity-rules.md`    | 심각도 자동 매핑 알고리즘과 기본값                  |
| `references/module-inference.md`  | 스택 트레이스 기반 모듈 추론 (언어·프레임워크 중립) |
| `references/filter-rules.md`      | 중복·회귀 판정 의사코드                             |
| `references/subagent-contract.md` | Step 3 서브에이전트 프롬프트·반환 스키마·책임 경계  |

## 설계 원칙 요약

- **하드코딩 제로**: 서비스명·프로젝트 ID·앱 ID·레포지토리·언어별 패턴은 전부 `config.json`으로 외부화.
- **공개 계약**: Crashlytics 메모는 1줄 포인터 포맷으로 공개 계약돼 있다(상세 `references/note-schema.md`). 다른 도구가 읽어서 "이 크래시가 연결된 GitHub 이슈"를 한 줄 정규식으로 추출할 수 있다.
- **점진적 설정**: 첫 실행은 AskUserQuestion으로 최소 값만 받고, 고급 튜닝(`severity_thresholds` 등)은 나중에 `config.json` 직접 편집으로 수행.
- **부분 실패 내성**: 재시도 + 중복 생성 방지 + 메모 실패가 이슈 생성을 막지 않음.
- **앱 수 독립 latency**: 서브에이전트 병렬 디스패치로 조회 단계는 앱 수와 무관하게 일정한 wall-clock에 수렴.
