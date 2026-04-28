# Issue Template

## Title Format

**Fixed format** — 하드코딩이며 `config.json`으로 변경할 수 없다:

```
[Firebase Crashlytics] {module} - {summary}
```

### Tokens

| Token                    | Value                                                                                                                                     |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- |
| `[Firebase Crashlytics]` | 리터럴 프리픽스. `gh issue list --search "[Firebase Crashlytics] in:title"`처럼 라벨 필터 없이도 자동 등록분만 좁힐 수 있는 키.           |
| `{module}`               | LLM이 스택 트레이스·`display_name`·`error_type`에서 추론한 짧은 현장 언어 단어 (예: `광고`, `출금`, `Home`). 상세: `module-inference.md`. |
| `{summary}`              | Crashlytics `display_name`에서 추출한 1줄 오류 요약. 80자 초과 시 truncate.                                                               |

### Examples

```
[Firebase Crashlytics] 출금 - NSRangeException in transaction list
[Firebase Crashlytics] 홈 - NullPointerException in ViewModel.fetchBalance
[Firebase Crashlytics] 광고 - AdMob SDK initialization failed
```

서비스명·플랫폼은 제목에 넣지 않는다 — 플랫폼은 `os:ios`/`os:android` 라벨과 본문 `Platform` 행에 이미 있다.

## Body Template

이 템플릿을 그대로 사용한다. 필드는 영문 키로 고정(언어 중립), HTML 주석 블록은 머신 파싱용 fallback이다.

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
<!-- crashlytics_issue_id: {issue_id} -->
<!-- app_id: {app_id} -->
<!-- platform: {platform} -->
````

## Unified Issues (iOS + Android)

같은 `display_name`이 여러 앱/플랫폼에 나오면 단일 GitHub 이슈로 통합.

- **Crashlytics Issue ID** 행은 앱마다 한 줄씩 반복.
- **App** 행은 멀티라인 또는 콤마 구분.
- **Platform**은 `iOS+Android` (알파벳 순).
- Event count, impacted users는 **합산**.
- **`App Versions` 행은 반드시 한 줄로 union된 `{global_min} ~ {global_max}`**. `global_min = min(앱별 min)`, `global_max = max(앱별 max)`. 멀티라인으로 분기하면 회귀 정규식(`^\|\s*App Versions\s*\|\s*(\S+)\s*~\s*(\S+)\s*\|`)이 매칭 실패해 회귀 감지가 깨진다. 앱별 분기 정보가 필요하면 본문 하단에 별도 `### App-specific Versions` 보조 표를 추가.
- **`OS Versions` 행도 동일** — union된 `min ~ max`. 회귀 판정엔 영향 없지만 일관성 유지.
- 앱별 `<!-- crashlytics_issue_id: ... -->` 라인이 한 본문에 여러 줄 존재할 수 있다.

회귀 판정의 단일 진실 원천은 "이 닫힌 이슈에서 가장 높았던 max_app_version" — 통합 이슈도 `max(앱별 max)` 한 점만 알면 충분하다.

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
