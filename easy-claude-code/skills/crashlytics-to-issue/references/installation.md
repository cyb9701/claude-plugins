# Installation Guide

## Prerequisites

- **Claude Code** (or compatible client with Skill tool support)
- **Firebase MCP server** — `mcp__firebase__*` tool family이 세션에서 가용해야 한다. `mcp__firebase__firebase_get_environment` 같은 도구가 목록에 보이는지 확인.
- **GitHub CLI (`gh`)** — 인증 완료. 확인: `gh --version` / `gh auth status`. `gh`는 gojq를 임베드해 `--jq` 플래그를 내장 제공하므로 별도 jq 바이너리는 불필요.
- **`python3`** — 이슈 생성 응답 파싱 1회용. 표준 라이브러리(`json`)만 쓰므로 추가 패키지 불필요. macOS 12+ / 대부분 Linux 배포판 / GitHub Codespaces 기본 탑재.
- **대상 GitHub 레포에 아래 7개 라벨이 사전 등록**되어 있어야 한다. 셋업 명령은 "Label Setup" 섹션 참고.

## Installation

이 skill은 `easy-claude-code` 플러그인의 일부로 배포된다. 플러그인 활성화를 통해서만 사용한다.

플러그인 자체 설치·로드 방법은 [easy-claude-code 플러그인 README](../../../README.md) 참고. 개발 시점에는 `claude --plugin-dir <plugin-root>`으로 in-place 로드 후 `/reload-plugins`로 변경 사항을 반영할 수 있다.

## Storage Layout

플러그인이 활성화되면 두 종류의 config 파일이 사용된다.

| 경로                                                                            | 역할                                           | 보존 여부                             | 누가 쓰나         |
| ------------------------------------------------------------------------------- | ---------------------------------------------- | ------------------------------------- | ----------------- |
| `${CLAUDE_SKILL_DIR}/config.json`                                               | 작성자가 번들한 기본값 템플릿                  | 플러그인 업데이트 시 새 버전으로 교체 | 작성자(릴리스 시) |
| `${CLAUDE_PLUGIN_DATA}/crashlytics-to-issue/projects/<PROJECT_KEY>/config.json` | 사용자별·프로젝트별 셋업 결과 + 사용자 튜닝 값 | 플러그인 업데이트 후에도 보존         | skill의 셋업 단계 |

`${CLAUDE_PLUGIN_DATA}`는 `~/.claude/plugins/data/<plugin-id>/`로 해석된다.

`<PROJECT_KEY>`는 호출 시점에 다음 우선순위로 자동 추출된다:

1. `git remote get-url origin` 성공 시 `<owner>-<repo>` 형태 (예: `cyb9701-easy-claude-code`)
2. 실패 시 `git rev-parse --show-toplevel`의 basename
3. 둘 다 실패 시 `pwd`의 basename

이 키 분리 덕분에 동일 사용자가 여러 프로젝트(회사 repo / 개인 repo / OSS fork)를 오갈 때 각 프로젝트의 셋업이 서로 덮어쓰지 않고 독립 보존된다.

## Label Setup (레포 1회 초기화)

전부 `key:value` 네임스페이스 라벨이다. 최초 1회 대상 레포에 아래 7개를 등록해야 이슈 생성이 422 라벨 누락으로 실패하지 않는다.

```bash
REPO="<owner>/<repo>"  # 예: your-org/your-app

gh label create "source:crashlytics"  --repo "$REPO" --description "From Crashlytics" --color "B60205" 2>/dev/null || true
gh label create "os:ios"               --repo "$REPO" --description "iOS platform"     --color "0E8A16" 2>/dev/null || true
gh label create "os:android"           --repo "$REPO" --description "Android platform" --color "0E8A16" 2>/dev/null || true
gh label create "severity:blocker"     --repo "$REPO" --description "Blocker"          --color "B60205" 2>/dev/null || true
gh label create "severity:critical"    --repo "$REPO" --description "Critical"         --color "D93F0B" 2>/dev/null || true
gh label create "severity:major"       --repo "$REPO" --description "Major"            --color "FBCA04" 2>/dev/null || true
gh label create "state:regression"     --repo "$REPO" --description "Regression"       --color "5319E7" 2>/dev/null || true
```

커스텀 severity 레벨(예: `severity:minor`)을 추가하면 같은 방식으로 미리 등록.

## First Run (대화형 셋업)

스킬 호출:

- 슬래시 커맨드: `/easy-claude-code:crashlytics-to-issue`
- 자연어: "Crashlytics 이슈를 GitHub에 등록해줘" / "open crashes를 이슈로 올려"

첫 실행 시 현재 프로젝트의 영구 저장소가 비어 있으므로 셋업 대화로 진입한다:

1. **Firebase project 선택** — `firebase_list_projects` 결과에서 하나 선택.
2. **Firebase app 선택** — `firebase_list_apps` 결과에서 조회 대상 앱(들) 선택 (iOS/Android 복수 가능).
3. **GitHub repo 확인** — `git remote get-url origin`에서 자동 파싱. 실패 시 직접 입력.

입력값은 해당 프로젝트의 `${CLAUDE_PLUGIN_DATA}/.../projects/<PROJECT_KEY>/config.json`에 저장. 다음 실행부터 셋업이 생략되며, 다른 프로젝트로 이동하면 그 프로젝트의 별도 PROJECT_KEY 디렉토리에서 새 셋업이 트리거된다.

## Customization

- **제목 포맷·모듈 추론**: 커스터마이즈 불가. 제목은 항상 `[Firebase Crashlytics] {module} - {summary}`. `{module}`은 LLM이 직접 추론 (`module-inference.md` 참고).
- **`severity_thresholds`**: 너무 느슨/엄격하면 사용자 인스턴스 config의 숫자만 조정 (`severity-rules.md`).
- **`query.lookback_days`**: 기본 3일. 빈도가 낮은 앱이면 7~14일.

## Troubleshooting

| 증상                               | 원인 / 해결                                                                                     |
| ---------------------------------- | ----------------------------------------------------------------------------------------------- |
| "Firebase MCP tools unavailable"   | MCP 설정에 Firebase 서버가 등록되지 않았다. 클라이언트의 MCP 설정을 확인.                       |
| `gh: command not found`            | GitHub CLI 미설치. https://cli.github.com/ 에서 설치.                                           |
| `gh auth status` 실패              | `gh auth login` 실행.                                                                           |
| `firebase login` 반복 요청         | 토큰 만료. 한 번 로그인하면 장기간 유지. 반복되면 Firebase MCP 구현 버그 가능성.                |
| Issue 생성 실패 422 (라벨 관련)    | 라벨이 레포에 미등록. 위 "Label Setup"의 `gh label create` 스크립트를 먼저 실행.                |
| `python3: command not found`       | macOS 12+ / 대부분 Linux는 기본 탑재. 미니멀 컨테이너에서는 `apk add python3` 등으로 설치.      |
| 제목의 `{module}`이 자주 `Unknown` | 스택이 외부 SDK·프레임워크 프레임으로만 구성돼 LLM이 app feature를 추론할 수 없을 때 정상 동작. |

## Verification Checklist

### 작성자 측: 번들 템플릿 검증

```bash
PLUGIN_ROOT=<easy-claude-code 플러그인 루트>

ls "$PLUGIN_ROOT/skills/crashlytics-to-issue/"
# expect: SKILL.md, config.json, references/

# 번들 기본값 템플릿의 초기값 확인 — project_id·apps가 비어 있어야 새 사용자가 셋업으로 진입
python3 -c "import json; c=json.load(open('$PLUGIN_ROOT/skills/crashlytics-to-issue/config.json')); \
  assert c['firebase']['project_id'] is None and c['firebase']['apps']==[]; print('OK')"
```

### 사용자 측: 첫 셋업 후 영구 저장소 확인

```bash
PROJECT_KEY=$(git remote get-url origin 2>/dev/null \
  | sed -E 's|^https?://[^/]+/||; s|^git@[^:]+:||; s|\.git$||; s|/|-|g' \
  | tr '[:upper:]' '[:lower:]')
echo "PROJECT_KEY=$PROJECT_KEY"

# 셋업 결과가 반영됐는지 확인
python3 -c "
import json, glob, os
for p in glob.glob(os.path.expanduser(
    '~/.claude/plugins/data/easy-claude-code*/crashlytics-to-issue/projects/$PROJECT_KEY/config.json')):
    c = json.load(open(p))
    print('project_id:', c['firebase']['project_id'])
    print('apps      :', c['firebase']['apps'])
    print('repo      :', c['github']['repo'])
"
```
