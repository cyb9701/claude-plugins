# Installation Guide

## Prerequisites

- **Claude Code** (or compatible client with Skill tool support)
- **Firebase MCP server** — `mcp__firebase__*` tool family must be accessible in your session. Verify by checking that tools like `mcp__firebase__firebase_get_environment` appear in your tool list.
- **GitHub CLI (`gh`)** — 최신 stable. 인증 완료. 확인:
  ```bash
  gh --version | head -1
  gh auth status
  ```
- **git 2.5 이상** — `git worktree` 명령 지원 필요. 확인:
  ```bash
  git --version   # 2.5+
  ```
- **GitHub repo의 issue label** — 본 스킬은 `config.github.issue_label`에 지정된 단일 라벨로 미처리 이슈를 조회한다. 라벨이 미등록 상태면 `gh label create "<label>" --repo "<owner>/<repo>"`로 사전 등록.

## Installation

이 skill은 `easy-claude-code` 플러그인의 일부로 배포된다. standalone 복사·설치(`~/.claude/skills/<name>/`)는 더 이상 지원하지 않으며, 플러그인 활성화를 통해서만 사용한다.

플러그인 자체 설치·로드 방법은 [easy-claude-code 플러그인 README](../../../README.md) 참고. 개발 시점에는 `claude --plugin-dir <plugin-root>`으로 in-place 로드 후 `/reload-plugins`로 변경 사항을 즉시 반영할 수 있다.

## Storage Layout

플러그인이 활성화되면 두 종류의 config 파일이 사용된다. 두 경로의 책임은 **읽기 전용 기본값**과 **쓰기 가능한 사용자 인스턴스**로 명확히 분리되어 있다.

| 경로 | 역할 | 보존 여부 | 누가 쓰나 |
|------|------|----------|----------|
| `${CLAUDE_SKILL_DIR}/config.json` | 작성자가 번들한 기본값 템플릿 | 플러그인 업데이트 시 새 버전으로 교체 | 작성자(릴리스 시) |
| `${CLAUDE_PLUGIN_DATA}/crashlytics-issue-to-fix/projects/<PROJECT_KEY>/config.json` | 사용자별 + 프로젝트별 셋업 결과 | 플러그인 업데이트 후에도 보존 | skill의 셋업 단계 |

`${CLAUDE_PLUGIN_DATA}`는 `~/.claude/plugins/data/<plugin-id>/`로 해석되며, 플러그인을 마지막 스코프에서 제거할 때(또는 `--keep-data` 없이 uninstall)까지 유지된다.

`<PROJECT_KEY>`는 호출 시점에 다음 우선순위로 자동 추출된다:

1. `git remote get-url origin` 성공 시 `<owner>-<repo>` 형태 (예: `cyb9701-easy-claude-code`)
2. 실패 시 `git rev-parse --show-toplevel`의 basename
3. 둘 다 실패 시 `pwd`의 basename

이 키 분리 덕분에 동일 사용자가 여러 프로젝트(예: 회사 repo / 개인 repo / 오픈소스 fork)를 오갈 때 각 프로젝트의 Firebase·repo·라벨 셋업이 서로 덮어쓰지 않고 독립 보존된다. 첫 실행 시 해당 프로젝트의 영구 저장소가 비어 있으면 SKILL.md의 Step 2가 자동으로 번들 기본값을 복사한 뒤 대화형 셋업을 시작한다.

## First Run (대화형 셋업)

스킬을 호출하면 현재 프로젝트의 `${CLAUDE_PLUGIN_DATA}/crashlytics-issue-to-fix/projects/<PROJECT_KEY>/config.json`이 없거나 핵심 필드가 빈 상태에서는 자동으로 대화형 셋업으로 진입한다. PROJECT_KEY 추출 규칙과 셋업 단계의 정확한 순서·저장 필드는 SKILL.md의 **Step 2**가 단일 진실원이다.

호출 방법:

- 슬래시 커맨드: `/easy-claude-code:crashlytics-issue-to-fix` (인자 없음 → 라벨 기반 일괄 조회), `/easy-claude-code:crashlytics-issue-to-fix 123,456` (특정 이슈만)
- 자연어 예시: "fix crashlytics issue #123", "이슈 #123 자동 수정해줘", "crashlytics 라벨 이슈 처리해줘"

입력값은 해당 프로젝트의 `${CLAUDE_PLUGIN_DATA}/crashlytics-issue-to-fix/projects/<PROJECT_KEY>/config.json`에 저장되어 다음 실행부터는 같은 프로젝트에서만 셋업이 생략된다. 다른 프로젝트로 이동하면 그 프로젝트의 별도 PROJECT_KEY 디렉토리에서 새 셋업이 트리거된다. 설정을 다시 받고 싶으면 `--reconfigure`.

## Customization

### `github.merge_method`

기본값 `squash`. PR 머지 방식을 바꾸려면 다음 중 하나로 수정:

- `squash` — 모든 커밋을 하나로 압축 (권장 기본값)
- `merge` — 머지 커밋 생성
- `rebase` — fast-forward 리베이스

`gh pr merge --<method>` 형태로 전달된다.

### `github.pr_labels`

본 스킬이 생성하는 모든 PR에 자동으로 부착할 라벨 배열. 첫 셋업(또는 `--reconfigure`)에서 사용자 레포의 실제 등록 라벨(`gh label list`) 중 다중 선택으로 채워진다. 라벨명은 환경마다 컨벤션이 달라(`bug`·`type:bug`·`kind/bug`·국문 라벨 등) 본 스킬이 어떤 후보도 가정하지 않으므로, 사용자 레포에 등록된 라벨이 단일 진실원이다.

- `[]` (빈 배열): 의도적 비활성화. 라벨 없이 PR 생성. `--reconfigure` 없이는 재선택 트리거가 발생하지 않는다.
- 누락(`null` 또는 키 자체 없음): 미설정 상태로 간주되어 다음 호출 시 셋업 진입.
- 1개 이상: 각 항목이 `gh pr create --label "<name>"` 플래그로 PR 생성 시 전달된다.

라벨을 추가하거나 변경하려면 두 가지 방법이 있다:

1. **재셋업 (권장)**: `--reconfigure`로 호출하면 가용 라벨 다중 선택을 다시 받는다.
2. **직접 편집**: 사용자 인스턴스(`${CLAUDE_PLUGIN_DATA}/crashlytics-issue-to-fix/projects/<PROJECT_KEY>/config.json`)의 `github.pr_labels` 배열을 수동 편집. 번들 템플릿(`${CLAUDE_SKILL_DIR}/config.json`)은 플러그인 업데이트 시 교체되므로 편집 대상이 아니다. 이 경우 라벨이 실제로 사용자 레포에 등록되어 있는지는 사용자 책임이다 — 스킬은 PR 생성 시 `gh`가 거부하면 라벨 없이 재시도하고 보고서에 실패를 명시한다.

**셋업 시점에 라벨이 0건인 경우**: 사용자 레포에 등록된 라벨이 없으면 빈 배열로 저장하고 안내 메시지를 출력한다. 이후 `gh label create`로 라벨을 등록한 뒤 `--reconfigure`로 재선택할 수 있다.

### Worktree base path

이슈마다 fresh 워크트리를 만든다. 워크트리 경로는 `<repo-root>/.worktrees/fix-issue-<issue_number>/`, 브런치명은 `fix/issue-<issue_number>`. 같은 이슈를 재처리해 충돌이 발생하면 스킬이 AskUserQuestion으로 재사용·시퀀스(`-2`, `-3`)·사이클 건너뛰기를 묻는다. 다른 경로 컨벤션을 쓰려면 본 스킬을 fork해 SKILL.md의 Step 5-1 경로를 변경한다 (config 외부화는 단순화를 위해 미지원).

**`.gitignore`에 `.worktrees/` 등록 (필수 권장)**: 워크트리 디렉토리는 main 워킹트리 _내부_(`<repo-root>/.worktrees/`)에 생성되므로 main 입장에서는 `git status`에 untracked 디렉토리로 노출된다. 워크트리는 git이 별도 working tree로 관리하는 독립 자원이고 본 스킬이 만든 사이클 산출물(중간 커밋, 빌드 결과 등)은 main 브런치의 커밋 대상이 아니다. 다음 한 줄을 프로젝트 루트 `.gitignore`에 추가해 노이즈와 실수 커밋을 동시에 차단한다:

```gitignore
# crashlytics-issue-to-fix 스킬이 이슈별로 생성하는 워크트리 디렉토리.
# 각 워크트리는 자체 브런치(`fix/issue-<n>`)로 격리되며, main 트리는 이를 무시한다.
.worktrees/
```

이 항목은 본 스킬을 사용하는 모든 사용자에게 공통이므로, 프로젝트 루트 `.gitignore`에 한 줄을 추가해 팀에 함께 커밋한다 — 워크트리 디렉토리는 main 워킹트리에 untracked로 노출되어 모든 협업자에게 동일하게 보이기 때문이다.

### 워크트리 의존성 처리 (선택 실행)

본 스킬은 워크트리에서 패키지 install·환경 파일 복사·코드 생성을 **자동으로 강제하지 않는다**. 분석은 기본적으로 `Read`/`Grep` 기반이라 셋업 없이 진행되며, SKILL.md Step 5-2가 다음 두 경우에 한해 워크트리에서 명령을 직접 실행한다:

- `verification_summary == test_added`로 테스트 실행이 필요할 때 (예: `npm test`, `pytest`, `go test ./...`, `cargo test`, `flutter test`)
- codegen 산출물이 분석에 필요한데 누락되어 있을 때 (예: `protoc`, `npm run codegen`, `go generate ./...`, `dart run build_runner build`)

이 명령들이 실패하면 사이클은 `failed: env_setup`으로 종결되고 다음 사이클로 진행한다. 워크트리·브런치는 보존되어 사용자가 직접 셋업한 뒤 재처리 가능.

자주 쓰는 절차가 있으면 사용자 메모리 또는 프로젝트 `CLAUDE.md` / `AGENTS.md`에 적어두면, 클로드가 그 절차를 인지해 5-2 안에서 한 번에 명령들을 시도할 수 있다.

**언어별 참고 절차 (예시 — 본인 프로젝트에 맞춰 치환)**:

`..`로 부모 작업 트리의 비커밋 자원(예: `.env.*`, 로컬 시크릿 파일)을 가져올 수 있다. 워크트리는 `<repo-root>/.worktrees/<name>` 구조라 두 단계 위가 repo-root다.

Node / TypeScript:

```bash
cd <repo-root>/.worktrees/fix-issue-<n>
npm ci                        # 또는 pnpm install / yarn install
cp ../../.env .env            # 비커밋 환경 파일이 필요한 경우
npm run codegen               # 프로젝트에 정의되어 있다면
```

Python:

```bash
cd <repo-root>/.worktrees/fix-issue-<n>
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt   # 또는 poetry install / uv sync
cp ../../.env .env
```

Go:

```bash
cd <repo-root>/.worktrees/fix-issue-<n>
go mod download
go generate ./...   # 프로젝트에 정의되어 있다면
```

Rust:

```bash
cd <repo-root>/.worktrees/fix-issue-<n>
cargo fetch
cp ../../.env .env
```

Dart / Flutter:

```bash
cd <repo-root>/.worktrees/fix-issue-<n>
flutter pub get                                         # fvm 사용 시 `fvm flutter pub get`
cp ../../.env.development .env.development              # 환경 파일이 비커밋이라면
dart run build_runner build --delete-conflicting-outputs
```

## 옵셔널: Crashlytics 메타 주석 자동 동기화

본 스킬은 GitHub Issue 본문에 다음 형식의 HTML 주석이 있으면 PR 생성·종결 시 Crashlytics 상태를 자동 동기화한다. 주석은 사용자가 본문에 임의로 적은 텍스트와 충돌하지 않도록 **HTML 주석 영역에만** 매치한다.

- `<!-- app_id: <Firebase 앱 ID> -->`
- `<!-- crashlytics_issue_id: <Crashlytics 이슈 ID> -->`

통합 이슈(iOS+Android)는 두 주석을 본문 등장 순서대로 페어링해 `(app_id, crashlytics_issue_id)` 쌍 배열로 다룬다.

**주석이 없는 경우도 정상 동작**: 일반 버그 라벨 이슈에 메타 주석이 없으면 GitHub만 닫히고 Crashlytics 동기 종결은 건너뛴다(보고서에 "수동 처리 필요" 항목으로 명시). 사용자는 두 가지 방식 중 편한 쪽을 택할 수 있다.

1. **수동 등록**: 이슈 본문에 위 HTML 주석을 직접 추가.
2. **자동 등록(별도 도구)**: Crashlytics → GitHub Issue 등록을 자동화하는 별도 스킬·CI 잡·스크립트가 위 형식을 본문에 박아두면, 본 스킬이 등록된 상태 그대로 소비한다. 이 자동 등록 도구의 존재는 본 스킬의 동작 전제가 아니다.

## Troubleshooting

| 증상                                      | 원인 / 해결                                                                                                                                                                                                                     |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "Firebase MCP tools unavailable"          | MCP 설정에 Firebase 서버가 등록되지 않았다. 클라이언트의 MCP 설정을 확인.                                                                                                                                                       |
| `gh: command not found`                   | GitHub CLI 미설치. https://cli.github.com/ 에서 설치.                                                                                                                                                                           |
| `gh auth status` 실패                     | `gh auth login` 실행.                                                                                                                                                                                                           |
| `firebase login` 반복 요청                | 토큰 만료. 한 번 로그인하면 장기간 유지된다. 반복된다면 Firebase MCP 구현 버그 가능성 — 로그 확인.                                                                                                                              |
| `BASE_BRANCH`가 비어 있다는 종료 메시지   | detached HEAD 상태. `git checkout <정상-브런치>`로 이동 후 재실행.                                                                                                                                                              |
| `git worktree add` 실패: 이미 존재        | 이전 실행에서 거절·실패·충돌로 보존된 워크트리(`fix-issue-<n>`)가 남아 있음. `git worktree list`로 확인 후 `git worktree remove <path>` 또는 Step 6-6의 일괄 정리 사용.                                                         |
| `fix/issue-<n>` 브런치 이미 존재          | 같은 이슈 재처리이거나 이전 거절된 PR의 브런치가 남아 있음. Step 5-1에서 스킬이 재사용/시퀀스(`-2`)/사이클 건너뛰기 옵션을 제시한다.                                                                                            |
| pre-commit hook 실패                      | hook 매니저와 검사 도구는 프로젝트마다 다르다. 스킬은 hook 출력을 그대로 사용자에게 보고하고 멈춘다. 우회·재시도 방법은 사용자가 직접 결정.                                                                                     |
| Crashlytics issue id 추출 실패            | 이슈 본문에 `crashlytics_issue_id` 메타 주석이 없는 경우. 일반 버그 라벨 이슈는 정상이며, GitHub만 닫히고 안내 메시지 출력.                                                                                                     |
| `gh pr merge` 실패: PR 검사 미통과        | 브랜치 보호 규칙으로 머지 차단. 검사 통과를 기다린 뒤 본 스킬을 재실행하거나 사용자가 직접 해당 PR을 머지한 뒤 잔존 워크트리 정리만 수행.                                                                                       |
| 머지 시도 시 `MERGE_CONFLICT`             | 다른 PR이 먼저 머지되어 BASE가 갱신됐고, 본 PR이 같은 파일을 건드림. Step 6-4가 "건너뛰기/직접 해결/중단" 분기를 제시. 직접 해결하려면 보존된 워크트리에서 `git rebase origin/<BASE>` 후 `git push --force-with-lease`.         |
| PR 라벨 부착 실패 (`could not add label`) | `config.github.pr_labels`의 라벨 중 일부가 사용자 레포에 등록되어 있지 않음. 스킬은 라벨 없이 PR 생성을 재시도하고 보고서에 사유를 남긴다. 정상화하려면 `gh label create`로 누락 라벨을 등록하거나 `--reconfigure`로 다시 선택. |
| 셋업 시 라벨 후보 0건                     | 사용자 레포에 등록된 라벨이 없는 상태. `gh label create "<name>" --repo "<owner>/<repo>"`로 라벨을 등록한 뒤 `--reconfigure`로 재진입. 라벨 부착이 필요 없으면 빈 배열 그대로 둬도 무방.                                        |

## Verification Checklist

배포 전 다음을 통과해야 한다.

### 작성자 측: 번들 템플릿 검증

```bash
PLUGIN_ROOT=<easy-claude-code 플러그인 루트>

# 1. skill 디렉토리 구조 확인
ls "$PLUGIN_ROOT/skills/crashlytics-issue-to-fix/"
# expect: SKILL.md, config.json, references/

find "$PLUGIN_ROOT/skills/crashlytics-issue-to-fix/references/" -type f
# expect: installation.md, pr-template.md, report-template.md

# 2. 번들 기본값 템플릿(${CLAUDE_SKILL_DIR}/config.json) 초기값 확인
jq -e '
  .firebase.project_id == null
  and (.firebase.apps | length == 0)
  and .github.repo == null
  and .github.issue_label == null
  and .github.merge_method == "squash"
  and (.github.pr_labels == null)
' "$PLUGIN_ROOT/skills/crashlytics-issue-to-fix/config.json" && echo OK
```

### 사용자 측: 첫 셋업 후 영구 저장소 확인 (런타임)

```bash
# 현재 프로젝트의 PROJECT_KEY 확인
PROJECT_KEY=$(git remote get-url origin 2>/dev/null \
  | sed -E 's|^https?://[^/]+/||; s|^git@[^:]+:||; s|\.git$||; s|/|-|g' \
  | tr '[:upper:]' '[:lower:]')
echo "PROJECT_KEY=$PROJECT_KEY"

# 첫 셋업이 한 번이라도 완료된 뒤에 생성된다 (현재 프로젝트만)
ls ~/.claude/plugins/data/easy-claude-code*/crashlytics-issue-to-fix/projects/$PROJECT_KEY/config.json

# 셋업 결과가 반영됐는지 확인 — 셋업 후 project_id·repo가 채워져 있어야 함
jq '.firebase.project_id, .github.repo' \
  ~/.claude/plugins/data/easy-claude-code*/crashlytics-issue-to-fix/projects/$PROJECT_KEY/config.json

# 모든 프로젝트 셋업 목록 확인 (다중 프로젝트 사용 시)
ls ~/.claude/plugins/data/easy-claude-code*/crashlytics-issue-to-fix/projects/
```
