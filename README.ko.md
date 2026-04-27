# claude-plugins

🌐 [English](README.md) | **한국어**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-orange)](https://github.com/anthropics/claude-code)

> Claude Code 플러그인을 모아둔 개인 마켓플레이스입니다.
> **공식 Anthropic 제품이 아닌 개인 프로젝트입니다.**

각 플러그인은 자신만의 최상위 디렉토리와 독립된 `plugin.json` 매니페스트를 가지며, 단독으로 설치 가능합니다.

## 플러그인 목록

| 플러그인                              | 설명                                                                                                                                                          |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [**my-skills**](./my-skills)          | Claude Code 스킬 모음 — 프롬프트 정제, Firebase Crashlytics ↔ GitHub Issue 자동화(등록·회귀 감지·워크트리 기반 자동 수정).                                    |

## `my-skills` 내부 스킬

| 스킬                       | 호출 형식                                           | 용도                                                                                                       |
| -------------------------- | --------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| `prompt-refine`            | `/my-skills:prompt-refine <텍스트>`                 | 원본 의도를 보존하면서 사용자 프롬프트를 Claude 최적화 형태로 재구성합니다.                                |
| `crashlytics-to-issue`     | `/my-skills:crashlytics-to-issue`                   | Firebase Crashlytics의 미해결 크래시·ANR을 GitHub Issue로 동기화하고 회귀를 자동 감지합니다.               |
| `crashlytics-issue-to-fix` | `/my-skills:crashlytics-issue-to-fix [<issue#>...]` | Crashlytics 연동 GitHub Issue를 워크트리 격리 환경에서 분석하고 이슈마다 PR 1개를 생성합니다.              |

## 빠른 시작

Claude Code를 열고 세션 안에서 아래 명령을 실행합니다:

```shell
# 1. 마켓플레이스 추가
/plugin marketplace add cyb9701/claude-plugins

# 2. 플러그인 설치
/plugin install my-skills@claude-plugins

# 3. 플러그인 활성화
/reload-plugins
```

설치 후 `my-skills` 네임스페이스로 스킬을 사용합니다:

```shell
/my-skills:prompt-refine <텍스트>
/my-skills:crashlytics-to-issue
/my-skills:crashlytics-issue-to-fix
```

전체 사전 요구사항과 사용 예시는 [`my-skills/README.md`](./my-skills/README.md)를 참고하세요.

## 라이선스

MIT
