---
name: crashlytics-issue-to-fix
description: Use when fixing Firebase Crashlytics-linked GitHub Issues (or general bugs sharing the same label) by analyzing them in isolated git worktrees, generating one independent PR per issue, then batch-reviewing, merging, and synchronously closing both the GitHub Issue and the Crashlytics issue in one cycle. Triggers on "fix crashlytics issue", "auto-fix from issue", "issue to fix", "close crashlytics issue with PR", "worktree-based issue fix". Invoke even when only a single issue number is specified. Works standalone on plain bug-label issues; if a sibling skill registers Crashlytics issues into GitHub with HTML metadata comments, those comments are consumed for automatic Crashlytics-side closure.
model: opus
effort: xhigh
disable-model-invocation: true
---

# crashlytics-issue-to-fix

GitHub Issue로 적재된 Firebase Crashlytics 오류를 워크트리 격리 환경에서 **이슈마다 독립된 PR**로 자동 분석·수정·생성한 뒤, 사용자의 일괄 검토 후 머지하고 GitHub Issue·Crashlytics를 PR 단위로 종결한다.

프로젝트 고유 값(서비스명·프로젝트 ID·앱 ID·레포·라벨·워크트리 초기화 명령)은 전부 `config.json`으로 외부화한다 — SKILL.md 본문과 `references/*`에는 하드코딩하지 않는다. 사용자별 인스턴스는 `${CLAUDE_PLUGIN_DATA}/crashlytics-issue-to-fix/projects/<PROJECT_KEY>/config.json`(플러그인 업데이트 후에도 보존되는 영구 저장소, **프로젝트별 격리**)에 위치하고, 작성자가 제공하는 기본값 템플릿은 번들된 `${CLAUDE_SKILL_DIR}/config.json`이다. `<PROJECT_KEY>`는 호출 시점에 git remote URL에서 `<owner>-<repo>` 형태로 자동 추출되어, 동일 사용자가 여러 프로젝트를 오갈 때 각 프로젝트의 셋업이 서로 충돌하지 않는다(추출 로직은 Step 2 참고).

## Prerequisites

- Firebase MCP 도구군 (`mcp__firebase__*`)
- GitHub CLI (`gh`) 인증 완료
- git 2.5 이상 (worktree 지원)
- 첫 실행 시 자동 셋업 대화 진입 — 상세 내용은 `references/installation.md`

## Workflow

총 6단계. 단계 간 의존성으로 순차 실행. Step 5는 승인된 이슈 수만큼 사이클을 반복하며, 각 사이클은 자기만의 독립 워크트리·브런치·PR을 가진다.

**사이클 모델**: 각 이슈는 `origin/<BASE_BRANCH>`의 최신 SHA에서 출발한 **fresh 워크트리**(`fix/issue-<issue_id>`)에서 처리된다. 이슈 1건 = 워크트리 1개 = 브런치 1개 = PR 1개. 사이클 간 의존성이 없으며, Step 6에서 모든 PR을 한 번의 분기점으로 모아 일괄 검토·머지한다. 한 PR이 막혀도 나머지는 진행된다는 점이 핵심이다.

### Step 1. Firebase MCP 환경 점검

1. `mcp__firebase__*` 도구 가용성 확인. 미가용 시 `references/installation.md`의 설치 가이드로 안내 후 종료.
2. `mcp__firebase__firebase_get_environment` 호출.
   - 이미 인증된 상태면 **재인증하지 않는다** (토큰 TTL 최대화).
   - 만료·미인증 상태일 때만 `mcp__firebase__firebase_login` 호출.

### Step 2. 프로젝트·앱·GitHub 셋업 (첫 실행 또는 `--reconfigure`)

**저장 경로 결정 — PROJECT_KEY 추출**: 동일 사용자가 여러 프로젝트를 오갈 때 각 프로젝트의 Firebase·repo·라벨 셋업이 독립 보존되도록, config는 프로젝트별 서브디렉토리에 저장한다. PROJECT_KEY는 다음 우선순위로 추출하며, 모든 결과는 lowercase로 정규화하고 영숫자·하이픈 외 문자를 `-`로 치환한 뒤 연속 하이픈을 1개로 압축한다.

1. `git remote get-url origin`이 성공하면 URL을 파싱해 `<owner>-<repo>` 형태로 변환. 예: `https://github.com/cyb9701/claude-plugins.git` 또는 `git@github.com:cyb9701/claude-plugins.git` → `cyb9701-claude-plugins`
2. 실패 시 `git rev-parse --show-toplevel`의 basename 정규화 (예: `/Users/cyb/dev/myapp` → `myapp`)
3. 둘 다 실패 시 `pwd`의 basename 정규화

**저장 경로**: `${CLAUDE_PLUGIN_DATA}/crashlytics-issue-to-fix/projects/<PROJECT_KEY>/config.json`

해당 경로의 파일을 읽는다. 파일이 없으면 번들된 기본값 `${CLAUDE_SKILL_DIR}/config.json`을 복사해 초기화한다 — 플러그인 업데이트 시 `${CLAUDE_PLUGIN_DATA}`만 보존되며, 프로젝트별로 격리된 셋업이 유지된다. 다음 중 하나라도 해당하면 대화형 셋업으로 진입, 그렇지 않으면 Step 3로 건너뛴다.

- `firebase.project_id == null`
- `firebase.apps`가 빈 배열
- `github.repo == null`
- `github.issue_label == null`
- `github.pr_labels == null` (필드가 아예 없는 경우. 빈 배열 `[]`은 사용자가 의도적으로 라벨 추가를 비활성화한 상태로 간주하므로 재진입 트리거가 아니다)
- 사용자가 `--reconfigure` 플래그 명시

셋업 대화 순서:

1. `mcp__firebase__firebase_list_projects` → AskUserQuestion 단일 선택으로 `project_id` 결정.
2. `mcp__firebase__firebase_list_apps(project_id)` → AskUserQuestion `multiSelect: true`로 조회 대상 앱을 다중 선택 (iOS/Android 복수 대응).
3. AskUserQuestion으로 `github.repo` 입력. 기본값은 `git remote get-url origin` 파싱 결과(`owner/repo`). 파싱 실패 시 사용자 직접 입력.
4. AskUserQuestion으로 `github.issue_label` 입력. "어떤 라벨이 붙은 이슈를 처리할까요?"라고 묻고 단일 라벨명을 받는다. 라벨명은 환경마다 컨벤션이 달라(`bug`·`crashlytics`·`type:bug`·국문 라벨 등) 본 스킬이 어떤 후보도 가정하지 않는다 — 사용자 환경의 실제 라벨명을 직접 입력받는다.
5. **PR 라벨 선택**: 본 스킬이 생성하는 PR에 자동으로 부착할 라벨을 사용자 레포의 **실제 등록 라벨 중에서만** 받는다. 라벨명을 본문에 박아두면 다양한 사용자 환경에 부합하지 못하므로, 매 셋업마다 GitHub에서 동적으로 조회한다.
   1. `gh label list --repo <github.repo> --json name,description --limit 100` 호출. (네트워크·권한 문제로 실패하면 사용자에게 보고 후 빈 배열 `[]`을 저장하고 다음 단계로 진행 — 라벨 부착은 PR 생성의 부수적 기능이라 셋업을 막지 않는다.)
   2. 결과가 0건이면 "사용자 레포에 등록된 라벨이 없습니다. 필요하면 `gh label create`로 등록 후 `--reconfigure`로 재셋업하세요."를 안내하고 빈 배열로 저장.
   3. 결과가 1건 이상이면 AskUserQuestion `multiSelect: true`로 0개 이상 선택받는다. 옵션 라벨명에 description이 있으면 보조 텍스트로 같이 노출해 사용자 결정을 돕는다.
   4. 선택 결과를 `github.pr_labels: string[]`로 저장. 0개 선택은 의도적 비활성화로 간주(빈 배열 그대로 저장).
6. 선택된 각 앱에 대해 `app_id`, `platform` (`ios` 또는 `android`), `display_name`, `bundle_id` 또는 `package_name`을 `firebase.apps[]`에 객체로 저장.

저장 후 Step 3로 진행.

### Step 3. 베이스 브런치 캡처

스킬 실행 시점에 `git rev-parse --abbrev-ref HEAD`로 **현재 체크아웃 브런치**를 읽고 `BASE_BRANCH` 변수에 저장한다. 이후 모든 사이클의 워크트리는 `origin/<BASE_BRANCH>`의 최신 SHA를 베이스로 만들고, 모든 PR은 이 브런치를 타겟으로 한다.

`BASE_BRANCH`가 `HEAD`(detached) 또는 빈 값이면 즉시 종료하고 사용자에게 정상 브런치로 이동을 요청한다.

### Step 4. 이슈 조회 및 사용자 검토

1. **인자 파싱**:
   - **인자 있음**: 공백·콤마 구분된 GitHub Issue 번호 목록으로 해석. 각 번호에 대해 `gh issue view <number> --repo <config.github.repo> --json number,title,labels,url,body,state` 조회. state 무관(open/closed 모두 허용).
   - **인자 없음**: `gh issue list --repo <config.github.repo> --label "<config.github.issue_label>" --state open --json number,title,labels,url,body --limit 100` 조회.

2. 조회된 이슈를 표로 사용자에게 제시:

   | #     | 제목      | 라벨       | 링크    |
   | ----- | --------- | ---------- | ------- |
   | `<n>` | `<title>` | `<labels>` | `<url>` |

3. **closed 이슈 사전 확인**: 인자에 closed 이슈가 포함된 경우 AskUserQuestion으로 진행 여부 확인. 거부 시 해당 번호를 목록에서 제외.

4. AskUserQuestion `multiSelect: true`로 진행할 이슈 선택받기.

5. **거절(미선택) 이슈 처리**:
   - GitHub: `gh issue close <number> --reason "not planned" --repo <config.github.repo>` (해결됨이 아닌 **Closed as not planned**).
   - Firebase Crashlytics: 이슈 본문에서 다음 형식의 HTML 주석 메타가 발견되면 자동으로 Crashlytics 측도 동기 종결한다. 메타가 없으면 GitHub만 닫고 사용자에게 수동 처리를 안내한다 — 본문 메타 자동 등록은 외부 도구의 책임이고 본 스킬은 그 결과를 활용할 뿐이라, 메타 부재는 정상 케이스다. 통합 이슈(iOS+Android)는 한 본문에 **여러 쌍**이 존재할 수 있다.
     - `app_id` 정규식 (전역 매치): `<!--\s*app_id:\s*(\S+)\s*-->`
     - `crashlytics_issue_id` 정규식 (전역 매치): `<!--\s*crashlytics_issue_id:\s*([A-Za-z0-9_-]+)\s*-->`
     - 두 정규식의 매치를 본문 등장 순서대로 `(app_id, crashlytics_issue_id)` 쌍 배열로 묶는다. 일반 텍스트가 아닌 **HTML 주석 영역에 한정**해 매치하므로 사용자가 본문에 임의로 적은 텍스트와 충돌하지 않는다.
     - 두 정규식의 매치 개수가 다르면 데이터 불일치로 보고 추출 실패 처리.
   - 추출 성공 시 각 쌍에 대해 `mcp__firebase__crashlytics_update_issue(app_id, issue_id, state="CLOSED")`를 병렬 호출.
   - 추출 실패(매치 0건 또는 개수 불일치) 시 GitHub만 닫고 사용자에게 수동 처리를 안내.

6. 승인된 이슈 목록만 다음 단계로 이월. 승인된 이슈가 0건이면 Step 6-5의 보고서 출력으로 직행.

7. **자동 진행 모드 토글**: 승인된 이슈가 **2건 이상**이면 사이클별 승인 누적이 부담이다. AskUserQuestion으로 "전체 자동 진행 모드"를 묻고 사용자 선택을 `AUTO_PROCEED` 변수에 저장한다 (1건이면 묻지 않고 `false` 고정).
   - **수동(기본값)**: 사이클마다 변경 요약을 보여주고 커밋·푸시·PR 생성 승인을 받는다.
   - **자동**: self code review(Step 5-2의 통과 기준 참조)를 통과한 변경은 별도 승인 없이 커밋·푸시·PR 생성까지 진행. 사용자에게는 변경 요약만 출력. **머지 단계(Step 6-2)는 모드와 무관하게 항상 일괄 승인을 받는다** — 머지는 블레스트가 큰 결정이라 자동화에 적합하지 않다.

8. **사전 수집 (Step 5·6에서 재사용할 캐시)**:
   - 승인된 각 이슈 본문에서 `(app_id, crashlytics_issue_id)` 쌍을 정규식(Step 4-5 정의)으로 추출해 `meta_pairs[issue_number]` 캐시에 저장한다. 본문 파싱은 이 시점 1회만 수행하고, 5-3 PR 본문 보강·6-4 Crashlytics 종결은 모두 이 캐시를 재사용한다.
   - 추출된 모든 쌍에 대해 `mcp__firebase__crashlytics_get_issue`를 **병렬 호출**해 `events`/`users`/`first_seen`/`last_seen` 통계를 미리 채워 `crash_stats[issue_number]` 캐시에 저장한다. 이슈 N건 × 쌍 M건 → N\*M 병렬 호출 1회로 5-3의 PR 본문 작성 시 추가 네트워크 호출 없이 본문을 완성할 수 있다.
   - 호출 실패 항목은 캐시에서 빈 값으로 두고 5-3에서 "해당 없음"으로 본문에 명시한다 — 사이클을 막지는 않는다.
   - **BASE SHA는 캐시하지 않는다.** 사이클마다 5-1에서 fetch해 외부 협업자의 최신 push까지 흡수한다. 한 번 fetch해 두는 미세 최적화보다, 머지 단계에서 충돌로 드러날 외부 변경을 사이클 시작 시점에 흡수하는 단순함이 더 가치 있다.

### Step 5. 사이클 루프 (승인된 이슈마다 반복)

각 이슈에 대해 다음을 순차 수행한다. 한 사이클이 종료된 뒤에만 다음 사이클로 진입한다. 각 사이클은 자기만의 fresh 워크트리에서 동작하며, 사이클 종료 시 PR 1개가 origin에 푸시되어 검토 대기 상태가 된다. 사이클들은 서로 독립적이므로 한 사이클이 막혀도 다음 사이클은 정상 진행된다.

#### 5-1. fresh base 워크트리 생성

각 사이클은 `origin/<BASE_BRANCH>`의 **최신 SHA**에서 출발한 새 워크트리·브런치를 만든다. 이전 사이클의 PR이 머지됐든 안 됐든 영향 없다 — 사이클 시작 시점의 origin 상태가 기준이다. 이게 rebase 로직 없이도 사이클 간 충돌을 회피하는 안전망이다.

1. **BASE 최신화 fetch**: 사이클 시작 시 `git fetch origin <BASE_BRANCH>`를 실행해 외부 협업자의 push까지 흡수한 최신 SHA를 기준으로 워크트리를 만든다. 본 스킬은 Step 6에서 일괄 머지하므로 사이클 진행 중에 자기가 만든 PR이 머지되어 BASE가 변하는 일은 없고, 사이클 간 BASE 변동 원인은 외부 push뿐이다 — 사이클마다 fetch가 그 변경을 가장 빨리 반영하는 단순한 방법이다. fetch 비용은 보통 수 초 내외이며, 캐시로 인한 외부 변경 누락보다 훨씬 작다.

2. **브런치명 결정**: `BRANCH = fix/issue-<issue_number>` (예: `fix/issue-150`).

3. **이름 충돌 확인**: `git rev-parse --verify --quiet refs/heads/<BRANCH>` 또는 `git worktree list`로 동일 브런치/워크트리 존재 여부 확인.
   - 존재 시 AskUserQuestion으로 처리 옵션 제시:
     - **재사용**: 기존 브런치를 그대로 사용해 이어서 작업(이전 미완료 사이클 재개에 적합).
     - **시퀀스**: `fix/issue-<n>-2`, `-3` … 으로 새 이름 채번.
     - **사이클 건너뛰기**: 본 이슈를 `failed`로 표시하고 다음 사이클로 진행.

4. **워크트리 생성**:
   - 디렉토리: 슬래시(`/`)는 디렉토리명에 부적합하므로 `fix-issue-<n>` 형태로 변환.
   - 경로: `<repo-root>/.worktrees/fix-issue-<issue_number>/` (`git rev-parse --show-toplevel`로 repo-root 확인).
   - 명령(신규):

     ```bash
     git worktree add <repo-root>/.worktrees/fix-issue-<issue_number> \
       -b <BRANCH> origin/<BASE_BRANCH>
     ```

   - 재사용 시:

     ```bash
     git worktree add <repo-root>/.worktrees/fix-issue-<issue_number> <BRANCH>
     ```

#### 5-2. 이슈 분석 및 수정 (산출물 중심)

**워크트리 의존성 처리 (사전 안내)**: 분석은 기본적으로 `Read`/`Grep` 기반이라 별도 셋업 없이 진행한다. 다만 다음 두 경우는 워크트리에서 명령을 직접 실행해야 한다 — `verification_summary == test_added`로 테스트를 돌려 검증이 필요할 때(예: `npm test`, `pytest`, `go test ./...`, `flutter test`, `cargo test`), 그리고 codegen 산출물이 분석에 필요한데 누락되어 있을 때(예: protobuf `*.pb.go`·`*_pb2.py`, OpenAPI 클라이언트, Dart `*.g.dart`·`*.freezed.dart`, GraphQL `*_generated.ts`). 이 명령들이 실패하면 사용자에게 출력을 보고하고 사이클을 `failed: env_setup`으로 종결한다(다음 사이클로 진행). 환경별 초기화 절차가 매번 동일하다면 사용자 메모리나 프로젝트 CLAUDE.md/AGENTS.md에 적어두면 자동 인지에 도움이 된다.

**일관된 결과물 보장을 위해 각 단계는 명시된 산출물(artifact)을 남긴다**. 산출물은 5-3의 PR 본문 작성에 그대로 재사용되며, 사용자가 PR을 검토할 때 라벨만 봐도 원인 분류·검증 방식을 한 줄로 파악할 수 있다. 산출물이 정의되지 않은 자유 서술은 LLM 호출마다 형식이 흔들려 일관성을 깨뜨리는 주범이라, 본 단계의 모든 결과는 다음 4개 필드로 환원된다.

1. **`entry_point` 식별** — 산출물 형식: `<파일 경로>:<함수/클래스명>:<라인>`.
   - 스택트레이스 상단부에서 자사 코드(workspace 내 경로) 첫 프레임을 선택한다. 외부 SDK 프레임은 건너뛴다.
   - workspace 내 프레임이 없으면 사이클을 `failed: no_workspace_frame`으로 종결하고 다음 사이클로 진행한다(외부 SDK 단독 크래시는 본 스킬 범위 밖).

2. **`cause_label` 분류** — 산출물 형식: 다음 6개 enum 중 정확히 1개.
   - `null_dereference` / `unhandled_exception` / `race_condition` / `wrong_state` / `external_api_failure` / `unknown`
   - `unknown`을 선택할 때만 사유 1줄을 본문에 명시. enum이 고정되어 있으므로 회귀 시 cause_label 분포 변화로 추적 가능하다.

3. **`patch_files` 수정** — 산출물 형식: 변경된 파일 경로 배열(권장 1~2개).
   - 외부 인터페이스(공개 API 시그니처, 라우트 정의, DTO 필드명) 변경 금지 — 회귀 위험 큰 변경은 본 스킬 범위 밖.
   - 변경 라인 수 합계가 30을 초과하면 자동 모드여도 AskUserQuestion으로 사용자 승인을 받는다.

4. **`verification_summary` 검증** — 산출물 형식: 다음 3개 enum 중 정확히 1개 + 부속 정보.
   - `test_added` (테스트 파일 경로 + 통과 여부) / `manual_only` (수동 검증 시나리오 1~3줄) / `not_reproducible` (사유 1줄)

**self code review 통과 기준 (자동 모드 진입 조건)**:

자동 모드(`AUTO_PROCEED == true`)에서 별도 사용자 승인 없이 5-3으로 진행하려면 다음 4개 조건을 **전부** 충족해야 한다. 하나라도 어긋나면 자동 모드여도 사용자 승인 분기로 강제 진입한다 — 자동화의 안전 마진이다.

- 변경 라인 수 합계 ≤ 30
- `cause_label != "unknown"`
- `patch_files`의 모든 경로가 workspace 내부(소스/테스트/매니페스트 — 예: Node `src/`+`test/`+`package.json`, Python `src/`+`tests/`+`pyproject.toml`, Go `internal/`+`*_test.go`+`go.mod`, Dart `lib/`+`test/`+`pubspec.yaml`. `.git/`, `.worktrees/`, 외부 의존성 캐시 — `node_modules/`, `.venv/`, `vendor/` 등 — 은 제외)
- 외부 인터페이스 변경 없음(공개 API 시그니처·라우트·DTO 필드명 무수정)

#### 5-3. 커밋·푸시·PR 생성

1. 변경 요약(`git diff --stat`로 파일별 통계 + 핵심 변경 설명)을 사용자에게 제시.
2. **수동 모드**(`AUTO_PROCEED = false`): AskUserQuestion으로 진행 여부를 받는다. **자동 모드**(`AUTO_PROCEED = true`): 별도 승인 없이 다음 단계로 진행.
3. 워크트리 안에서 커밋·푸시·PR 생성:

   ```bash
   git add <files>
   git commit -m "fix(#<issue_number>): <한 줄 요약>

   <본문 — 원인·수정 방향>

   Closes #<issue_number>"
   git push -u origin <BRANCH>

   # PR 본문 작성
   # - references/pr-template.md(단일 이슈 형식)을 채워 임시 파일에 작성
   # - Step 5-2의 산출물 (entry_point / cause_label / patch_files / verification_summary)을
   #   PR 본문의 "변경 요약" 섹션 첫 줄에 라벨 형태로 명시. 예시:
   #     [cause: null_dereference] [verify: test_added] entry: lib/foo/bar.dart:42
   # - Crashlytics 통계는 Step 4-8에서 미리 캐시한 crash_stats[issue_number]를 그대로 사용.
   #   사이클 단계에서 mcp__firebase__crashlytics_get_issue를 다시 호출하지 않는다(중복 호출 제거).
   # - 본문 임시 파일 경로는 /tmp/crashlytics-issue-to-fix-pr-<issue_number>.md. 인라인 --body는
   #   따옴표 이스케이프 문제로 자주 깨지므로 항상 --body-file로 전달.
   gh pr create \
     --repo <config.github.repo> \
     --base <BASE_BRANCH> \
     --head <BRANCH> \
     --title "fix(#<issue_number>): <한 줄 요약>" \
     --body-file /tmp/crashlytics-issue-to-fix-pr-<issue_number>.md \
     <--label 플래그 N개 — config.github.pr_labels의 각 라벨을 한 번씩 전달>
   ```

   - **PR 라벨 부착**: `config.github.pr_labels` 배열의 각 라벨을 `--label "<name>"` 플래그로 한 번씩 전달한다 (`gh`는 같은 플래그의 반복 사용을 허용한다). 예: `pr_labels = ["bug", "regression"]` → `--label "bug" --label "regression"`. 빈 배열이면 `--label` 플래그 자체를 생략한다(라벨 부착 비활성화).
   - 라벨 부착이 실패해도 PR 생성을 막지 않는다. `gh pr create`가 라벨 한 개라도 거부하면 라벨 없이 재시도하고, 종료 보고서에 "PR #N: 라벨 부착 실패 — <사유>"를 비고로 남긴다. 라벨은 부수 메타데이터라 본 스킬의 핵심 산출물(PR·이슈·Crashlytics 동기화)을 막을 가치는 없다.
   - 커밋 메시지에 `Closes #<issue_number>` 키워드를 반드시 포함한다. 머지 시 GitHub이 이 키워드를 인식해 해당 이슈를 자동으로 닫는다.
   - PR은 만들기만 하고 머지하지 않는다. 머지는 Step 6에서 일괄 처리.
   - 생성된 PR 번호를 `(이슈 번호 → PR 번호)` 매핑에 보관해 Step 6에서 사용한다.

4. **pre-commit hook 실패 처리**: 커밋이 pre-commit hook으로 실패하면 hook의 출력을 그대로 사용자에게 보고하고 AskUserQuestion으로 다음 옵션을 묻는다.
   - **재시도**: 동일한 변경으로 한 번 더 커밋 시도(일시적 실패 가정).
   - **수동 수정 후 재시도**: 사용자가 워크트리에서 직접 추가 수정 후 재시도. 사용자가 "재개" 응답을 보낸 시점에 변경분을 다시 stage·commit.
   - **사이클 중단**: 본 사이클을 `failed`로 종결하고 다음 사이클로 진행. 본 이슈는 종료 보고서에 사유와 함께 명시. 워크트리·브런치는 보존 (사용자가 직접 검토 가능하도록).
   - hook 매니저와 그 안의 검증 도구는 프로젝트마다 다르다. 스킬은 절대 자동으로 hook 우회(`--no-verify`)를 사용하지 않으며, 자동 모드에서도 hook 실패 시에는 본 분기로 진입해 사용자 결정을 기다린다.

#### 5-4. 사이클 종결

본 사이클은 PR 1개를 origin에 푸시한 것으로 종결한다. 워크트리·브런치는 보존하며, 머지 또는 정리는 Step 6의 책임이다. PR 번호와 이슈 번호의 매핑을 다음 단계에서 사용할 수 있도록 보관한다.

다음 이슈가 있으면 5-1로 복귀.

### Step 6. PR 일괄 검토·머지 및 일괄 종결

모든 사이클이 종료된 뒤 다음을 수행한다. Step 5에서 만든 PR 목록(이슈 번호 → PR 번호 매핑)을 기준으로 진행한다. 생성된 PR이 0건이면 Step 6-5의 보고서 출력으로 직행.

#### 6-1. PR 목록 제시

생성된 모든 PR을 표 형태로 사용자에게 제시. 각 PR의 변경 통계는 `gh pr view <pr_number> --json url,additions,deletions,changedFiles`를 **PR 수만큼 병렬 호출**해 수집한다. 직렬 호출 시 PR이 많을수록 사용자 대기 시간이 비례 증가하므로, 외부 시스템 독립 조회는 항상 병렬을 기본값으로 둔다.

| #     | 이슈 제목 | PR 링크      | 변경 stat (files / +add / -del) |
| ----- | --------- | ------------ | ------------------------------- |
| `<n>` | `<title>` | [#<pr>](url) | `<files>/+<add>/-<del>`         |

#### 6-2. 일괄 승인 분기

1차 AskUserQuestion으로 단일 선택:

- **[A] 전부 머지**: 생성된 PR 모두 머지 시도.
- **[B] 일부만 선택 머지**: 2차 AskUserQuestion `multiSelect: true`로 머지할 PR 선택. 미선택 PR은 거절(OPEN 유지) 처리.
- **[C] 전부 거절**: 모든 PR·이슈·Crashlytics OPEN 유지. Step 6-5의 보고서로 직행.

#### 6-3. 머지 사전 점검 (필수)

머지 시도 전에 머지 대상 PR을 **병렬 조회**해 충돌 예고된 PR을 미리 식별한다. 한 PR이 충돌이면 6-4의 직렬 순회가 첫 머지에서 멈춰 사용자가 매번 분기를 응답해야 하므로, 병렬 사전 점검으로 한 번에 분류해 사용자 응답 횟수를 1회로 제한한다.

```bash
# PR 수만큼 병렬 호출
gh pr view <pr_number> --json mergeable,mergeStateStatus
```

- `mergeable: CONFLICTING`인 PR이 있으면 사용자에게 일괄 보고하고 "이 N개 충돌 예상 PR을 어떻게 처리할지" AskUserQuestion으로 묻는다.
  - **건너뛰기(권장)**: 해당 PR은 머지 대상에서 제외하고 결과 라벨 `conflict`로 표시. 사용자가 보존된 워크트리에서 직접 rebase 후 재머지.
  - **그대로 시도**: 6-4 직렬 머지에서 race-condition 분기로 위임(다른 PR이 그 사이 머지되어 BASE가 갱신된 경우에만 의미가 있다).
- `mergeStateStatus: BEHIND`는 GitHub이 자동 fast-forward 처리하므로 별도 조치 불필요.
- 6-4의 `MERGE_CONFLICT` 분기는 본 사전 점검 통과 후 발생한 race-condition(직전 PR 머지로 BASE 갱신 → 본 PR이 같은 파일 충돌) 케이스만 책임진다 — 책임을 사전 점검(정적 충돌)과 직렬 머지(동적 race) 두 단계로 분리.

#### 6-4. 직렬 머지 + PR 내부 종결 병렬

**머지(`gh pr merge`)는 BASE 브런치라는 공유 자원을 변경하므로 직렬화한다**. 두 PR이 텍스트적으로 겹치면(공통 헬퍼·import 순서·`.g.dart` 같은 생성 파일·`pubspec.yaml`) 두 번째 머지가 `MERGE_CONFLICT`로 거절된다. 종결 작업(이슈 close, Crashlytics CLOSED, 워크트리 정리)은 외부 시스템 독립이라 PR 내부에서 병렬 처리 가능.

처리 대상을 두 그룹으로 나눈다:

- **머지 대상**: Step 6-2에서 사용자가 머지를 승인한 PR. 아래 6-4-1의 직렬 순회로 처리.
- **거절 대상**: Step 6-2 `[B]`에서 미선택된 PR. 머지 시도 자체를 하지 않고 6-4-2에서 결과 라벨만 부여.

#### 6-4-1. 머지 대상 PR — 직렬 순회

승인된 각 PR에 대해 직렬로 다음을 수행한다:

1. **머지 시도**:

   ```bash
   gh pr merge <pr_number> --<config.github.merge_method> --delete-branch --repo <config.github.repo>
   ```

   기본값은 `--squash`. `merge_method`가 `merge`/`rebase`인 경우 해당 플래그로 치환.

2. **머지 실패(`MERGE_CONFLICT`) 시 AskUserQuestion**:
   - **건너뛰기(권장)**: 이 PR은 OPEN 유지, 결과 라벨 `conflict`로 표시. 다음 PR로 진행.
   - **직접 해결**: 사용자가 워크트리에서 rebase·force push 후 "재시도" 응답. 응답 받으면 동일 PR 재시도.
   - **6-4 중단**: 남은 PR 모두 OPEN. Step 6-5 보고서로 직행.

3. **머지 성공 시 — PR 내부 종결 작업은 병렬**:
   - 5초 대기 (GitHub 자동 닫힘 트리거 반영).
   - 다음을 병렬로 수행:
     - **GitHub 이슈 종결**: `gh issue view <n> --json state -q .state --repo <config.github.repo>`로 상태 확인. `OPEN`이면 `gh issue close <n> --reason "completed" --repo <config.github.repo>`로 보강. 이미 `CLOSED`면 건너뛴다(중복 호출 방지).
     - **Crashlytics 종결**: 이슈 본문에서 추출한 `(app_id, crashlytics_issue_id)` 쌍 **전부**에 대해 `mcp__firebase__crashlytics_update_issue(app_id, issue_id, state="CLOSED")`를 병렬 호출. 통합 이슈(iOS+Android)는 한 GitHub 이슈에 다수 쌍이 매핑되므로 모두 호출. 추출 실패 또는 호출 실패한 항목은 종료 보고서에 명시.
     - **워크트리 정리**:

       ```bash
       git worktree remove <repo-root>/.worktrees/fix-issue-<n>
       git branch -D fix/issue-<n>
       ```

       원격 브런치는 `gh pr merge --delete-branch`가 정리한다.

#### 6-4-2. 거절 대상 PR — 보존 처리

Step 6-2의 `[B]` 분기에서 미선택된 PR은 머지 시도 없이 다음과 같이 처리한다(외부 호출 없음):

- PR·이슈·Crashlytics 모두 OPEN 유지.
- 워크트리·브런치도 보존(사용자가 직접 검토·머지·종결 가능하도록).
- 결과 라벨 `user_rejected`로 종료 보고서에 기록.

#### 6-5. 종료 보고서 출력

`references/report-template.md`를 채운 종료 보고서를 사용자에게 출력. 필수 항목:

- 처리한 이슈 수, 머지 성공·거절·충돌·실패·미선택 건수
- 이슈별 결과 표(`#`, `제목`, `결과`, `PR 링크`, `Crashlytics 상태`, `비고`)
- 잔여 작업: 거절·충돌·실패로 남은 워크트리 목록, Crashlytics 수동 처리 필요 항목

#### 6-6. 잔존 워크트리 점검

본 단계는 **이번 실행에서 정리된 워크트리가 아니라**, 이전 실행에서 사용자 거절·중단·충돌·실패로 남겨진 워크트리를 한꺼번에 정리하기 위한 단계다. Step 5-1의 시작-시점 충돌 감지와는 책임이 다르다.

`git worktree list`로 점검. 본 스킬이 만든 `.worktrees/fix-issue-*` 중 정리되지 않은 것이 있으면 AskUserQuestion으로 일괄 정리 여부를 묻는다. 사용자가 정리에 동의하면 각 잔존 항목에 대해 `git worktree remove <path>`와 `git branch -D <branch>`를 실행한다.

## 명령행 플래그

| 플래그          | 동작                                                                                                                                                                  |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| (인자 없음)     | `config.json`의 `github.repo`에서 `state:open` + `label:<config.github.issue_label>` 조건으로 이슈 조회.                                                              |
| `<번호 목록>`   | 공백·콤마 구분 GitHub Issue 번호 목록만 처리. state 무관(closed 포함 시 사용자 확인).                                                                                 |
| `--reconfigure` | 기존 `config.json`의 `firebase.*`, `github.repo`, `github.issue_label`, `github.pr_labels` 값을 무시하고 Step 2 셋업 재실행. `merge_method` 등 사용자 튜닝 값은 보존. |

## 사용 도구

| 도구                                        | 용도                                                                 |
| ------------------------------------------- | -------------------------------------------------------------------- |
| `mcp__firebase__firebase_get_environment`   | 인증 상태 점검                                                       |
| `mcp__firebase__firebase_login`             | 미인증·만료 시 로그인                                                |
| `mcp__firebase__firebase_list_projects`     | 프로젝트 목록 조회 (첫 실행 시)                                      |
| `mcp__firebase__firebase_list_apps`         | 앱 목록 조회 (첫 실행 시)                                            |
| `mcp__firebase__crashlytics_get_issue`      | PR 본문 events / users / first_seen / last_seen 자동 보강            |
| `mcp__firebase__crashlytics_update_issue`   | Crashlytics 이슈 상태 CLOSED 전환                                    |
| `gh issue view` / `gh issue list`           | GitHub 이슈 조회                                                     |
| `gh issue close`                            | 거절 이슈 not-planned 처리, 자동 닫힘 미반영 보강                    |
| `gh label list`                             | 첫 셋업·`--reconfigure` 시 PR 라벨 후보 조회 (Step 2-5)              |
| `gh pr create`                              | 사이클당 PR 1개 생성, `--label`로 PR 라벨 부착 (Step 5-3)            |
| `gh pr view`                                | PR stat·mergeability 조회 (Step 6-1, 6-3)                            |
| `gh pr merge`                               | PR 직렬 머지·원격 브런치 삭제 (Step 6-4)                             |
| `git fetch` / `git worktree add` / `remove` | 사이클별 워크트리 N개 생성·정리                                      |
| `git rev-parse` / `git push` / `git branch` | 베이스 브런치 캡처·이슈별 브런치 푸시·로컬 브런치 정리               |
| `AskUserQuestion`                           | 셋업·이슈 검토·브런치 충돌·커밋·일괄 머지·충돌 처리·잔존 정리 분기점 |

## 참조 리소스

| 파일                            | 내용                                                 |
| ------------------------------- | ---------------------------------------------------- |
| `references/installation.md`    | 설치 위치 선택, 첫 실행, 커스터마이징, 트러블슈팅    |
| `references/pr-template.md`     | 단일 이슈 PR 본문 템플릿 (Step 5-2 산출물 라벨 포함) |
| `references/report-template.md` | 사이클 종료 보고서 템플릿 (PR 단위 결과)             |

## 설계 원칙 요약

- **영구 설정 분리 + 프로젝트 격리**: 사용자 셋업 결과는 `${CLAUDE_PLUGIN_DATA}/crashlytics-issue-to-fix/projects/<PROJECT_KEY>/config.json`에, 작성자 기본값은 `${CLAUDE_SKILL_DIR}/config.json`(번들 템플릿)에 분리한다. PROJECT_KEY는 git remote URL의 `<owner>-<repo>` 형태로 자동 추출되므로 동일 사용자가 여러 프로젝트를 오갈 때 각 프로젝트의 Firebase·repo·라벨 설정이 자기 디렉토리에 격리되어 서로 덮어쓰지 않는다. 플러그인 업데이트 시 `${CLAUDE_PLUGIN_DATA}`는 보존되고 `${CLAUDE_SKILL_DIR}`는 새 버전으로 교체되므로, 사용자 셋업이 살아남으면서 새 사용자는 검증된 기본값으로 시작한다.
- **하드코딩 제로**: 서비스명·프로젝트 ID·앱 ID·레포지토리·라벨명은 전부 `config.json`으로 외부화. 라벨명은 환경마다 컨벤션이 달라(`bug`·`type:bug`·`kind/bug`·국문 라벨 등), SKILL 본문이나 references에 후보를 박아두지 않고 셋업 시 `gh label list`로 사용자 레포의 실제 등록 라벨에서만 다중 선택을 받는다. 워크트리 초기화(패키지 install·환경 파일 복사·코드 생성)는 환경별 편차가 커 자동화 대신 사용자 직접 실행으로 위임한다.
- **결정성 우선 (Step 5-2 산출물 4종)**: 이슈 분석은 자유 서술이 아닌 `entry_point` / `cause_label`(enum) / `patch_files` / `verification_summary`(enum)의 4개 산출물로 환원. PR 본문 일관성, evals 자동 채점, 회귀 추적(분포 변화 감지)을 동시에 가능케 한다.
- **사전 수집 캐시 (Step 4-8)**: 이슈 본문 파싱·Crashlytics 통계 조회는 Step 4에서 1회 수행해 캐시. 사이클 N개일 때 호출 횟수가 N→1로 감소. **단 BASE SHA는 캐시하지 않는다** — fetch 비용은 미미하지만 외부 협업자 push를 흡수하지 못하면 머지 단계에서 충돌로 더 비싸게 드러나기 때문.
- **per-issue 워크트리 + per-issue PR + 일괄 검토**: 이슈마다 독립 워크트리·브런치·PR을 만든 뒤, Step 6에서 모든 PR을 단일 검토 분기점으로 모아 일괄 결정. 사이클 간 격리·부분 실패 회복력·revert 단위 명확성을 모두 잡는 운영 선택.
- **fresh base 원칙**: 매 사이클이 `origin/<BASE_BRANCH>`의 최신 SHA에서 출발. rebase 로직 없이 사이클 간 충돌을 회피한다. 사이클 도중 다른 PR이 머지돼도 다음 사이클이 자동 흡수.
- **공유 자원 직렬 / 독립 자원 병렬**: 머지(`gh pr merge`)는 BASE 브런치라는 공유 자원 변경이라 PR끼리 직렬. 종결 작업(이슈 close, Crashlytics CLOSED, 워크트리 정리)은 외부 시스템 독립이라 PR 내부에서 병렬. 분산 시스템의 기본 패턴.
- **이슈당 1 PR**: 회귀 추적·부분 revert를 위해 이슈마다 PR 1개로 분리(`Closes #<n>` 포함). 머지 후 회귀 발견 시 PR 단위 단독 revert 가능.
- **베이스 브런치 단일 진실원**: `BASE_BRANCH`는 스킬 시작 시 한 번만 캡처. 모든 워크트리·PR이 이 브런치를 참조. 사이클 도중 사용자가 다른 브런치로 이동해도 영향 없음.
- **AskUserQuestion 분기점 명시**: 셋업·이슈 검토·브런치 충돌·커밋·일괄 머지 결정·충돌 처리·잔존 워크트리 정리 분기점에서 가정 없이 사용자 승인. 자동 진행은 안전한 조회·계산 단계와 사이클 내부의 커밋·PR 생성에 한정. 머지는 항상 사용자 승인.
- **재인증 금지**: 인증 상태가 유효하면 재로그인 호출 안 함(토큰 TTL 최대화).
- **이중 종결**: 거절 시(not planned, Step 4-5) + 머지 시(completed, Step 6-4) 양쪽 모두에서 GitHub 이슈와 Crashlytics 상태를 동기 종결해 데이터 누락 방지.
- **MCP 우선 / CLI 보조**: Firebase 조작은 `mcp__firebase__*`만, GitHub·git은 CLI 사용. 도구 선택 일관성 유지.
