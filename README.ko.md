# easy-claude-code

🌐 [English](README.md) | **한국어**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-orange)](https://github.com/anthropics/claude-code)

> Claude Code를 더 잘 활용하기 위한 실용적인 도구 모음입니다.
> **공식 Anthropic 제품이 아닌 개인 프로젝트입니다.**

## 스킬 목록

| 스킬                       | 호출 형식                                                      | 용도                                                                                          |
| -------------------------- | -------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `prompt-refine`            | `/easy-claude-code:prompt-refine <텍스트>`                     | 원본 의도를 보존하면서 사용자 프롬프트를 Claude 최적화 형태로 재구성합니다.                   |
| `crashlytics-to-issue`     | `/easy-claude-code:crashlytics-to-issue`                       | Firebase Crashlytics의 미해결 크래시·ANR을 GitHub Issue로 동기화하고 회귀를 자동 감지합니다.  |
| `crashlytics-issue-to-fix` | `/easy-claude-code:crashlytics-issue-to-fix [<issue#>...]`     | Crashlytics 연동 GitHub Issue를 워크트리 격리 환경에서 분석하고 이슈마다 PR 1개를 생성합니다. |

## 커맨드 목록

| 커맨드       | 호출 형식                                                      | 용도                                                                                                    |
| ------------ | -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| `skill-tree` | `/easy-claude-code:skill-tree [<lang>] [<query>]`              | 활성 플러그인·user·project 영역의 스킬을 테이블로 출력합니다. 키워드 필터링과 번역을 지원합니다.        |

## 빠른 시작

Claude Code를 열고 세션 안에서 아래 명령을 실행합니다:

```shell
/plugin marketplace add cyb9701/easy-claude-code
/plugin install easy-claude-code@easy-claude-code
/reload-plugins
```

설치 후 `easy-claude-code` 네임스페이스로 스킬을 사용합니다:

```shell
/easy-claude-code:prompt-refine <텍스트>
/easy-claude-code:crashlytics-to-issue
/easy-claude-code:crashlytics-issue-to-fix
```

전체 사전 요구사항과 사용 예시는 [`easy-claude-code/README.md`](./easy-claude-code/README.md)를 참고하세요.

## 라이선스

MIT
