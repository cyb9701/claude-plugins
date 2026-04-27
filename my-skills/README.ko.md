# my-skills

🌐 [English](README.md) | **한국어**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](../LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-orange)](https://github.com/anthropics/claude-code)

> 프롬프트 정제와 Firebase Crashlytics 자동화 스킬을 번들한 Claude Code 플러그인입니다.
> **공식 Anthropic 제품이 아닌 개인 프로젝트입니다.**

## 스킬 목록

| 스킬                       | 호출 형식                                           | 용도                                                                                                            |
| -------------------------- | --------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `prompt-refine`            | `/my-skills:prompt-refine <텍스트>`                 | 원본 의도를 보존하면서 사용자 프롬프트를 Claude 최적화 형태로 재구성합니다.                                     |
| `crashlytics-to-issue`     | `/my-skills:crashlytics-to-issue`                   | Firebase Crashlytics의 미해결 크래시·ANR을 GitHub Issue로 동기화하고 회귀를 자동 감지합니다.                    |
| `crashlytics-issue-to-fix` | `/my-skills:crashlytics-issue-to-fix [<issue#>...]` | Crashlytics 연동 GitHub Issue를 워크트리 격리 환경에서 분석하고, 이슈마다 PR 1개를 생성해 일괄 검토·머지합니다. |

## 설치

### 마켓플레이스를 통한 설치 (권장)

Claude Code를 열고 세션 안에서 아래 명령을 실행합니다:

```shell
/plugin marketplace add cyb9701/claude-plugins
/plugin install my-skills@claude-plugins
/reload-plugins
```

> **설치 범위는 자유롭게 선택 가능** — Crashlytics 계열 스킬은 git remote의 `<owner>-<repo>` 키로 프로젝트별 config를 자동 격리합니다. `user` 범위로 설치해도 각 프로젝트의 Firebase 셋업이 별도 디렉토리에 보관됩니다. `project`/`local` 범위는 플러그인 활성화/비활성화 자체를 프로젝트별로 통제하고 싶을 때만 선택하세요.

### 로컬 개발

```bash
git clone https://github.com/cyb9701/claude-plugins.git
claude --plugin-dir ./claude-plugins/my-skills
```

재시작 없이 변경 사항을 적용하려면:

```shell
/reload-plugins
```

## 사전 요구사항

### 공통

- Claude Code 최신 버전 (플러그인 시스템 지원)

### Crashlytics 관련 스킬 (`crashlytics-to-issue`, `crashlytics-issue-to-fix`)

- Firebase MCP 도구군 (`mcp__firebase__*`) 활성화
- GitHub CLI (`gh`) 인증 완료 (`gh auth status`로 확인)
- `git` 2.5+ (`crashlytics-issue-to-fix`의 워크트리 기반 동작에 필수)
- 첫 실행 시 자동 셋업 대화에서 프로젝트·앱·레포·라벨 선택

상세 환경 셋업은 각 스킬의 `references/installation.md`를 참고하세요.

### `prompt-refine`

외부 의존성 없음 — `AskUserQuestion`만 사용하는 폐쇄형 텍스트 변환기입니다.

## 사용 예시

### 프롬프트 정제

```shell
/my-skills:prompt-refine 이 프롬프트 다듬어줘: "코드 리뷰 부탁해"
```

### Crashlytics 크래시를 GitHub Issue로 동기화

```shell
/my-skills:crashlytics-to-issue
```

### Crashlytics Issue 자동 수정

```shell
# 라벨로 조회된 모든 이슈 처리
/my-skills:crashlytics-issue-to-fix

# 특정 이슈만 지정
/my-skills:crashlytics-issue-to-fix 150 151 152
```

## 설정 저장소

Crashlytics 계열 두 스킬은 사용자별 + **프로젝트별** 셋업 결과(Firebase project ID, GitHub repo, 라벨 선택 등)를 번들 기본값과 분리된 위치에 영구 저장합니다. 플러그인 업데이트는 번들 기본값을 교체하지만, 사용자 데이터는 덮어쓰지 않으며, 각 프로젝트는 자기만의 격리된 서브디렉토리를 갖기 때문에 같은 머신에서 여러 프로젝트가 서로의 설정을 덮어쓰는 일이 없습니다.

| 경로                                                                  | 역할                                                | 업데이트 후 보존 여부        |
| --------------------------------------------------------------------- | --------------------------------------------------- | ---------------------------- |
| `${CLAUDE_SKILL_DIR}/config.json`                                     | 번들 기본값 템플릿 (severity 임계치, retry 정책 등) | 업데이트 시 새 버전으로 교체 |
| `${CLAUDE_PLUGIN_DATA}/<skill-name>/projects/<PROJECT_KEY>/config.json` | 사용자별 + 프로젝트별 셋업 결과                     | 업데이트 후에도 보존         |

`${CLAUDE_PLUGIN_DATA}`는 실제로 `~/.claude/plugins/data/my-skills*/` 경로로 해석됩니다(마켓플레이스 ID에 따라 suffix가 붙음).

`<PROJECT_KEY>`는 호출 시점에 다음 우선순위로 자동 추출됩니다:

1. `git remote get-url origin` 성공 시 `<owner>-<repo>` 형태 (예: `cyb9701-claude-plugins`)
2. 실패 시 `git rev-parse --show-toplevel`의 basename
3. 둘 다 실패 시 `pwd`의 basename

이 키 분리 덕분에 동일 사용자가 여러 프로젝트(회사 repo / 개인 repo / 오픈소스 fork 등)를 오갈 때 각 프로젝트의 Crashlytics 셋업이 서로 충돌하지 않고 독립 보존됩니다. 첫 실행 시 해당 프로젝트의 사용자 영구 저장소가 비어 있으면 스킬이 번들 기본값을 복사한 뒤 대화형 셋업을 자동으로 시작합니다.

설정을 다시 받으려면:

```shell
/my-skills:crashlytics-to-issue --reconfigure
/my-skills:crashlytics-issue-to-fix --reconfigure
```

`prompt-refine`은 외부 config가 없으므로 이 절의 영향을 받지 않습니다.

## 디렉토리 구조

```
my-skills/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── README.ko.md
└── skills/
    ├── crashlytics-issue-to-fix/
    │   ├── SKILL.md
    │   ├── config.json
    │   └── references/
    ├── crashlytics-to-issue/
    │   ├── SKILL.md
    │   ├── config.json
    │   └── references/
    └── prompt-refine/
        ├── SKILL.md
        ├── evals/
        └── references/
```

런타임 사용자 데이터(`~/.claude/plugins/data/my-skills*/`)는 플러그인에 포함되지 않으며, 첫 셋업 시 자동으로 생성됩니다.

## 라이선스

MIT
