# Installation Guide

## Prerequisites

- **Claude Code** (or compatible client with Skill tool support)
- **Firebase MCP server** — `mcp__firebase__*` tool family must be accessible in your session. Verify by checking that tools like `mcp__firebase__firebase_get_environment` appear in your tool list.
- **GitHub CLI (`gh`)** — 인증 완료. 확인:
  ```bash
  gh --version
  gh auth status
  ```
  `gh`는 gojq를 임베드해 `--jq` 플래그를 내장 제공하므로 별도 jq 바이너리는 필요하지 않다.
- **`python3`** — config schema 마이그레이션과 이슈 생성 응답 파싱에 1회용으로 사용. 표준 라이브러리(`json`)만 쓰므로 추가 패키지 설치 불필요. macOS 12+ / 대부분 Linux 배포판 / GitHub Codespaces / GitHub Actions runner 모두 기본 탑재.
- **대상 GitHub 레포에 아래 7개 라벨이 사전 등록되어 있어야 함.** 최초 셋업 명령은 아래 "Label Setup" 섹션 참고.
- **대상 GitHub Organization에 Issue Types가 활성화**되어 있고 `config.github.issue_type` 값이 존재 타입이어야 적용된다. 미활성화 조직이거나 타입 미존재라도 1차 시도 실패 시 type 없이 자동 재시도되므로 **이슈 생성 자체는 보장**된다(상세: `issue-template.md`의 Issue Type 섹션). 명시적으로 끄려면 `config.github.issue_type: null`로 설정.

## Installation

이 skill은 `my-skills` 플러그인의 일부로 배포된다. standalone 복사·설치(`~/.claude/skills/<name>/`)는 더 이상 지원하지 않으며, 플러그인 활성화를 통해서만 사용한다.

플러그인 자체 설치·로드 방법은 [my-skills 플러그인 README](../../../README.md) 참고. 개발 시점에는 `claude --plugin-dir <plugin-root>`으로 in-place 로드 후 `/reload-plugins`로 변경 사항을 즉시 반영할 수 있다.

## Storage Layout

플러그인이 활성화되면 두 종류의 config 파일이 사용된다. 두 경로의 책임은 **읽기 전용 기본값**과 **쓰기 가능한 사용자 인스턴스**로 명확히 분리되어 있다.

| 경로                                                                            | 역할                                                                        | 보존 여부                             | 누가 쓰나         |
| ------------------------------------------------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------- | ----------------- |
| `${CLAUDE_SKILL_DIR}/config.json`                                               | 작성자가 번들한 기본값 템플릿(severity 임계치, retry 정책, query 기본값 등) | 플러그인 업데이트 시 새 버전으로 교체 | 작성자(릴리스 시) |
| `${CLAUDE_PLUGIN_DATA}/crashlytics-to-issue/projects/<PROJECT_KEY>/config.json` | 사용자별 + 프로젝트별 셋업 결과(project_id, apps[], repo) + 사용자 튜닝 값  | 플러그인 업데이트 후에도 보존         | skill의 셋업 단계 |

`${CLAUDE_PLUGIN_DATA}`는 `~/.claude/plugins/data/<plugin-id>/`로 해석되며, 플러그인을 마지막 스코프에서 제거할 때(또는 `--keep-data` 없이 uninstall)까지 유지된다.

`<PROJECT_KEY>`는 호출 시점에 다음 우선순위로 자동 추출된다:

1. `git remote get-url origin` 성공 시 `<owner>-<repo>` 형태 (예: `cyb9701-claude-plugins`)
2. 실패 시 `git rev-parse --show-toplevel`의 basename
3. 둘 다 실패 시 `pwd`의 basename

이 키 분리 덕분에 동일 사용자가 여러 프로젝트(예: 회사 repo / 개인 repo / 오픈소스 fork)를 오갈 때 각 프로젝트의 Firebase·repo 셋업이 서로 덮어쓰지 않고 독립 보존된다. 첫 실행 시 해당 프로젝트의 영구 저장소가 비어 있으면 SKILL.md의 Step 2가 자동으로 번들 기본값을 복사한 뒤 대화형 셋업을 시작한다.

## Label Setup (레포 1회 초기화)

이 스킬은 전부 `key:value` 네임스페이스 라벨만 사용한다. 최초 1회, 대상 GitHub 레포에 아래 7개 라벨을 등록해 둬야 이후 `gh api`의 이슈 생성 호출이 라벨 누락으로 422를 반환하지 않는다.

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

- 슬래시 커맨드: `/my-skills:crashlytics-to-issue`
- 자연어: "Crashlytics 이슈를 GitHub에 등록해줘" / "open crashes를 이슈로 올려"

첫 실행 시 현재 프로젝트의 `${CLAUDE_PLUGIN_DATA}/crashlytics-to-issue/projects/<PROJECT_KEY>/config.json`이 없거나 빈 상태이므로 Step 2가 셋업 대화로 진입한다:

1. **Firebase project 선택** — `firebase_list_projects` 결과에서 하나 선택.
2. **Firebase app 선택** — `firebase_list_apps` 결과에서 조회 대상 앱(들)을 선택 (iOS/Android 복수 가능).
3. **GitHub repo 확인** — `git remote get-url origin`에서 자동 파싱. 파싱 실패 시 직접 입력.

입력값은 해당 프로젝트의 `${CLAUDE_PLUGIN_DATA}/crashlytics-to-issue/projects/<PROJECT_KEY>/config.json`에 저장되어 다음 실행부터는 같은 프로젝트에서만 셋업이 생략된다. 다른 프로젝트로 이동하면 그 프로젝트의 별도 PROJECT_KEY 디렉토리에서 새 셋업이 트리거된다.

## Customization

### 제목 포맷과 모듈 추론

**커스터마이즈 불가**. 이슈 제목은 항상 `[Firebase Crashlytics] {module} - {summary}` 형태로 고정된다. `{module}`은 스킬의 LLM이 스택 트레이스를 읽고 현장 언어로 직접 추론한다(예: `광고`, `출금`). 상세는 `issue-template.md`, `module-inference.md` 참고.

### `severity_thresholds`

상세는 `severity-rules.md` 참고. 기본값이 너무 느슨/엄격하다고 판단되면 `config.json`에서 숫자만 조정.

### `query.lookback_days`

조회 대상 기간. 기본 3일. 빈도가 낮은 앱이면 7~14일로 늘리면 된다.

## Troubleshooting

| 증상                               | 원인 / 해결                                                                                                                                                                                                                                 |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "Firebase MCP tools unavailable"   | MCP 설정에 Firebase 서버가 등록되지 않았다. 클라이언트의 MCP 설정을 확인.                                                                                                                                                                   |
| `gh: command not found`            | GitHub CLI 미설치. https://cli.github.com/ 에서 설치.                                                                                                                                                                                       |
| `gh auth status` 실패              | `gh auth login` 실행.                                                                                                                                                                                                                       |
| `firebase login` 반복 요청         | 토큰 만료. 한 번 로그인하면 장기간 유지된다. 반복된다면 Firebase MCP 구현 버그 가능성 — 로그 확인.                                                                                                                                          |
| Issue 생성 실패 422 (라벨 관련)    | 라벨이 레포에 등록되지 않음. 위 "Label Setup" 섹션의 `gh label create` 스크립트를 먼저 실행.                                                                                                                                                |
| Issue 생성 실패 422 (type 관련)    | 1차 시도가 실패하면 type 없이 자동 1회 재시도되므로 정상 경로에서는 보이지 않는다. 그래도 사용자에게 노출됐다면 stdout을 직접 확인하고 라벨·인증 등 다른 422 원인을 점검. type을 영구 비활성화하려면 `config.github.issue_type: null` 설정. |
| `python3: command not found`       | `python3` 미설치. macOS 12+ 와 대부분의 Linux는 기본 탑재. alpine·distroless 같은 미니멀 컨테이너에서는 `apk add python3` / 베이스 이미지를 python 포함 버전으로 교체. config 마이그레이션·응답 파싱 1회용이라 표준 라이브러리만 있으면 충분. |
| 제목의 `{module}`이 자주 `Unknown` | 스택이 외부 SDK·프레임워크 프레임으로만 구성돼 LLM이 app feature를 추론할 수 없을 때 정상 동작. 필요하면 이슈 생성 후 GitHub에서 수동으로 제목을 편집.                                                                                      |

## Verification Checklist

배포 전에 다음을 통과해야 한다.

### 작성자 측: 번들 템플릿 검증

```bash
PLUGIN_ROOT=<my-skills 플러그인 루트>

# 1. skill 디렉토리 구조 확인
ls "$PLUGIN_ROOT/skills/crashlytics-to-issue/"
# expect: SKILL.md, config.json, references/

find "$PLUGIN_ROOT/skills/crashlytics-to-issue/references/" -type f
# expect: installation.md, issue-template.md, note-schema.md,
#         severity-rules.md, module-inference.md, filter-rules.md

# 2. 고유 식별자 누출 검사 (자체 배포물을 포크·수정할 때 사용)
# 자기 조직의 브랜딩/ID/언어별 토큰을 아래 패턴에 채워 넣고 실행.
# 결과가 0건이면 누출 없음.
grep -iE "<your-company>|<your-service>|<your-firebase-project-id>|<your-lang-token>" \
  "$PLUGIN_ROOT/skills/crashlytics-to-issue/SKILL.md" \
  "$PLUGIN_ROOT/skills/crashlytics-to-issue/references/"*.md

# 3. 번들 기본값 템플릿(${CLAUDE_SKILL_DIR}/config.json) 초기값 확인
python3 -c "import json; c=json.load(open('$PLUGIN_ROOT/skills/crashlytics-to-issue/config.json')); \
  assert c['firebase']['project_id'] is None and c['firebase']['apps']==[]; print('OK')"
```

### 사용자 측: 첫 셋업 후 영구 저장소 확인 (런타임)

```bash
# 현재 프로젝트의 PROJECT_KEY 확인
PROJECT_KEY=$(git remote get-url origin 2>/dev/null \
  | sed -E 's|^https?://[^/]+/||; s|^git@[^:]+:||; s|\.git$||; s|/|-|g' \
  | tr '[:upper:]' '[:lower:]')
echo "PROJECT_KEY=$PROJECT_KEY"

# 첫 셋업이 한 번이라도 완료된 뒤에 생성된다 (현재 프로젝트만)
ls ~/.claude/plugins/data/my-skills*/crashlytics-to-issue/projects/$PROJECT_KEY/config.json

# 셋업 결과가 반영됐는지 확인 — 셋업 후 project_id·repo·apps가 채워져 있어야 함
python3 -c "
import json, glob
for p in glob.glob(__import__('os').path.expanduser(
    '~/.claude/plugins/data/my-skills*/crashlytics-to-issue/projects/$PROJECT_KEY/config.json')):
    c = json.load(open(p))
    print('project_id:', c['firebase']['project_id'])
    print('apps      :', c['firebase']['apps'])
    print('repo      :', c['github']['repo'])
"

# 모든 프로젝트 셋업 목록 확인 (다중 프로젝트 사용 시)
ls ~/.claude/plugins/data/my-skills*/crashlytics-to-issue/projects/
```

### Schema v1 → v2 마이그레이션 (옛 사용자만 해당)

이전 버전을 사용하다가 업그레이드된 사용자는 첫 호출 시 SKILL.md Step 2의 자동 마이그레이션이 트리거된다. 의미가 바뀐 부분:

| 변경      | v1                                        | v2                                               |
| --------- | ----------------------------------------- | ------------------------------------------------ |
| 회귀 판정 | `regression.grace_hours` (시간 grace)     | `regression.auto_close` (버전 비교 + 자동 close) |
| 도구 호출 | `gh issue create --type` (gh v2.63+ 필요) | `gh api -X POST repos/.../issues` + bash 변수 quoting (외부 jq 불필요, gh 내장 `--jq` + `python3` 사용) |

#### 자동 마이그레이션 절차 (메인 세션이 1회 수행)

읽은 config의 최상위 `$schema_version`이 누락이거나 `< 2`이면 다음 변환을 적용한 뒤 동일 경로로 다시 저장한다. atomic write(`os.replace`)로 부분 쓰기 시 config가 파괴되는 사고를 차단한다. 알 수 없는 키는 모두 보존되어 사용자 튜닝이 손실되지 않는다.

```bash
python3 - "$CONFIG_FILE" <<'PY'
import json, os, sys, tempfile
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    cfg = json.load(f)

reg = cfg.get("regression") or {}
reg.pop("grace_hours", None)              # v1 키 제거(의미 폐기)
reg.setdefault("auto_close", True)        # 신규 기본값 — 사용자가 false로 둔 경우는 보존
cfg["regression"] = reg
cfg["$schema_version"] = 2

dir_ = os.path.dirname(path) or "."
fd, tmp = tempfile.mkstemp(prefix=".cfg.", dir=dir_)
with os.fdopen(fd, "w", encoding="utf-8") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
    f.write("\n")
os.replace(tmp, path)                     # POSIX rename → atomic
PY
```

마이그레이션이 일어났다면 Step 5 결과 표 머리에 `migrated_to_schema_v2` 1회 안내. 사용자에게 *"`grace_hours`는 더 이상 동작하지 않으며 `auto_close: true`가 기본 적용된다"*는 한 줄을 같이 노출한다.

#### 검증

자동 마이그레이션 후 다음을 확인한다:

```bash
PROJECT_KEY=$(git remote get-url origin 2>/dev/null \
  | sed -E 's|^https?://[^/]+/||; s|^git@[^:]+:||; s|\.git$||; s|/|-|g' \
  | tr '[:upper:]' '[:lower:]')
CFG=~/.claude/plugins/data/my-skills*/crashlytics-to-issue/projects/$PROJECT_KEY/config.json

# 세 가지 검사 한 번에 — python3 표준 라이브러리만 사용
python3 - "$CFG" <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
print("$schema_version == 2 :", c.get("$schema_version") == 2)        # True 기대
print("grace_hours removed  :", "grace_hours" not in c.get("regression", {}))  # True 기대
print("auto_close present   :", "auto_close" in c.get("regression", {}))       # True 기대 (사용자가 false로 둔 경우는 그 값 보존)
print("auto_close value     :", c.get("regression", {}).get("auto_close"))
PY
```

세 검사가 모두 `True`로 출력되면 마이그레이션 정상 완료.
