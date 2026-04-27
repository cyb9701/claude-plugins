# Installation Guide

## Prerequisites

- **Claude Code** (or compatible client with Skill tool support)
- **Firebase MCP server** — `mcp__firebase__*` tool family must be accessible in your session. Verify by checking that tools like `mcp__firebase__firebase_get_environment` appear in your tool list.
- **GitHub CLI (`gh`)** — **v2.63 이상** (Issue Type `--type` 플래그 지원). 인증 완료. 확인:
  ```bash
  gh --version | head -1   # "gh version 2.63.x" 이상이어야 함
  gh auth status
  ```
- **대상 GitHub 레포에 아래 7개 라벨이 사전 등록되어 있어야 함.** 최초 셋업 명령은 아래 "Label Setup" 섹션 참고.
- **대상 GitHub Organization에 Issue Types가 활성화**되어 있고 `config.github.issue_type` 값이 존재 타입이어야 함. 미활성화 조직은 `config.github.issue_type: null`로 설정해 플래그 생략 가능.

## Install Locations

두 가지 권장 위치가 있다. 상황에 맞게 선택한다.

### A. User-global (개인 개발자 기본값)

```
~/.claude/skills/crashlytics-to-issue/
```

- 모든 프로젝트에서 같은 스킬을 사용.
- 단일 `config.json`을 여러 프로젝트가 공유 — 한 사람이 여러 Firebase 프로젝트를 오가는 경우 `--reconfigure`로 매번 전환.

### B. Project-local (팀 배포 기본값)

```
<your-repo>/.claude/skills/crashlytics-to-issue/
```

- `config.json`이 저장소에 커밋되어 팀원 전원이 동일한 설정으로 동작.
- 팀마다 별도 Firebase 프로젝트·GitHub 레포를 쓰는 경우에 적합.

## Installation Steps

1. 이 스킬 디렉토리 전체를 원하는 위치에 복사:

   ```bash
   # user-global 예시
   cp -r crashlytics-to-issue ~/.claude/skills/

   # project-local 예시
   cp -r crashlytics-to-issue <your-repo>/.claude/skills/
   ```

2. 복사된 디렉토리에 `SKILL.md`, `config.json`, `references/`가 모두 있는지 확인.
3. 클라이언트를 재시작하거나 skill refresh를 수행해 스킬 목록에 반영.

## Label Setup (레포 1회 초기화)

이 스킬은 전부 `key:value` 네임스페이스 라벨만 사용한다. 최초 1회, 대상 GitHub 레포에 아래 7개 라벨을 등록해 둬야 이후 `gh issue create --label`이 422 없이 통과한다.

```bash
REPO="<owner>/<repo>"  # 예: your-org/your-app

# 기본 7개 라벨 등록 (이미 존재하면 --force로 덮어쓰거나 에러 무시)
gh label create "source:crashlytics"  --repo "$REPO" --description "From Crashlytics" --color "B60205" 2>/dev/null || true
gh label create "os:ios"               --repo "$REPO" --description "iOS platform"     --color "0E8A16" 2>/dev/null || true
gh label create "os:android"           --repo "$REPO" --description "Android platform" --color "0E8A16" 2>/dev/null || true
gh label create "severity:blocker"     --repo "$REPO" --description "Blocker"          --color "B60205" 2>/dev/null || true
gh label create "severity:critical"    --repo "$REPO" --description "Critical"         --color "D93F0B" 2>/dev/null || true
gh label create "severity:major"       --repo "$REPO" --description "Major"            --color "FBCA04" 2>/dev/null || true
gh label create "state:regression"     --repo "$REPO" --description "Regression"       --color "5319E7" 2>/dev/null || true
```

커스텀 심각도 레벨(예: `severity:minor`)이나 커스텀 state 값을 추가한다면 같은 방식으로 미리 등록한다.

**확인**:

```bash
for L in "source:crashlytics" "os:ios" "os:android" \
         "severity:blocker" "severity:critical" "severity:major" \
         "state:regression"; do
  gh label list --repo "$REPO" --search "$L" \
    --json name --jq ".[] | select(.name == \"$L\") | .name" \
    | grep -q "^$L\$" || echo "MISSING: $L"
done
```

출력이 없으면 모든 라벨이 존재.

## First Run (대화형 셋업)

스킬을 호출한다:

- 슬래시 커맨드: `/crashlytics-to-issue`
- 자연어: "Crashlytics 이슈를 GitHub에 등록해줘" / "open crashes를 이슈로 올려"

첫 실행 시 `config.json`이 빈 상태이므로 Step 2가 셋업 대화로 진입한다:

1. **Firebase project 선택** — `firebase_list_projects` 결과에서 하나 선택.
2. **Firebase app 선택** — `firebase_list_apps` 결과에서 조회 대상 앱(들)을 선택 (iOS/Android 복수 가능).
3. **GitHub repo 확인** — `git remote get-url origin`에서 자동 파싱. 파싱 실패 시 직접 입력.

입력값은 `config.json`에 저장되어 다음 실행부터는 생략된다.

## Customization

### 제목 포맷과 모듈 추론

**커스터마이즈 불가**. 이슈 제목은 항상 `[Firebase Crashlytics] {module} - {summary}` 형태로 고정된다. `{module}`은 스킬의 LLM이 스택 트레이스를 읽고 현장 언어로 직접 추론한다(예: `광고`, `출금`). 상세는 `issue-template.md`, `module-inference.md` 참고.

### `severity_thresholds`

상세는 `severity-rules.md` 참고. 기본값이 너무 느슨/엄격하다고 판단되면 `config.json`에서 숫자만 조정.

### `query.lookback_days`

조회 대상 기간. 기본 3일. 빈도가 낮은 앱이면 7~14일로 늘리면 된다.

## Troubleshooting

| 증상                                        | 원인 / 해결                                                                                                                                                                                           |
| ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "Firebase MCP tools unavailable"            | MCP 설정에 Firebase 서버가 등록되지 않았다. 클라이언트의 MCP 설정을 확인.                                                                                                                             |
| `gh: command not found`                     | GitHub CLI 미설치. https://cli.github.com/ 에서 설치.                                                                                                                                                 |
| `gh auth status` 실패                       | `gh auth login` 실행.                                                                                                                                                                                 |
| `firebase login` 반복 요청                  | 토큰 만료. 한 번 로그인하면 장기간 유지된다. 반복된다면 Firebase MCP 구현 버그 가능성 — 로그 확인.                                                                                                    |
| Issue 생성 실패 422 (라벨 관련)             | 라벨이 레포에 등록되지 않음. 위 "Label Setup" 섹션의 `gh label create` 스크립트를 먼저 실행.                                                                                                          |
| Issue 생성 실패 422 (type 관련)             | `config.github.issue_type` 값이 조직의 Issue Types에 존재하지 않거나 Issue Types가 비활성화됨. 조직 Settings → Issue Types에서 타입을 추가하거나, `issue_type: null`로 설정해 `--type` 플래그를 생략. |
| `unknown flag: --type`                      | `gh` 버전이 2.63 미만. `brew upgrade gh`(macOS) 또는 https://cli.github.com/ 에서 업그레이드. 임시 우회로 `issue_type: null` 설정 가능.                                                               |
| 제목의 `{module}`이 자주 `Unknown`         | 스택이 외부 SDK·프레임워크 프레임으로만 구성돼 LLM이 app feature를 추론할 수 없을 때 정상 동작. 필요하면 이슈 생성 후 GitHub에서 수동으로 제목을 편집.                                                 |

## Verification Checklist

배포 전에 다음을 통과해야 한다:

```bash
# 1. 구조
ls <install_path>/crashlytics-to-issue/
# expect: SKILL.md, config.json, references/

find <install_path>/crashlytics-to-issue/references/ -type f
# expect: installation.md, issue-template.md, note-schema.md,
#         severity-rules.md, module-inference.md, filter-rules.md

# 2. 고유 식별자 누출 검사 (자체 배포물을 포크·수정할 때 사용)
# 자기 조직의 브랜딩/ID/언어별 토큰을 아래 패턴에 채워 넣고 실행.
# 결과가 0건이면 누출 없음.
grep -iE "<your-company>|<your-service>|<your-firebase-project-id>|<your-lang-token>" \
  <install_path>/crashlytics-to-issue/SKILL.md \
  <install_path>/crashlytics-to-issue/references/*.md

# 3. config.json 초기값 확인
python3 -c "import json; c=json.load(open('<install_path>/crashlytics-to-issue/config.json')); \
  assert c['firebase']['project_id'] is None and c['firebase']['apps']==[]; print('OK')"
```
