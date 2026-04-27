# my-skills

Claude Code 작업을 위한 유용한 skills 모음 플러그인.

## 포함된 Skills

| Skill | 호출 형식 | 용도 |
|-------|----------|------|
| `prompt-refine` | `/my-skills:prompt-refine <텍스트>` | 사용자 프롬프트를 Claude에 최적화된 형태로 재구성. 의도 보존 우선 텍스트 변환기 |
| `crashlytics-to-issue` | `/my-skills:crashlytics-to-issue` | Firebase Crashlytics의 미해결 크래시·ANR을 GitHub Issue로 자동 등록·동기화. 회귀(regression) 자동 감지 포함 |
| `crashlytics-issue-to-fix` | `/my-skills:crashlytics-issue-to-fix [<issue#>...]` | GitHub Issue로 적재된 Crashlytics 오류를 워크트리 격리 환경에서 분석·수정·PR 생성·일괄 머지 |

## 설치

### 로컬 테스트 (개발 중)

플러그인을 마켓플레이스에 등록하지 않고 직접 로드합니다.

```bash
claude --plugin-dir /Users/cyb/dev/choi/claude-plugins/my-skills
```

세션 내에서 변경 사항을 적용하려면 다음 명령으로 핫 리로드 가능합니다.

```text
/reload-plugins
```

### 마켓플레이스를 통한 설치 (배포 후)

향후 마켓플레이스 등록이 완료되면 표준 플러그인 설치 절차로 사용합니다.

```text
/plugin install my-skills@<marketplace>
```

## Prerequisites

각 skill의 동작 환경 요구사항입니다.

### 공통

- Claude Code 최신 버전 (플러그인 시스템 지원)

### Crashlytics 관련 skill (`crashlytics-to-issue`, `crashlytics-issue-to-fix`)

- Firebase MCP 도구군 (`mcp__firebase__*`) 활성화
- GitHub CLI (`gh`) 인증 완료 (`gh auth status`로 확인)
- `git` 2.5+ (`crashlytics-issue-to-fix`의 워크트리 기반 동작에 필수)
- 첫 실행 시 자동 셋업 대화에서 프로젝트·앱·레포·라벨 선택

상세 환경 셋업은 각 skill의 `references/installation.md`를 참고하세요.

### prompt-refine

- 별도 외부 의존성 없음 (`AskUserQuestion`만 사용하는 폐쇄형 텍스트 변환기)

## 사용 예시

### 프롬프트 개선

```text
/my-skills:prompt-refine 이 프롬프트 다듬어줘: "코드 리뷰 부탁해"
```

### Crashlytics 크래시를 GitHub 이슈로 동기화

```text
/my-skills:crashlytics-to-issue
```

### GitHub 이슈로 등록된 Crashlytics 오류 자동 수정

```text
# label로 조회된 모든 이슈 처리
/my-skills:crashlytics-issue-to-fix

# 특정 이슈만 지정
/my-skills:crashlytics-issue-to-fix 150 151 152
```

## 디렉토리 구조

```
my-skills/
├── .claude-plugin/
│   └── plugin.json
├── README.md
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

## 라이선스 / 배포

- 작성자: cyb9701 (cyb9701@gmail.com)
- 버전: 1.0.0

향후 마켓플레이스 공식 등록이 진행되면 이 섹션에 라이선스·repository·homepage 정보가 추가됩니다.
