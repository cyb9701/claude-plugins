# Subagent Contract — 조회 + 후처리 + 본문 렌더

Step 3의 앱별 서브에이전트는 단순 fetcher가 아니다. Crashlytics 조회·모듈 추론·심각도 계산·GitHub 본문 렌더링까지 서브에이전트 컨텍스트에서 끝낸다. 메인 세션은 **이미 렌더된 결과**만 받아 분류·발행한다.

이 설계의 효과:

- **메인 context 절약**: full stack trace(이슈당 2~5KB)·raw notes[]가 메인에 흡수되지 않는다.
- **모듈 추론 품질**: 스택을 서브에이전트가 직접 읽는 동안 추론하므로 메인이 요약본에서 재추론하는 구조보다 정확하다.

## 서브에이전트 프롬프트 템플릿

메인 세션은 각 앱마다 아래 프롬프트로 `Agent({ subagent_type: "general-purpose" })`를 디스패치한다. `<...>` 자리는 메인이 채워 넣는다.

```
너는 Crashlytics → GitHub Issue 자동화 스킬의 앱별 조회 서브에이전트다.
대상 앱: app_id=<app_id>, platform=<platform>, display_name=<display_name>,
        bundle_id_or_package=<bundle_id_or_package>

다음 설정을 참고하라(메인이 이미 계산해서 전달):
- project_id: <config.firebase.project_id>          # 본문 링크 조립용
- repo: <config.github.repo>
- lookback_days: <config.query.lookback_days>
- module.language: <config.module.language>         # 예: "ko"
- severity_thresholds: <config.severity_thresholds JSON>
- issue_body: <config.issue_body JSON>              # include_* 토글, max_* 상한

(서브에이전트는 회귀 판정·제목 조립에 관여하지 않는다.
 회귀: 메인이 max_app_version을 받아서 처리.
 제목: 메인이 module과 title_summary로 직접 조립.)

반드시 읽을 reference:
- references/issue-template.md — 본문 템플릿, 메타 주석 포맷, 단일 링크 정책
- references/module-inference.md — 모듈 추론 규칙
- references/severity-rules.md — 심각도 매핑 알고리즘
- references/note-schema.md — 트래킹 메모 파싱

수행 순서:
1. mcp__firebase__crashlytics_list_events (또는 list_events가 상태 필터를
   지원하지 않으면 crashlytics_get_report(report=TOP_ISSUES) 폴백)로
   최근 lookback_days 범위의 state=OPEN 이슈 목록 수집.
2. 각 이슈에 대해 다음을 한 턴에 병렬 tool_use로 조회:
   - crashlytics_get_issue          (메타·variants·app_versions·os_versions)
   - crashlytics_list_notes         (트래킹 메모)
   - crashlytics_get_report(TOP_ISSUES) (top_devices·top_os_versions·top_app_versions·top_regions 분포)
   - crashlytics_list_events (sample size N) (custom_keys·breadcrumbs·logs 추출용)
3. 각 이슈마다:
   a. notes에서 latest tracking note 파싱 → tracking_note_number (없으면 null).
   b. stack_trace + display_name + error_type을 읽고 module 추론.
   c. severity_thresholds로 severity 결정 (first matching wins).
   d. 추가 메트릭 계산:
      - title_summary = display_name 첫 줄을 80자 truncate.
      - first_frame   = stack_trace[0]을 한 줄로 요약 (function/method + offset).
      - days_since_first_seen = (now - first_seen_at).days.
      - crashes_per_day_avg   = event_count / max(days_since_first_seen, 1)
                                (소수점 1자리).
      - has_variants     = len(variants[])      > 1
      - has_custom_keys  = sample 이벤트 중 custom_keys가 있는지
      - has_breadcrumbs  = sample 이벤트 중 breadcrumbs가 있는지
      - has_logs         = sample 이벤트 중 logs가 있는지
      - issue_link = "https://console.firebase.google.com/project/<project_id>"
                     "/crashlytics/app/<platform>:<bundle_id_or_package>"
                     "/issues/<issue_id>"
   e. issue-template.md의 Body Template을 렌더해 rendered_body 생성:
      - <!-- crashlytics_issue_id: <issue_id> --> 메타 주석 포함 필수.
      - 분포 섹션 행 수는 issue_body.max_top_* 상한에 따라 잘라낸다.
      - has_* 플래그가 false인 섹션은 렌더하지 않는다(빈 표 금지).
      - issue_body.include_breadcrumbs / include_custom_keys / include_logs /
        include_variants가 false면 해당 섹션 스킵.
      - Links는 위에서 만든 issue_link 한 줄만.
   f. crashlytics_get_issue 응답의 app_versions[]에서 min·max 추출 →
      min_app_version·max_app_version. 없거나 빈 배열이면 둘 다 null.
      os_versions[]도 동일하게 min·max 추출.
4. rendered_title은 만들지 않는다. 메인이 module + title_summary로 직접 조립한다.
5. 자유 형식 설명 없이 아래 JSON만 반환.
```

## 반환 JSON 스키마

```json
{
  "app_id": "...",
  "platform": "ios",
  "display_name": "...",
  "bundle_id_or_package": "com.example.app",
  "issues": [
    {
      "issue_id": "...",
      "display_name": "...",
      "module": "출금",
      "title_summary": "NSRangeException in transaction list",
      "error_type": "FATAL",
      "severity": "blocker",
      "tracking_note_number": 105,

      "event_count": 1234,
      "impacted_users_count": 567,
      "first_seen_at": "2026-04-12T00:00:00+09:00",
      "last_seen_at": "2026-04-24T00:00:00+09:00",
      "days_since_first_seen": 12,
      "crashes_per_day_avg": 102.8,

      "min_app_version": "1.0.0",
      "max_app_version": "1.0.3",
      "min_os_version": "iOS 16.0",
      "max_os_version": "iOS 17.4.1",

      "first_frame": "TransactionListVC.didSelectRow + 124",
      "has_variants": true,
      "has_custom_keys": false,
      "has_breadcrumbs": true,
      "has_logs": false,

      "rendered_body": "## Crashlytics Report\n..."
    }
  ]
}
```

`rendered_title`은 의도적으로 제거되었다. 메인 세션이 `module` + `title_summary`로 직접 조립한다(상세: `issue-template.md#Ownership`).

### 필드 역할

| Field                                                               | 메인 세션에서의 쓰임                                                   |
| ------------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `issue_id`                                                          | 멱등 검색 키                                                           |
| `display_name`                                                      | 앱 간 통합 판정 (동일 display_name = 통합)                             |
| `module`, `title_summary`                                           | **메인이 제목 조립** (`[Firebase Crashlytics] {module} - {summary}`)   |
| `error_type`                                                        | 제목 fallback (`module`이 비면 사용), 라벨링                           |
| `severity`                                                          | 라벨링                                                                 |
| `tracking_note_number`                                              | 분류 입력 (filter-rules.md)                                            |
| `event_count`, `impacted_users_count`                               | 통합 이슈 집계용                                                       |
| `first_seen_at`, `last_seen_at`                                     | 통합 이슈 시 min/max 재집계                                            |
| `days_since_first_seen`, `crashes_per_day_avg`                      | 통합 이슈 재계산용                                                     |
| `min/max_app_version`                                               | `semver_compare`에 직접 전달 (회귀 판정). `null`이면 보수적 SKIP       |
| `min/max_os_version`                                                | 통합 이슈 union 행 재집계                                              |
| `first_frame`                                                       | 통합 이슈 시 plat별 분기 표기                                          |
| `bundle_id_or_package`                                              | 통합 이슈 시 콤마/멀티라인 합성, 통합 링크 조립                        |
| `has_variants` / `has_custom_keys` / `has_breadcrumbs` / `has_logs` | 통합 이슈 본문 재가공 시 plat별 섹션 등장 여부 판단                    |
| `rendered_body`                                                     | 통합·회귀가 아니면 **그대로** `gh api -X POST repos/.../issues`에 전달 |

## 반환 금지 (메인으로 되돌리지 않음)

다음 raw 데이터는 모두 `rendered_body` 안에만 존재하고 메인 세션으로 절대 되돌리지 않는다. 이슈당 메인 payload를 ~1KB 수준으로 유지하기 위함이다(이슈 수가 100건을 넘어도 컨텍스트가 폭증하지 않음).

- `stack_trace` 전문
- `notes[]` 전체 배열 (`tracking_note_number`만 추출)
- `app_versions[]` / `os_versions[]` 전체 배열 (min/max 두 문자열만)
- `top_devices` / `top_os_versions` / `top_app_versions` / `top_regions` 분포 데이터
- `variants[]` raw 데이터 (개수 추론용 `has_variants` boolean만)
- `custom_keys` / `breadcrumbs` / `logs` 샘플 (`has_*` boolean만)

메인이 이 데이터에 접근해야 할 유일한 시나리오는 **통합 이슈 본문 재가공**인데, 그조차도 새로운 데이터를 합치는 게 아니라 **앱별 `rendered_body` 두 개를 텍스트 수준에서 합치는 작업**이다. 따라서 raw 데이터는 메인에 필요 없다.

## 통합·회귀 시 rendered_body 재가공

메인 세션이 body를 수정하는 경우는 두 가지뿐:

- **통합 이슈(iOS + Android)**: 앱별 `rendered_body`를 받아 Crashlytics Report 표의 app/platform/event_count/impacted_users를 합산·유니온(`issue-template.md#Unified-Issues`). 메타 주석은 앱별로 append.
- **회귀(`REGISTER(regression)`)**: body 상단에 회귀 경고 블록 prepend(`issue-template.md#Regression-Rendering`). 컨텍스트 필드는 `filter-rules.md` 분류 결과에서 주입.

그 외는 `rendered_body`를 **그대로** 사용.
