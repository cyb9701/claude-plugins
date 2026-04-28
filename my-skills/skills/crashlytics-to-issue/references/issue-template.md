# Issue Template

## Title Format

**Fixed format** — 하드코딩이며 `config.json`으로 변경할 수 없다:

```
[Firebase Crashlytics] {module} - {summary}
```

### Ownership

**제목 조립은 메인 세션의 책임이다.** 서브에이전트는 `module`과 `title_summary` raw 필드만 반환하고, 메인 세션이 `SKILL.md` Step 4 시작점에서 다음 한 줄로 직접 조립한다:

```bash
MODULE="${module:-${error_type}}"
TSUMMARY="${title_summary:-${display_name:0:80}}"
RENDERED_TITLE="[Firebase Crashlytics] ${MODULE} - ${TSUMMARY}"
```

서브에이전트(LLM)가 `rendered_title`을 만들면 prefix 누락·변형 가능성이 있으나, 메인이 Bash 변수로 강제 prepend하면 어떤 경우에도 `[Firebase Crashlytics] ` prefix가 보장된다. fallback(`module → error_type`, `title_summary → display_name 80자`)으로 raw 필드가 비어도 깨지지 않는다.

### Tokens

| Token                    | Value                                                                                                                                     |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `[Firebase Crashlytics]` | 리터럴 프리픽스. `gh issue list --search "[Firebase Crashlytics] in:title"`처럼 라벨 필터 없이도 자동 등록분만 좁힐 수 있는 키.           |
| `{module}`               | LLM이 스택 트레이스·`display_name`·`error_type`에서 추론한 짧은 현장 언어 단어 (예: `광고`, `출금`, `Home`). 상세: `module-inference.md`. |
| `{summary}`              | Crashlytics `display_name`에서 추출한 1줄 오류 요약. 80자 초과 시 truncate. 서브에이전트가 `title_summary` 필드로 반환.                   |

### Examples

```
[Firebase Crashlytics] 출금 - NSRangeException in transaction list
[Firebase Crashlytics] 홈 - NullPointerException in ViewModel.fetchBalance
[Firebase Crashlytics] 광고 - AdMob SDK initialization failed
```

서비스명·플랫폼은 제목에 넣지 않는다 — 플랫폼은 `os:ios`/`os:android` 라벨과 본문 `Platform` 행에 이미 있다.

## Body Template

이 템플릿을 그대로 사용한다. 필드는 영문 키로 고정(언어 중립), HTML 주석 블록은 머신 파싱용 fallback이다.

본문은 **Firebase Crashlytics에서 조회 가능한 모든 정보를 한 페이지에 압축**해 디버거가 콘솔로 이동하지 않고도 1차 트리아지를 끝낼 수 있게 한다. 데이터가 비어 있는 섹션(Variants / Custom Keys / Breadcrumbs / Logs)은 **렌더하지 않는다** — 빈 표가 본문에 등장해 노이즈가 되는 것을 방지한다.

````markdown
## Crashlytics Report

| Field                          | Value                                 |
| ------------------------------ | ------------------------------------- |
| Crashlytics Issue ID           | `{issue_id}`                          |
| App                            | {app_display_name}                    |
| Platform                       | {platform}                            |
| Bundle ID / Package            | `{bundle_id_or_package}`              |
| Module                         | {module}                              |
| Error Type                     | {error_type}                          |
| Severity                       | {severity}                            |
| First Seen                     | {first_seen_at}                       |
| Last Seen                      | {last_seen_at}                        |
| Days Since First Seen          | {days_since_first_seen}               |
| Events (last {lookback_days}d) | {event_count}                         |
| Impacted Users                 | {impacted_users_count}                |
| Crashes per Day (avg)          | {crashes_per_day_avg}                 |
| App Versions                   | {min_app_version} ~ {max_app_version} |
| OS Versions                    | {min_os_version} ~ {max_os_version}   |
| First Frame                    | `{first_frame}`                       |

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

### Top OS Versions

| OS Version     | Events    |
| -------------- | --------- |
| {os_version_1} | {count_1} |
| {os_version_2} | {count_2} |

### Top App Versions

| App Version     | Events    |
| --------------- | --------- |
| {app_version_1} | {count_1} |
| {app_version_2} | {count_2} |

### Top Regions

| Region     | Events    |
| ---------- | --------- |
| {region_1} | {count_1} |
| {region_2} | {count_2} |

### Variants

<!-- 여러 스택 변형이 있을 때만 등장. has_variants == false면 섹션 자체 생략. -->

| Variant ID    | Events    | First Frame |
| ------------- | --------- | ----------- |
| {variant_id1} | {count_1} | `{frame_1}` |
| {variant_id2} | {count_2} | `{frame_2}` |

### Custom Keys

<!-- Crashlytics SDK가 기록한 key/value. has_custom_keys == false면 섹션 생략. -->

| Key     | Value     |
| ------- | --------- |
| {key_1} | {value_1} |
| {key_2} | {value_2} |

### Breadcrumbs

<!-- has_breadcrumbs == false면 섹션 생략. collapsed로 처리해 이슈 리스트 프리뷰 오염 방지. -->

<details><summary>Expand</summary>

```
[2026-04-28 09:12:01] INFO  - tapped withdraw button
[2026-04-28 09:12:03] DEBUG - fetched balance=12345
...
```

</details>

### Logs

<!-- Crashlytics SDK 로그. has_logs == false면 섹션 생략. collapsed. -->

<details><summary>Expand</summary>

```
{logs_sample}
```

</details>

### Links

- [Firebase Crashlytics Issue](https://console.firebase.google.com/project/{project_id}/crashlytics/app/{platform}:{bundle_id_or_package}/issues/{issue_id})

<!-- crashlytics-to-issue meta -->
<!-- crashlytics_issue_id: {issue_id} -->
<!-- app_id: {app_id} -->
<!-- platform: {platform} -->
````

### 필드 출처와 계산식

| Field                   | 출처 / 계산                                                                          |
| ----------------------- | ------------------------------------------------------------------------------------ |
| `bundle_id_or_package`  | iOS는 `crashlytics_get_issue` 응답의 `bundle_id`, Android는 `package_name`           |
| `first_frame`           | `stack_trace[0]`의 한 줄 요약 (function/method + offset)                             |
| `days_since_first_seen` | `(now - first_seen_at).days` (서브에이전트 계산)                                     |
| `crashes_per_day_avg`   | `event_count / max(days_since_first_seen, 1)` 소수점 1자리. lookback 범위 평균.      |
| Top OS / App Versions   | `crashlytics_get_report(report=TOP_ISSUES)` 응답의 분포 데이터에서 events 기준 상위. |
| Variants                | `crashlytics_get_issue` 응답의 `variants[]`. 비어 있으면 섹션 생략.                  |
| Custom Keys             | `crashlytics_list_events` 샘플 이벤트의 `custom_keys`. 비어 있으면 섹션 생략.        |
| Breadcrumbs / Logs      | 동일 샘플 이벤트의 `breadcrumbs[]`/`logs[]`. 비어 있으면 섹션 생략.                  |

각 분포 표·breadcrumbs·logs의 행 수는 `config.json`의 `issue_body.max_*` 상한에 따라 잘라낸다.

### 단일 링크 정책

본문 링크는 **Firebase Crashlytics Issue 직접 링크 하나만** 둔다. 콘솔의 이슈 페이지 한 곳에서 Events / Breadcrumbs / Signals / Stack / Logs를 모두 볼 수 있으므로 다중 링크는 노이즈가 된다. 링크 URL 패턴:

```
https://console.firebase.google.com/project/{project_id}/crashlytics/app/{platform}:{bundle_id_or_package}/issues/{issue_id}
```

서브에이전트가 본문 렌더 시 직접 조립한다. 메인 세션은 가공하지 않는다.

## Unified Issues (iOS + Android)

같은 `display_name`이 여러 앱/플랫폼에 나오면 단일 GitHub 이슈로 통합.

### 메타 표 처리

- **Crashlytics Issue ID** 행은 앱마다 한 줄씩 반복.
- **App** 행은 멀티라인 또는 콤마 구분.
- **Platform**은 `iOS+Android` (알파벳 순).
- **Bundle ID / Package**: 앱별 콤마 구분 또는 멀티라인 (`com.example.ios, com.example.android`).
- **Module**: 모듈명이 동일하므로 첫 번째 앱 기준 그대로.
- **Error Type**: 동일하므로 그대로. 다르면 `iOS:FATAL / Android:ANR` 형태.
- **Severity**: 앱별 severity 중 가장 높은 등급(blocker > critical > major).
- **First Seen**: `min(앱별 first_seen_at)`.
- **Last Seen**: `max(앱별 last_seen_at)`.
- **Days Since First Seen**: `min(앱별 first_seen_at)` 기준 재계산.
- **Events / Impacted Users**: **합산**.
- **Crashes per Day (avg)**: `total_event_count / max(days_since_first_seen, 1)`로 재계산.
- **`App Versions` 행은 반드시 한 줄로 union된 `{global_min} ~ {global_max}`**. `global_min = min(앱별 min)`, `global_max = max(앱별 max)`. 멀티라인으로 분기하면 회귀 정규식(`^\|\s*App Versions\s*\|\s*(\S+)\s*~\s*(\S+)\s*\|`)이 매칭 실패해 회귀 감지가 깨진다.
- **`OS Versions` 행도 동일** — union된 `min ~ max`. 회귀 판정엔 영향 없지만 일관성 유지.
- **First Frame**: 동일 stack 시 그대로, 다르면 `iOS: ..., Android: ...` 형태.

### 분포 섹션 처리

`Top Devices` / `Top OS Versions` / `Top App Versions` / `Top Regions` / `Variants` 섹션은 앱별로 데이터 분리:

```markdown
### Top Devices (iOS)

| Device | Events |
...

### Top Devices (Android)

| Device | Events |
...
```

Custom Keys / Breadcrumbs / Logs 도 동일 — `### Custom Keys (iOS)` / `### Custom Keys (Android)`로 분기. 데이터가 한쪽 앱에만 있으면 해당 앱 섹션만 등장.

이 분기 표시는 회귀 판정 정규식과 무관하므로 자유롭게 분기해도 안전하다. 회귀 판정의 단일 진실 원천은 한 줄 union된 `App Versions` 행 하나뿐.

### 메타 주석 처리

앱별 `<!-- crashlytics_issue_id: ... -->`, `<!-- app_id: ... -->`, `<!-- platform: ... -->` 라인이 한 본문에 **여러 줄** 존재 가능. 예:

```
<!-- crashlytics-to-issue meta -->
<!-- crashlytics_issue_id: ios_issue_abc -->
<!-- app_id: 1:1234:ios:abc -->
<!-- platform: ios -->
<!-- crashlytics_issue_id: android_issue_xyz -->
<!-- app_id: 1:1234:android:xyz -->
<!-- platform: android -->
```

멱등 검색은 `gh issue list --search "crashlytics_issue_id: <id> in:body"`로 어느 한 줄만 매칭되어도 동일 이슈로 인식되므로, 통합 이슈도 안전하게 멱등 처리된다.

### 링크 처리

각 앱별 Crashlytics 이슈 직접 링크를 **모두 나열**:

```markdown
### Links

- [Firebase Crashlytics Issue (iOS)](https://console.firebase.google.com/project/{project_id}/crashlytics/app/ios:{ios_bundle_id}/issues/{ios_issue_id})
- [Firebase Crashlytics Issue (Android)](https://console.firebase.google.com/project/{project_id}/crashlytics/app/android:{android_package}/issues/{android_issue_id})
```

## Regression Rendering

`REGISTER(regression)`일 때 본문 최상단(`## Crashlytics Report` 앞)에 prepend:

```markdown
> **⚠️ Regression detected**
>
> 이 크래시는 이전에 [#{previous_issue_number}]({previous_issue_url})로 등록·처리됐지만, 닫힌 이슈의 max_app_version `{closed_issue_max_version}` 이후 버전인 `{crashlytics_max_version}`에서 다시 관측되어 회귀로 재등록됐다.
>
> - Previous issue: [#{previous_issue_number}]({previous_issue_url})
> - Previous issue max app version: `{closed_issue_max_version}`
> - Crashlytics current max app version: `{crashlytics_max_version}`
```

`regression` 라벨로 GitHub에서 필터 가능. 본문은 회귀 판정 근거(버전)만 노출 — 시각·콘솔 링크는 GitHub timeline / Crashlytics 콘솔에서 한 클릭으로 확인 가능하므로 중복 표시하지 않는다.

## Labels

이슈 1건에 대해 아래 순서로 조합. 모든 라벨은 `key:value` 네임스페이스 규약을 따른다.

1. **`config.github.default_labels`** — 기본 `["source:crashlytics"]`. 항상 부여.
2. **Platform** — `os:ios` 또는 `os:android`. 통합 이슈는 두 값 모두 부여.
3. **Severity** — `severity:blocker` / `severity:critical` / `severity:major` 중 자동 선택 (상세: `severity-rules.md`).
4. **Regression** — 회귀 분류면 `state:regression` 추가.

**사전 조건**: 위 라벨이 모두 대상 레포에 미리 등록되어 있어야 `gh api ... -F 'labels[]=...'`가 422를 반환하지 않는다. 셋업은 `installation.md`의 "Label Setup" 참고.

## Safe Issue Creation Call (Bash 패턴)

`gh api`로 이슈를 생성할 때 **placeholder를 텍스트 치환해 명령행에 끼워 넣지 않는다** — bash 변수로만 통과시켜 `gh`의 `-f` form 인자에 넘긴다. bash가 변수의 따옴표·역슬래시·`$(...)`를 데이터로 보존하고, `gh api`가 `application/json`로 자동 직렬화하므로 외부 입력(Crashlytics display_name·stack_trace 등)의 shell injection이 차단된다. 응답 본문은 `python3` 표준 라이브러리로 파싱하므로 외부 jq 바이너리는 필요 없다.

이 패턴을 SKILL.md Step 4가 그대로 사용한다. 환경 변수 `RENDERED_TITLE`, `RENDERED_BODY`, `REPO`, `PLATFORM`, `SEVERITY`, `IS_REGRESSION`, `IS_UNIFIED`는 메인 세션이 분류 결과·서브에이전트 반환에서 채운다.

```bash
# 0) 라벨 인자 배열 — bash array로 인자 단위 분리(메타문자 안전).
LABEL_ARGS=(
  -F 'labels[]=source:crashlytics'
  -F "labels[]=os:${PLATFORM}"
  -F "labels[]=severity:${SEVERITY}"
)
# [ "$IS_REGRESSION" = "1" ] && LABEL_ARGS+=( -F 'labels[]=state:regression' )
# [ "$IS_UNIFIED"    = "1" ] && LABEL_ARGS=( -F 'labels[]=source:crashlytics' \
#                                            -F 'labels[]=os:ios' -F 'labels[]=os:android' \
#                                            -F "labels[]=severity:${SEVERITY}" )

# 1) 이슈 생성. -i로 헤더까지 받아 HTTP 코드를 직접 본다.
RAW=$(gh api -i -X POST "repos/${REPO}/issues" \
  -f "title=${RENDERED_TITLE}" \
  -f "body=${RENDERED_BODY}" \
  "${LABEL_ARGS[@]}" 2>&1) || true

HTTP_LINE=$(printf '%s\n' "$RAW" | head -1)
HTTP_CODE=$(printf '%s\n' "$HTTP_LINE" | awk '{print $2}')
BODY_TXT=$(printf '%s\n' "$RAW" | awk 'BEGIN{p=0} /^\r?$/{p=1; next} p{print}')

# 2) 2xx만 성공. 이미 받은 BODY_TXT를 python3로 파싱해 두 값 추출.
case "$HTTP_CODE" in
  2*)
    read ISSUE_URL ISSUE_NUMBER <<<"$(printf '%s' "$BODY_TXT" \
      | python3 -c 'import sys,json; o=json.load(sys.stdin); print(o["html_url"], o["number"])')"
    ;;
  *)
    # → SKILL.md config.retry.* 진입.
    ;;
esac
```

### 부분 실패·재시도

- 호출 실패(2xx 외) → SKILL.md `config.retry.*` 진입.
- 재시도 직전 멱등 가드: `gh issue list --repo <repo> --state all --search "\"crashlytics_issue_id: <issue_id>\" in:body" --json number,url --jq '.[0]'`. 매칭되면 기존 이슈 재사용.
- 이슈 생성 성공·메모 기록 실패 → 메모만 재시도. GitHub 이슈는 보존.

## Rationale

- **English field keys**: 다국어 팀 간 배포에 중립.
- **Collapsed stack trace**: 긴 스택이 이슈 리스트 프리뷰를 오염시키지 않게 한다.
- **HTML comment meta**: 다운스트림 파서(CI 스크립트, 대시보드)가 `crashlytics_issue_id`·`app_id`·`platform`을 마크다운 표 파싱 없이 얻을 수 있다. 특히 `crashlytics_issue_id`는 이 스킬의 **멱등 키** — `gh issue list --search '"crashlytics_issue_id: <id>" in:body" --state all`로 결정적 중복 탐지가 가능하다(제목의 모듈명 비결정성에 의존하지 않음).
