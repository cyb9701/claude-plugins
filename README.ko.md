# claude-plugins

🌐 [English](README.md) | **한국어**

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-orange)](https://github.com/anthropics/claude-code)

> Claude Code용 개인 플러그인 마켓플레이스입니다.
> **공식 Anthropic 제품이 아닌 개인 프로젝트입니다.**

## 플러그인 목록

| 플러그인                                 | 설명                                                                    | 문서                                                                                |
| ---------------------------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| [`easy-claude-code`](./easy-claude-code) | 프롬프트 개선, Firebase Crashlytics 자동화, 스킬 탐색을 위한 스킬 모음. | [English](./easy-claude-code/README.md) · [한국어](./easy-claude-code/README.ko.md) |

## 빠른 시작

Claude Code를 열고 마켓플레이스를 한 번 추가합니다:

```shell
/plugin marketplace add cyb9701/claude-plugins
```

위 표에서 플러그인을 골라 설치하고 다시 로드합니다:

```shell
/plugin install <plugin>@cyb9701-claude-plugins
/reload-plugins
```

예를 들어 다음 명령은 `easy-claude-code`를 설치합니다:

```shell
/plugin install easy-claude-code@cyb9701-claude-plugins
```

플러그인 스킬은 `/<plugin>:<skill>` 형식으로 호출합니다. 스킬 목록, 사전 요구사항, 사용 예시는 각 플러그인의 README를 참고하세요.

## 저장소 구조

```text
.
├── .claude-plugin/
│   └── marketplace.json    # 마켓플레이스 카탈로그
└── <plugin>/
    ├── .claude-plugin/
    │   └── plugin.json     # 플러그인 매니페스트
    ├── skills/
    ├── README.md
    └── README.ko.md
```

## 플러그인 추가

1. 위 구조로 `<plugin>/` 폴더를 만듭니다. 플러그인 이름은 기능을 나타내도록 정합니다. 이름은 `claude-`로 시작할 수 없습니다.
2. `<plugin>/.claude-plugin/plugin.json`에 `name`, `description`, `version`, `author`를 씁니다.
3. `.claude-plugin/marketplace.json`의 `plugins` 배열에 플러그인을 추가합니다:

   ```json
   {
     "name": "<plugin>",
     "source": "./<plugin>",
     "description": "<한 줄 설명>"
   }
   ```

4. `README.md`와 `README.ko.md`의 [플러그인 목록](#플러그인-목록) 표에 행을 추가합니다.
5. 저장소 루트에서 `claude plugin validate .`를 실행합니다. 커밋하기 전에 오류를 모두 수정합니다.

## 라이선스

MIT
