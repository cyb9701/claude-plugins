# Subagent Contract — 조회 + 후처리 + 본문 렌더

Step 3의 앱별 서브에이전트는 단순 fetcher가 아니다. Crashlytics 조회·모듈 추론·심각도 계산·GitHub 본문 렌더링까지 서브에이전트 컨텍스트에서 끝낸다. 메인 세션은 **이미 렌더된 결과**만 받아 분류·발행한다.

이 설계의 효과:

- **메인 context 절약**: full stack trace(이슈당 2~5KB)·raw notes[]가 메인에 흡수되지 않는다.
- **모듈 추론 품질**: 스택을 서브에이전트가 직접 읽는 동안 추론하므로 메인이 요약본에서 재추론하는 구조보다 정확하다.

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

(서브에이전트는 회귀 판정에 관여하지 않는다 — 메인이 max_app_version을 받아서 처리.)

반드시 읽을 reference:
- references/issue-template.md — 제목·본문 템플릿, 메타 주석 포맷
- references/module-inference.md — 모듈 추론 규칙
- references/severity-rules.md — 심각도 매핑 알고리즘
- references/note-schema.md — 트래킹 메모 파싱

수행 순서:
1. mcp__firebase__crashlytics_list_events (또는 list_events가 상태 필터를
   지원하지 않으면 crashlytics_get_report(report=TOP_ISSUES) 폴백)로
   최근 lookback_days 범위의 state=OPEN 이슈 목록 수집.
2. 각 이슈에 대해 crashlytics_get_issue와 crashlytics_list_notes를
   한 턴에 병렬 tool_use로 조회.
3. 각 이슈마다:
   a. notes에서 latest tracking note 파싱 → tracking_note_number (없으면 null).
   b. stack_trace + display_name + error_type을 읽고 module 추론.
   c. severity_thresholds로 severity 결정 (first matching wins).
   d. issue-template.md의 Body Template을 렌더해 rendered_body 생성.
      (<!-- crashlytics_issue_id: <issue_id> --> 메타 주석 포함 필수.)
   e. rendered_title = "[Firebase Crashlytics] <module> - <summary>"
      (summary는 display_name 첫 줄 80자 truncate).
   f. crashlytics_get_issue 응답의 app_versions[]에서 min·max 추출 →
      min_app_version·max_app_version. 없거나 빈 배열이면 둘 다 null.
4. 자유 형식 설명 없이 아래 JSON만 반환.
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
      "rendered_body": "## Crashlytics Report\n..."
    }
  ]
}
```

### 필드 역할

| Field                                 | 메인 세션에서의 쓰임                                                        |
| ------------------------------------- | --------------------------------------------------------------------------- |
| `issue_id`                            | 멱등 검색 키                                                                |
| `display_name`                        | 앱 간 통합 판정 (동일 display_name = 통합)                                  |
| `event_count`, `impacted_users_count` | 통합 이슈 집계용                                                            |
| `error_type`, `module`, `severity`    | 라벨링·body 재렌더에 사용                                                   |
| `tracking_note_number`                | 분류 입력 (filter-rules.md)                                                 |
| `min/max_app_version`                 | `semver_compare`에 직접 전달. `null`이면 보수적 SKIP                        |
| `rendered_title`, `rendered_body`     | 통합·회귀가 아니면 **그대로** `gh api -X POST repos/.../issues` 발행에 전달 |

## 반환 금지 (메인으로 되돌리지 않음)

- `stack_trace` 전문 (rendered_body 안에만)
- `notes[]` 전체 배열 (tracking_note_number만)
- `top_devices`, `top_regions`, `os_versions` 범위 (rendered_body 안에만)
- `app_versions[]` 전체 배열 — **min/max 두 문자열만** 추출해 노출

이로써 이슈당 메인 payload는 ~1KB 수준으로 수렴한다.

## 통합·회귀 시 rendered_body 재가공

메인 세션이 body를 수정하는 경우는 두 가지뿐:

- **통합 이슈(iOS + Android)**: 앱별 `rendered_body`를 받아 Crashlytics Report 표의 app/platform/event_count/impacted_users를 합산·유니온(`issue-template.md#Unified-Issues`). 메타 주석은 앱별로 append.
- **회귀(`REGISTER(regression)`)**: body 상단에 회귀 경고 블록 prepend(`issue-template.md#Regression-Rendering`). 컨텍스트 필드는 `filter-rules.md` 분류 결과에서 주입.

그 외는 `rendered_body`를 **그대로** 사용.
