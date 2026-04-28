# Subagent Contract — 조회 + 후처리 + 본문 렌더

Step 3의 앱별 서브에이전트는 단순 fetcher가 아니다. Crashlytics 조회, 모듈 추론, 심각도 계산, GitHub 이슈 body 렌더링까지 전부 서브에이전트 컨텍스트에서 끝낸다. 메인 세션은 **이미 렌더된 결과**만 받아 분류·발행한다.

이 설계는 두 가지를 동시에 해결한다:

- **메인 context 토큰 절약**: full stack trace(이슈당 2~5KB)·raw notes[]가 메인에 흡수되지 않는다.
- **모듈 추론 품질**: 스택을 서브에이전트가 **직접** 읽는 동안 추론하므로, 메인이 요약본에서 재추론하는 구조보다 정확하다.

## 서브에이전트 프롬프트 템플릿

메인 세션은 각 앱마다 아래 프롬프트로 `Agent({ subagent_type: "general-purpose" })`를 디스패치한다. `<...>` 자리는 메인이 채워 넣는다.

```
너는 Crashlytics → GitHub Issue 자동화 스킬의 앱별 조회 서브에이전트다.
대상 앱: app_id=<app_id>, platform=<platform>, display_name=<display_name>

다음 설정을 참고하라(메인이 이미 계산해서 전달):
- repo: <config.github.repo>
- lookback_days: <config.query.lookback_days>
- module.language: <config.module.language>   # 예: "ko"
- severity_thresholds: <config.severity_thresholds JSON>

(서브에이전트는 회귀 판정에 관여하지 않는다 — 그건 메인이 max_app_version을 받아서 처리.)

반드시 읽을 reference:
- references/issue-template.md — 제목·본문 템플릿, 메타 주석 포맷
- references/module-inference.md — 모듈 추론 규칙
- references/severity-rules.md — 심각도 매핑 알고리즘
- references/note-schema.md — 트래킹 메모 파싱 + auto-close 메모 포맷
- references/filter-rules.md — 메인이 사용할 분류 로직(특히 max_app_version 필요성 이해)

수행 순서:
1. mcp__firebase__crashlytics_list_events (또는 list_events가 상태 필터를
   지원하지 않으면 crashlytics_get_report(report=TOP_ISSUES) 폴백)로
   최근 lookback_days 범위의 state=OPEN 이슈 목록 수집.
2. 각 이슈에 대해 crashlytics_get_issue와 crashlytics_list_notes를
   한 턴에 병렬 tool_use로 조회.
3. 각 이슈마다:
   a. notes에서 latest tracking note 파싱 → tracking_note_number (없으면 null).
      (`auto-closed:` prefix 메모는 tracking note가 아니므로 무시.)
   b. stack_trace + display_name + error_type을 읽고 module 추론
      (language는 config.module.language 고정. 기본 "ko").
   c. severity_thresholds로 severity 결정 (first matching wins, AND 매칭).
   d. issue-template.md의 Body Template을 렌더해 rendered_body 생성.
      - <!-- crashlytics_issue_id: <issue_id> --> 메타 주석 포함 필수.
      - stack_trace는 <details> 블록 안에 full 버전 그대로 삽입.
   e. rendered_title = "[Firebase Crashlytics] <module> - <summary>"
      (summary는 display_name 첫 줄에서 80자 truncate).
   f. crashlytics_get_issue 응답의 app_versions[] 또는 동등 필드에서
      min·max를 추출해 min_app_version·max_app_version으로 반환.
      - 표준 semver 포맷이 아니어도 raw 문자열 그대로. 메인의 semver_compare
        가 fallback 처리(filter-rules.md 참조).
      - 응답에 버전 정보 자체가 없거나 빈 배열이면 둘 다 null.
4. 자유 형식 설명 없이 아래 JSON만 반환. raw stack_trace나 raw notes[]는
   절대 반환 JSON에 넣지 않는다(메인 context 토큰 절약).
```

## 반환 JSON 스키마

```json
{
  "app_id": "...",
  "platform": "ios",
  "display_name": "...",
  "issues": [
    {
      "issue_id": "...",
      "display_name": "...",
      "event_count": 0,
      "impacted_users_count": 0,
      "last_seen_at": "2026-04-24T00:00:00+09:00",
      "error_type": "FATAL",
      "module": "출금",
      "severity": "blocker",
      "tracking_note_number": 105,
      "min_app_version": "1.0.0",
      "max_app_version": "1.0.3",
      "rendered_title": "[Firebase Crashlytics] 출금 - NSRangeException in transaction list",
      "rendered_body": "## Crashlytics Report\n\n| Field | Value |\n...\n<!-- crashlytics_issue_id: abc123 -->\n..."
    }
  ]
}
```

### 필드 설명

| Field                                 | 역할                                            | 메인 세션에서의 쓰임                                                                    |
| ------------------------------------- | ----------------------------------------------- | --------------------------------------------------------------------------------------- |
| `issue_id`                            | Crashlytics 이슈 ID                             | 멱등 검색 키                                                                            |
| `display_name`                        | 원본 요약                                       | 앱 간 통합 판정 (동일 display_name = 통합)                                              |
| `event_count`, `impacted_users_count` | 통합 이슈 집계용                                | 집계 후 최종 body에 재주입 (필요 시)                                                    |
| `last_seen_at`                        | 참고용                                          | 결과 표·디버깅에만 사용. 회귀 판정에는 더 이상 쓰지 않음                                |
| `error_type`                          | `FATAL` / `NON_FATAL` / `ANR`                   | 라벨링에는 간접 영향, body 재렌더에 사용                                                |
| `module`                              | 추론된 모듈명                                   | 제목 재생성이 필요한 경우(통합 이슈)                                                    |
| `severity`                            | 계산된 심각도 레벨                              | `severity:<level>` 라벨                                                                 |
| `tracking_note_number`                | 메모에서 추출한 GitHub 이슈 번호(없으면 `null`) | filter-rules.md 분류 입력                                                               |
| `min_app_version`, `max_app_version`  | Crashlytics 측 영향 앱 버전 범위                | filter-rules.md의 `semver_compare`에 직접 전달. `null`이면 보수적 SKIP                  |
| `rendered_title`, `rendered_body`     | 완성된 제목·본문                                | 통합·회귀가 아니면 **그대로** 메인 세션의 `gh api -X POST repos/.../issues` 발행에 전달 |

## 반환 금지 목록

서브에이전트 컨텍스트에만 남기고 메인으로 되돌리지 않는다:

- `stack_trace` 전문 (rendered_body 안에만 존재)
- `notes[]` 전체 배열 (tracking_note_number만 전달)
- `top_devices`, `top_regions`의 raw 배열 (rendered_body 안에만)
- `os_versions` 범위 (rendered_body 안에만 — 메인은 회귀 판정에 OS 버전 사용 안 함)
- `app_versions[]` 전체 배열 — min/max 두 문자열만 추출해 노출

`min_app_version`·`max_app_version`은 **예외**: 메인이 `filter-rules.md`의 `semver_compare`에 직접 전달해야 하므로 반드시 반환한다.

이로써 이슈당 메인 payload는 ~1KB 수준으로 수렴한다(두 짧은 버전 문자열 추가는 무시 가능한 오버헤드).

## 통합·회귀 시 rendered_body 재가공

메인 세션은 아래 두 경우에만 서브에이전트가 렌더한 body를 수정한다:

- **통합 이슈(iOS + Android)**: 앱별 서브에이전트 각각의 `rendered_body`를 받은 뒤, Crashlytics Report 테이블의 app/platform/event_count/impacted_users를 합산·유니온(issue-template.md#Unified-Issues 규칙). 메타 주석 블록은 앱별로 **append** — 한 body에 `<!-- crashlytics_issue_id: ... -->` 라인이 여러 줄 생긴다.
- **회귀(`REGISTER(regression)`)**: body 상단에 회귀 경고 블록(issue-template.md#Regression-Rendering) prepend. `{previous_issue_number}` / `{previous_issue_url}` / `{closed_issue_max_version}` / `{crashlytics_max_version}`은 filter-rules.md의 분류 결과 context에서 주입.

통합·회귀가 아닌 일반 신규 등록은 `rendered_body`를 **그대로** 사용.
