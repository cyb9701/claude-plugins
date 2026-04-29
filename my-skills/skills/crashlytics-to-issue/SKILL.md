---
name: crashlytics-to-issue
description: Use when Firebase Crashlytics의 미해결 크래시·ANR을 GitHub Issue로 등록·동기화하거나 이미 close된 이슈의 회귀(regression)를 자동 감지할 때. "crashlytics 이슈 등록", "크래시 GitHub 동기화", "크래시 회귀 감지", "open crashes to issues", "crashlytics regression" 요청에 반드시 사용. Sentry·Bugsnag 등 비-Crashlytics 에러 트래커에는 사용 금지.
model: sonnet
effort: medium
disable-model-invocation: true
---

# crashlytics-to-issue

Firebase Crashlytics의 최근 미해결 오류를 조회해, 아직 GitHub에 등록되지 않은 오류만 Issue로 자동 생성한다. 이미 등록된 오류 중 GitHub 이슈가 close된 후에 새 이벤트가 관측된 경우는 **회귀(regression)** 로 재등록한다.

**배포용 범용 스킬** — 프로젝트 고유 값은 모두 `config.json`으로 외부화된다. 사용자별 인스턴스는 `${CLAUDE_PLUGIN_DATA}/crashlytics-to-issue/projects/<PROJECT_KEY>/config.json`(플러그인 업데이트 후에도 보존, **프로젝트별 격리**)에 저장되며, 작성자 기본값은 번들된 `${CLAUDE_SKILL_DIR}/config.json`이다. `<PROJECT_KEY>`는 git remote URL에서 `<owner>-<repo>` 형태로 자동 추출되어, 동일 사용자가 여러 프로젝트를 오갈 때 셋업이 충돌하지 않는다.

## Prerequisites

- Firebase MCP 도구군 (`mcp__firebase__*`)
- GitHub CLI (`gh`) 인증 완료. `gh`는 gojq를 임베드해 `--jq` 플래그를 내장 제공하므로 별도 jq 바이너리 불필요
- `python3` (macOS 12+/Linux/Codespaces 기본 탑재) — 이슈 생성 응답 파싱용. 표준 라이브러리(`json`)만 사용
- 첫 실행 시 자동 셋업 대화 진입 — 상세는 `references/installation.md`

## Workflow

총 5단계. 단계 간에는 결과 의존성이 있어 순차 실행이지만, 단계 **내부**에서는 한 어시스턴트 턴 안에 다중 tool_use를 발행해 백엔드 병렬화를 활용한다.

### Step 1. Firebase MCP 환경 점검

1. `mcp__firebase__*` 도구 가용성 확인. 미가용 시 `references/installation.md`로 안내 후 종료.
2. `mcp__firebase__firebase_get_environment` 호출.
   - 인증 상태면 재인증하지 않는다 (토큰 TTL 최대화).
   - 만료·미인증일 때만 `mcp__firebase__firebase_login`.

### Step 2. 프로젝트·앱 선택 (첫 실행 + 재설정)

**저장 경로 결정 — PROJECT_KEY 추출**: 동일 사용자가 여러 프로젝트를 오갈 때 셋업이 독립 보존되도록, config는 프로젝트별 서브디렉토리에 저장한다. PROJECT_KEY는 다음 우선순위로 추출, 모든 결과는 lowercase로 정규화하고 영숫자·하이픈 외 문자를 `-`로 치환한 뒤 연속 하이픈을 1개로 압축한다.

1. `git remote get-url origin` 성공 시 `<owner>-<repo>` 형태. 예: `https://github.com/cyb9701/claude-plugins.git` → `cyb9701-claude-plugins`
2. 실패 시 `git rev-parse --show-toplevel`의 basename 정규화
3. 둘 다 실패 시 `pwd`의 basename 정규화

**저장 경로**: `${CLAUDE_PLUGIN_DATA}/crashlytics-to-issue/projects/<PROJECT_KEY>/config.json`

해당 경로의 파일을 읽는다. 파일이 없으면 번들된 기본값 `${CLAUDE_SKILL_DIR}/config.json`을 복사해 초기화한다 — 플러그인 업데이트 시 `${CLAUDE_PLUGIN_DATA}`만 보존되므로, 프로젝트별로 격리된 셋업이 유지된다.

**AskUserQuestion 사전 로드**: 셋업 대화에 진입하기 직전, 메인 세션에서 `AskUserQuestion`이 deferred tool 상태(스키마 미로드)이면 `ToolSearch(query="select:AskUserQuestion", max_results=1)`을 1회 발행해 스키마를 로드한다. deferred tool을 그대로 호출하면 `InputValidationError`로 실패하기 때문이다. 이미 로드된 세션에서는 생략(중복 비용 0).

다음 중 하나라도 해당하면 대화형 셋업 진입, 그렇지 않으면 Step 3로 건너뛴다.

- `firebase.project_id == null`
- `firebase.apps`가 빈 배열
- 사용자가 `--reconfigure` 플래그 명시

셋업 대화 순서:

1. `mcp__firebase__firebase_list_projects` → AskUserQuestion 단일 선택으로 `project_id` 결정.
2. `mcp__firebase__firebase_list_apps(project_id)` → AskUserQuestion `multiSelect: true`로 조회 대상 앱 다중 선택 (iOS/Android 복수 대응).
3. AskUserQuestion: `github.repo` — 기본값은 `git remote get-url origin` 파싱 결과. 실패 시 사용자 입력.
4. 선택된 각 앱에 대해 `app_id`, `platform` (`ios`/`android`), `display_name`, `bundle_id`/`package_name`을 `firebase.apps[]`에 객체로 저장.
5. `last_updated_at`을 현재 ISO 8601 (로컬 타임존 포함)로 기록.

저장 후 Step 3로 진행.

### Step 3. 앱별 서브에이전트 병렬 디스패치 (조회)

선택된 각 앱마다 `Agent({ subagent_type: "general-purpose" })`로 독립 서브에이전트를 병렬 디스패치한다. 동시 실행 상한은 `concurrency.max_parallel_apps` (기본 5). 앱 수가 상한을 초과하면 배치 분할.

메인 세션은 조회 로직을 직접 실행하지 않고 결과 수집만 한다 — 앱 수에 비례해 latency가 늘지 않고 context 사용량도 절약된다.

서브에이전트는 단순 fetcher가 아니라 **조회+모듈 추론+심각도 계산+본문 렌더**까지 수행한다. full stack trace·variants·custom*keys·breadcrumbs·logs·top*_ 분포 데이터는 서브에이전트 컨텍스트에만 남고, 메인은 `{rendered*body, module, title_summary, severity, tracking_note_number, has*_, ...}` 형태의 압축 payload만 받는다. **`rendered_title`은 더 이상 반환하지 않는다** — 제목 prefix 일관성 보장을 위해 메인 세션이 Step 4에서 직접 조립한다(상세: `references/issue-template.md#Ownership`).

프롬프트 템플릿·반환 JSON 스키마·통합/회귀 시 body 재가공 규칙은 `references/subagent-contract.md`에 있다.

### Step 3.5. 메인 세션 필터링 (등록 대상 선정)

서브에이전트 결과를 모아 `references/filter-rules.md`의 의사코드에 따라 7개 라벨 중 하나로 분류: `REGISTER(new)`, `REGISTER(regression)`, `SKIP(already_registered)`, `SKIP(already_fixed)`, `SKIP(closed_not_planned)`, `SKIP(legacy_linked)`, `CLOSE_CRASHLYTICS(outdated_version)`. 판정 조건·경계 케이스·버전 비교 fallback은 해당 reference 참조.

핵심 규칙 한 줄: **닫힌 GitHub 이슈 본문의 `max_app_version`보다 Crashlytics 새 이벤트의 `max_app_version`이 크면** `REGISTER(regression)`, **같거나 작으면** `CLOSE_CRASHLYTICS(outdated_version)`.

**앱 간 통합**: 서로 다른 앱의 이슈 중 `display_name`이 동일하면 GitHub 이슈 1건으로 통합. 사유 우선순위는 `regression > new > already_registered > close_crashlytics > already_fixed > closed_not_planned > legacy_linked`. 메모·close 액션은 앱별로 **각각** 수행.

### Step 4. GitHub Issue 생성 + Crashlytics 메모 기록

등록 대상마다 아래를 수행한다. 본문·모듈·심각도·제목용 raw 필드는 서브에이전트가 이미 처리해 `rendered_body`, `module`, `title_summary`, `severity`로 넘겨 준 상태다. **제목 자체는 메인 세션이 직접 조립한다** — LLM 서브에이전트가 만든 `rendered_title`에 의존하면 prefix 누락·변형 가능성이 있어, Bash 변수 한 줄로 강제 prepend한다.

1. **제목 조립 (메인 세션 책임)**: 다음 한 줄로 항상 동일한 형식을 보장.

   ```bash
   MODULE="${module:-${error_type}}"
   TSUMMARY="${title_summary:-${display_name:0:80}}"
   RENDERED_TITLE="[Firebase Crashlytics] ${MODULE} - ${TSUMMARY}"
   ```

   fallback(`module → error_type`, `title_summary → display_name 80자`)으로 raw 필드가 비어도 깨지지 않으며, **어떤 경우에도 `[Firebase Crashlytics] ` prefix는 보장**된다.

2. **통합 이슈 재가공**: 앱 간 통합 대상이면 앱별 `rendered_body`를 합쳐 `event_count`·`impacted_users_count`·버전 범위를 집계·유니온하고, `Top Devices`/`Top OS Versions`/`Top App Versions`/`Top Regions`/`Variants`/`Custom Keys`/`Breadcrumbs`/`Logs` 섹션은 앱별 분기로 표기. 메타 주석 블록은 앱별로 append. 규칙은 `references/issue-template.md`의 **Unified Issues**.

3. **회귀 prepend**: `REGISTER(regression)`이면 `rendered_body` 상단에 회귀 경고 블록을 prepend. 필드는 분류 결과 `context`에서 주입 (`references/issue-template.md`의 **Regression Rendering**).

4. **라벨 구성**: `default_labels` + `os:{platform}` + `severity:{severity}` + 회귀면 `state:regression`. 통합 이슈는 `os:ios`+`os:android` 양쪽 부여. 사전 등록 필요 라벨 목록은 `references/issue-template.md`의 **Labels**.

5. **`gh api` REST 호출** (한 어시스턴트 턴 내 다중 Bash tool_use). `gh issue create`는 type 등 일부 필드 한계가 있어 REST 엔드포인트를 직접 호출한다. **⚠️ 보안 핵심: placeholder는 절대 텍스트 치환으로 명령에 끼워 넣지 않는다 — bash 변수로만 통과시켜 `gh`의 `-f`/`-F` form 인자에 넘긴다.** 외부 입력(Crashlytics display_name·stack_trace 등)의 따옴표·`$(...)` 등 shell 메타문자를 데이터로만 보존하기 위함이다. **완성된 Bash 패턴은 `references/issue-template.md`의 "Safe Issue Creation Call"** 참조. 메인 세션은 환경 변수(`RENDERED_TITLE`, `RENDERED_BODY`, `REPO`, `PLATFORM`, `SEVERITY`, `IS_REGRESSION`, `IS_UNIFIED`)만 채워 그대로 실행한다.

6. 호출 결과로 얻은 `ISSUE_URL`·`ISSUE_NUMBER`를 다음 단계에 전달.

7. **`mcp__firebase__crashlytics_create_note` 앱별 병렬 발행**: 통합 이슈는 앱 수만큼 발행. 메모 본문은 `references/note-schema.md`의 1줄 포인터 포맷: `[crashlytics-to-issue] #<issue_number> <issue_url>`. 회귀 재등록은 새 이슈 번호로 새 메모를 append(과거 메모 보존).

**부분 실패 복구**:

- 멱등 키는 본문 메타 주석 `<!-- crashlytics_issue_id: <id> -->`. 재시도 직전 1회만 검색해 중복 생성을 차단한다.
- 이슈 생성 성공 + 메모 기록 실패 → 메모만 재시도. GitHub 이슈는 보존되므로 데이터 손실 없음. 요약표에 `note_failed` 경고.
- 회귀 재등록은 새 이슈 본문 상단의 "Regression from #N" 참조로만 처리 — 기존 이슈는 건드리지 않는다.

### Step 4-bis. CLOSE_CRASHLYTICS(outdated_version) 처리

`CLOSE_CRASHLYTICS` 분류된 이슈는 GitHub을 건드리지 않고 Firebase 측에만 액션한다. `mcp__firebase__crashlytics_update_issue` (state=`CLOSED`)를 직접 호출한다.

분류 단계에서 `config.regression.auto_close == false`면 미리 `auto_close_skipped`로 다운그레이드되어 본 단계가 실행되지 않는다(아래 **"다운그레이드 진입점"** 참조). 런타임 close 호출 실패는 별개의 경로로 처리되며 `failed: firebase_close_failed`로 결과 표에 표기된다(아래 **"부분 실패 복구"** 참조). 두 경로는 서로 변환되지 않는다.

한 어시스턴트 턴에서 두 호출을 병렬로 발행:

1. **상태 변경**: `mcp__firebase__crashlytics_update_issue` 를 `state="CLOSED"`로 호출.
2. **감사 메모**: `mcp__firebase__crashlytics_create_note`로 auto-close 메모 append:
   ```
   [crashlytics-to-issue] auto-closed: outdated_version v<crashlytics_max_version> <= closed #<previous_issue_number> v<closed_issue_max_version>
   ```
   상세는 `references/note-schema.md`의 **Auto-close Note Format**.
3. GitHub 이슈는 수정하지 않는다 (이미 close 상태이므로 부수효과 없음).

**부분 실패 복구**:

- 상태 변경 실패 → `config.retry.max_attempts`까지 재시도. 마지막까지 실패하면 결과 표에 `failed: firebase_close_failed` + 사유 표기. 다음 실행에서 다시 시도(이슈는 여전히 OPEN이므로 멱등).
- 상태 변경 성공·메모 실패 → 메모만 재시도. 결과 표에 `note_failed` 경고. 다음 실행 때 이슈는 OPEN이 아니므로 재처리되지 않음(데이터 손실 없음, 감사 로그만 누락).

**다운그레이드 진입점**: 분류 단계에서 `config.regression.auto_close == false`이면 `CLOSE_CRASHLYTICS`가 `SKIP(already_fixed, warning="auto_close_skipped")`로 변환된다(상세 의사코드는 `references/filter-rules.md`의 `classify()` 끝부분). 분류 결과가 확정된 뒤의 런타임 close 호출 실패는 위 **"부분 실패 복구"** 경로를 따른다 — `auto_close_skipped`로 사후 변환되지 않는다.

**`--dry-run`**: 두 호출 모두 스킵, 출력에만 `would close` 표기.

### Step 5. 결과 요약 보고서

프로즈 1~2줄로 전체 요약:

> 프로젝트 `<project_id>`의 N개 앱을 조회했습니다. 총 M개 미해결 오류 중 신규 a건·회귀 b건 등록, 자동 close c건, 스킵 d건, 실패 e건.

이어서 마크다운 표로 개별 결과:

| 상태               | Crashlytics ID | 앱                   | OS      | 오류 요약   | GitHub Issue | 사유 / 비교 결과                                |
| ------------------ | -------------- | -------------------- | ------- | ----------- | ------------ | ----------------------------------------------- |
| registered         | `<id>`         | `<app_display_name>` | ios     | `<summary>` | [#N](url)    | -                                               |
| regression         | `<id>`         | `<app_display_name>` | android | `<summary>` | [#N](url)    | prev #M v1.0.3, crashlytics v1.0.4 (regression) |
| skipped            | `<id>`         | `<app_display_name>` | ios     | `<summary>` | [#M](url)    | already_registered                              |
| skipped            | `<id>`         | `<app_display_name>` | ios     | `<summary>` | [#K](url)    | warning: auto_close_skipped                     |
| closed_crashlytics | `<id>`         | `<app_display_name>` | android | `<summary>` | [#K](url)    | crashlytics v1.0.3 ≤ closed #K v1.0.3           |
| failed             | `<id>`         | `<app_display_name>` | android | `<summary>` | -            | gh 5xx after 3 retries / firebase_close_failed  |

## 명령행 플래그

| 플래그                | 동작                                                                                                                                |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `--dry-run`           | Step 4 / Step 4-bis의 생성·기록·close 호출을 모두 건너뛰고 분류 결과·등록 예정 이슈 요약만 출력. 회귀·필터 판정 로직은 전부 실행됨. |
| `--reconfigure`       | 기존 `config.json`의 `firebase.*` 및 `github.*` 값을 무시하고 Step 2 대화형 셋업 재실행. 사용자 튜닝 값(severity 등)은 보존.        |
| `--repo <owner/repo>` | `config.github.repo` 일회성 오버라이드. config 파일은 수정하지 않음.                                                                |

## 사용 도구

| 도구                                                                            | 용도                                                           |
| ------------------------------------------------------------------------------- | -------------------------------------------------------------- |
| `mcp__firebase__firebase_get_environment` / `firebase_login`                    | 인증 상태 점검·로그인                                          |
| `mcp__firebase__firebase_list_projects` / `firebase_list_apps`                  | 셋업 시 프로젝트·앱 목록 조회                                  |
| `mcp__firebase__crashlytics_list_events` / `crashlytics_get_report`             | 오류 이벤트·리포트 조회                                        |
| `mcp__firebase__crashlytics_get_issue`                                          | 이슈 상세 조회                                                 |
| `mcp__firebase__crashlytics_list_notes` / `crashlytics_create_note`             | 메모 조회·기록 (tracking + auto-close 포맷)                    |
| `mcp__firebase__crashlytics_update_issue`                                       | 이슈 상태 변경 (`CLOSE_CRASHLYTICS` 처리)                      |
| `gh api -X POST repos/.../issues` / `gh issue list --jq` / `gh issue view --jq` | GitHub 이슈 생성(REST) · 중복 검색 · 본문 조회. 외부 jq 불필요 |
| `python3` (표준 라이브러리 `json`만)                                            | 이슈 생성 응답 본문 파싱                                       |
| `Agent(subagent_type: "general-purpose")`                                       | 앱별 병렬 조회 서브에이전트                                    |
| `AskUserQuestion`                                                               | 첫 실행 셋업 대화                                              |

## 참조 리소스

| 파일                              | 내용                                                |
| --------------------------------- | --------------------------------------------------- |
| `references/installation.md`      | 설치 위치, 첫 실행, 커스터마이징, 트러블슈팅        |
| `references/issue-template.md`    | GitHub 이슈 제목·본문 템플릿, 통합/회귀 렌더링      |
| `references/note-schema.md`       | Crashlytics 메모 포맷                               |
| `references/severity-rules.md`    | 심각도 자동 매핑 알고리즘과 기본값                  |
| `references/module-inference.md`  | 스택 트레이스 기반 모듈 추론 (언어·프레임워크 중립) |
| `references/filter-rules.md`      | 중복·회귀 판정 의사코드                             |
| `references/subagent-contract.md` | Step 3 서브에이전트 프롬프트·반환 스키마            |

## 설계 원칙 요약

- **영구 설정 분리 + 프로젝트 격리**: 사용자 셋업은 `${CLAUDE_PLUGIN_DATA}/.../<PROJECT_KEY>/`에, 작성자 기본값은 `${CLAUDE_SKILL_DIR}/config.json`에 분리. PROJECT_KEY는 git remote URL의 `<owner>-<repo>` 형태로 자동 추출되어 여러 프로젝트의 셋업이 격리된다.
- **하드코딩 제로**: 프로젝트 ID·앱 ID·레포지토리 등 모든 환경값은 `config.json`으로 외부화.
- **부분 실패 내성**: 재시도 + 멱등 가드(`crashlytics_issue_id` 메타 주석) + 메모 실패가 이슈 생성을 막지 않음.
- **앱 수 독립 latency**: 서브에이전트 병렬 디스패치로 조회 단계는 앱 수와 무관하게 일정한 wall-clock에 수렴.
