# Issue Template

## Title Format

**Fixed format** — 하드코딩이며 `config.json`으로 변경할 수 없다:

```
[Firebase Crashlytics] {module} - {summary}
```

### Tokens

| Token                    | Value                                                                                                                                         |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `[Firebase Crashlytics]` | 리터럴 프리픽스. GitHub 필터(`gh issue list --search "[Firebase Crashlytics] in:title"`)에 대한 강력한 스코핑 키.                             |
| `{module}`               | LLM이 스택 트레이스·`display_name`·`error_type`에서 추론한 **짧은 현장 언어 단어**. 예: `광고`, `출금`, `홈`, `Ads`, `Home`. 상세: `module-inference.md`. |
| `{summary}`              | Crashlytics `display_name`에서 추출한 1줄 오류 요약. 80자 초과 시 truncate.                                                                   |

### Examples

```
[Firebase Crashlytics] 출금 - NSRangeException in transaction list
[Firebase Crashlytics] 홈 - NullPointerException in ViewModel.fetchBalance
[Firebase Crashlytics] 광고 - AdMob SDK initialization failed
```

### Why Hardcode the Prefix?

- `[Firebase Crashlytics]`는 GitHub 이슈 검색 UI에서 **라벨 필터 없이도** 크래시 자동 등록분만 바로 좁힐 수 있는 단일 키워드가 된다.
- `source:crashlytics` 라벨과 함께 쓰이면 **제목·라벨 이중 신호**가 되어 필터·자동화에 견고하다.
- 서비스명·플랫폼 토큰은 제목에 포함하지 않는다. 서비스명은 제목 공간을 차지할 가치가 적고, 플랫폼 정보는 라벨(`os:ios` / `os:android`)과 본문의 `Platform` 행에 이미 담긴다.

## Body Template

이 템플릿을 그대로 사용한다. 필드는 영문 키로 고정되어 언어 중립이고, HTML 주석 블록은 머신 파싱용 fallback을 제공한다.

````markdown
## Crashlytics Report

| Field                          | Value                                 |
| ------------------------------ | ------------------------------------- |
| Crashlytics Issue ID           | `{issue_id}`                          |
| App                            | {app_display_name}                    |
| Platform                       | {platform}                            |
| Module                         | {module}                              |
| Error Type                     | {error_type}                          |
| Severity                       | {severity}                            |
| First Seen                     | {first_seen_at}                       |
| Last Seen                      | {last_seen_at}                        |
| Events (last {lookback_days}d) | {event_count}                         |
| Impacted Users                 | {impacted_users_count}                |
| App Versions                   | {min_app_version} ~ {max_app_version} |
| OS Versions                    | {min_os_version} ~ {max_os_version}   |

### Summary

{summary}

### Stack Trace

<details><summary>Expand</summary>

```
{full_stack_trace}
```

</details>

### Top Devices

| Device     | Events    |
| ---------- | --------- |
| {device_1} | {count_1} |
| {device_2} | {count_2} |

### Top Regions

| Region     | Events    |
| ---------- | --------- |
| {region_1} | {count_1} |
| {region_2} | {count_2} |

### Links

- [Crashlytics Console]({console_url})

<!-- crashlytics-to-issue meta -->
<!-- schema_version: 2 -->
<!-- crashlytics_issue_id: {issue_id} -->
<!-- app_id: {app_id} -->
<!-- platform: {platform} -->
````

## Unified Issues (iOS + Android)

When the same `display_name` appears in multiple apps/platforms, a single GitHub issue represents all of them.

- The **Crashlytics Issue ID** row is repeated, one per app.
- The **App** row is rendered as a multi-line list (one app per line) or comma-separated.
- **Platform** becomes `iOS+Android` (order: alphabetical).
- Event counts and impacted users are **summed** across apps.
- Version ranges are unioned (`min = min of mins`, `max = max of maxes`).
- Each app's `app_id` **and** `crashlytics_issue_id`가 각각 한 줄의 HTML comment로 per-app 블록을 이룬다. 한 이슈 본문에 여러 `<!-- crashlytics_issue_id: ... -->` 라인이 존재할 수 있다.

## Regression Rendering

When the classification is `REGISTER(regression)`, prepend this block at the very top of the body (before `## Crashlytics Report`):

```markdown
> **⚠️ Regression detected**
>
> 이 크래시는 이전에 [#{previous_issue_number}]({previous_issue_url})로 등록·처리됐지만, close 이후 새 이벤트가 관측되어 회귀로 재등록됐다.
>
> - Previous issue: [#{previous_issue_number}]({previous_issue_url})
> - Previous issue closed at: `{closed_at}`
> - Latest observed event at: `{last_seen_at}`
```

The `regression` label on the issue makes it trivially filterable in GitHub.

## Labels

모든 라벨은 `key:value` 네임스페이스 규약을 따른다. 이슈 1건에 대해 아래 순서로 조합된다.

1. **`config.github.default_labels`** — 기본 `["source:crashlytics"]`. 항상 부여.
2. **Platform** — `os:ios` 또는 `os:android`. 통합 이슈(iOS+Android)는 두 값 모두 부여.
3. **Severity** — `severity:blocker`, `severity:critical`, `severity:major` 중 자동 선택 (상세: `severity-rules.md`).
4. **Regression** — 회귀로 분류된 경우에만 `state:regression` 추가.

**사전 조건**: 위 라벨이 모두 대상 레포에 미리 등록되어 있어야 `gh issue create --label`이 422 없이 통과한다. 셋업 방법은 `installation.md`의 "Label Setup" 섹션 참고.

## Issue Type

`config.github.issue_type`이 지정되면(기본: `"Bug"`) `gh issue create --type "<value>"`로 전달되어 GitHub Issue Type 필드가 설정된다.

- `gh` **v2.63+** 필요.
- `issue_type: null`이면 `--type` 플래그를 조립 단계에서 제외해 낮은 `gh` 버전이나 Issue Types 미활성화 조직에도 대응.
- 조직에 Issue Types가 켜져 있고 타입명이 존재해야 한다. `gh issue create`가 422를 반환하면 조용한 fallback 없이 **즉시 실패**(데이터 일관성 유지).

## Rationale

- **Why English field keys**: language-neutral for distribution across teams with different working languages.
- **Why a collapsed stack trace**: long stacks pollute the issue list preview; one click to expand keeps details one gesture away.
- **Why HTML comment meta**: downstream parsers (CI scripts, dashboards) can read `app_id`, `platform`, `crashlytics_issue_id`를 마크다운 표 파싱 없이 얻을 수 있다. 특히 `crashlytics_issue_id`는 이 스킬의 **멱등 키**로 쓰인다 — `gh issue list --search '"crashlytics_issue_id: <id>" in:body' --state all`로 왕복 조회가 가능해, 제목 문자열(모듈명 비결정성)에 의존하지 않는 결정적 중복 탐지가 된다.
- **Why `schema_version` in a comment**: future-proofing. If the template changes, consumers can detect the version and adapt.
