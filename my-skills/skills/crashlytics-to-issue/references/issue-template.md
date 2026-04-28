# Issue Template

## Title Format

**Fixed format** — 하드코딩이며 `config.json`으로 변경할 수 없다:

```
[Firebase Crashlytics] {module} - {summary}
```

### Tokens

| Token                    | Value                                                                                                                                                     |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `[Firebase Crashlytics]` | 리터럴 프리픽스. GitHub 필터(`gh issue list --search "[Firebase Crashlytics] in:title"`)에 대한 강력한 스코핑 키.                                         |
| `{module}`               | LLM이 스택 트레이스·`display_name`·`error_type`에서 추론한 **짧은 현장 언어 단어**. 예: `광고`, `출금`, `홈`, `Ads`, `Home`. 상세: `module-inference.md`. |
| `{summary}`              | Crashlytics `display_name`에서 추출한 1줄 오류 요약. 80자 초과 시 truncate.                                                                               |

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
- **`App Versions` 행은 반드시 한 줄로 union된 `{global_min} ~ {global_max}` 만 기록한다** — `global_min = min(앱별 min_app_version)`, `global_max = max(앱별 max_app_version)`. 멀티라인 분기로 렌더하면 회귀 판정 정규식(`filter-rules.md`의 `parse_max_app_version_from_body`, `^\|\s*App Versions\s*\|\s*(\S+)\s*~\s*(\S+)\s*\|`)이 매칭 실패해 통합 이슈는 사실상 회귀 감지 불가능 상태가 된다. 앱별 분기 정보가 필요하다면 본문 하단에 별도 `### App-specific Versions` 보조 표를 추가하는 방식으로 격리한다(정규식이 보조 표 행은 매칭하지 않도록 `App Versions` 정확 라벨만 사용).
- **`OS Versions` 행도 동일** — 하나의 union된 `min ~ max`. 회귀 판정에는 영향 없지만 일관성 유지.
- Each app's `app_id` **and** `crashlytics_issue_id`가 각각 한 줄의 HTML comment로 per-app 블록을 이룬다. 한 이슈 본문에 여러 `<!-- crashlytics_issue_id: ... -->` 라인이 존재할 수 있다.

**왜 한 줄 union인가**: 회귀 판정의 단일 진실 원천은 "이 닫힌 이슈에서 가장 높았던 max_app_version"이다. 통합 이슈도 `max(앱별 max)` 한 점만 알면 회귀 vs 구버전 판정이 가능하므로, 굳이 앱별로 쪼개 본문 정규식을 깨뜨릴 이유가 없다. SRP: 본문은 회귀 판정 입력, 보조 표는 사람을 위한 부가 정보.

## Regression Rendering

When the classification is `REGISTER(regression)`, prepend this block at the very top of the body (before `## Crashlytics Report`):

```markdown
> **⚠️ Regression detected**
>
> 이 크래시는 이전에 [#{previous_issue_number}]({previous_issue_url})로 등록·처리됐지만, 닫힌 이슈의 max_app_version `{closed_issue_max_version}` 이후 버전인 `{crashlytics_max_version}`에서 다시 관측되어 회귀로 재등록됐다.
>
> - Previous issue: [#{previous_issue_number}]({previous_issue_url})
> - Previous issue max app version: `{closed_issue_max_version}`
> - Crashlytics current max app version: `{crashlytics_max_version}`
```

The `regression` label on the issue makes it trivially filterable in GitHub.

**왜 버전 정보만 표시하는가**: 회귀 판정 자체가 시간이 아닌 max_app_version 비교 결과로 일어나기 때문에, 본문도 그 판정 근거를 그대로 노출한다. 닫힌 시각·마지막 관측 시각은 GitHub timeline / Crashlytics 콘솔에서 한 클릭으로 확인 가능하므로 본문에서 중복 표시하지 않는다(SRP).

## Labels

모든 라벨은 `key:value` 네임스페이스 규약을 따른다. 이슈 1건에 대해 아래 순서로 조합된다.

1. **`config.github.default_labels`** — 기본 `["source:crashlytics"]`. 항상 부여.
2. **Platform** — `os:ios` 또는 `os:android`. 통합 이슈(iOS+Android)는 두 값 모두 부여.
3. **Severity** — `severity:blocker`, `severity:critical`, `severity:major` 중 자동 선택 (상세: `severity-rules.md`).
4. **Regression** — 회귀로 분류된 경우에만 `state:regression` 추가.

**사전 조건**: 위 라벨이 모두 대상 레포에 미리 등록되어 있어야 `gh api ... -F 'labels[]=...'` 이슈 생성 호출이 라벨 누락으로 422를 반환하지 않는다. 셋업 방법은 `installation.md`의 "Label Setup" 섹션 참고.

## Issue Type

`config.github.issue_type`이 지정되면(기본: `"Bug"`) `gh api -X POST /repos/.../issues -f type="<value>"`로 전달되어 GitHub Issue Type 필드가 설정된다.

- `gh issue create`는 `--type` 플래그를 지원하지 않으므로([cli/cli#9696](https://github.com/cli/cli/issues/9696)) Step 4는 항상 `gh api` REST 호출을 사용한다. 응답 본문 파싱은 `python3` 표준 라이브러리(`json`)로, 별도 `gh issue list` 같은 호출에서는 gh 임베드 gojq의 `--jq` 플래그로 끝낸다 — **외부 jq 바이너리는 필요 없다**.
- `issue_type: null`이면 1차 시도부터 `-f type=...`을 생략. Issue Types 미활성화 조직·필드 미사용 환경에 대응.
- 1차 시도가 실패하면(타입 미존재·조직 비활성화 등) **type만 빼고 1회 한정 재시도**한다. 이슈 자체는 항상 생성된다 — 데이터 손실 방지가 일관성보다 우선. 이 fallback은 *클라이언트 사전 적응*이며 조직이 type을 받지 않는 환경에서만 발동한다.
- 재시도도 실패하면 SKILL.md의 `config.retry.*` retry 로직에 진입하며, 이때는 1차/2차 명령을 그대로 반복하는 게 아니라 **type 제외 명령만 반복**한다(불필요한 1차 실패 누적 방지).

## Safe Issue Creation Call (Bash 패턴)

`gh api`로 이슈를 생성할 때 **placeholder를 텍스트 치환해 명령행에 끼워 넣지 않는다** — bash 변수로만 통과시켜 `gh`의 `-f` form 인자에 넘긴다. bash가 변수의 따옴표·역슬래시·`$(...)`를 데이터로만 보존하고, `gh api`가 GitHub API의 `application/json`로 자동 직렬화하므로 외부 입력(Crashlytics display_name·stack_trace 등)의 shell injection이 차단된다. 응답 본문은 `python3` 표준 라이브러리로 파싱하므로 외부 jq 바이너리는 필요 없다.

이 패턴은 SKILL.md Step 4가 그대로 사용한다. 환경 변수 `RENDERED_TITLE`, `RENDERED_BODY`, `REPO`, `PLATFORM`, `SEVERITY`, `ISSUE_TYPE`, `IS_REGRESSION`, `IS_UNIFIED`는 메인 세션이 분류 결과·서브에이전트 반환에서 채운다.

```bash
# 0) 라벨 인자 배열 — bash array로 인자 단위 분리(메타문자 안전).
#    회귀면 "state:regression" 추가, 통합 이슈면 "os:ios"+"os:android" 둘 다.
LABEL_ARGS=(
  -F 'labels[]=source:crashlytics'
  -F "labels[]=os:${PLATFORM}"
  -F "labels[]=severity:${SEVERITY}"
)
# [ "$IS_REGRESSION" = "1" ] && LABEL_ARGS+=( -F 'labels[]=state:regression' )
# [ "$IS_UNIFIED"    = "1" ] && LABEL_ARGS=( -F 'labels[]=source:crashlytics' \
#                                            -F 'labels[]=os:ios' -F 'labels[]=os:android' \
#                                            -F "labels[]=severity:${SEVERITY}" )

# 1) 1차 시도 — type 포함. -f/-F는 변수 quoting을 보존하므로 외부 입력의 메타문자가
#    명령행 메타문자로 재해석되지 않는다. -i로 헤더까지 받아 HTTP 코드를 직접 본다.
build_call() {                            # type 인자 유무에 따른 명령 구성
  local extra=()
  [ -n "$ISSUE_TYPE" ] && extra=( -f "type=${ISSUE_TYPE}" )
  gh api -i -X POST "repos/${REPO}/issues" \
    -f "title=${RENDERED_TITLE}" \
    -f "body=${RENDERED_BODY}" \
    "${extra[@]}" \
    "${LABEL_ARGS[@]}"
}

RAW=$(build_call 2>&1) || true
HTTP_LINE=$(printf '%s\n' "$RAW" | head -1)              # 예: HTTP/2.0 422 Unprocessable Entity
HTTP_CODE=$(printf '%s\n' "$HTTP_LINE" | awk '{print $2}')
BODY_TXT=$(printf '%s\n' "$RAW" | awk 'BEGIN{p=0} /^\r?$/{p=1; next} p{print}')

# 2) 422이면서 본문이 type 관련 메시지일 때만 2차(type 제외) — 그 외 실패는
#    type fallback이 무의미하므로 1차 에러를 그대로 retry/실패 경로로 넘긴다.
if [[ "$HTTP_CODE" == "422" && "$BODY_TXT" == *"type"* && -n "$ISSUE_TYPE" ]]; then
  ISSUE_TYPE=""                            # 이 호출부터 type 영구 제외
  RAW=$(build_call 2>&1) || true
  HTTP_LINE=$(printf '%s\n' "$RAW" | head -1)
  HTTP_CODE=$(printf '%s\n' "$HTTP_LINE" | awk '{print $2}')
  BODY_TXT=$(printf '%s\n' "$RAW" | awk 'BEGIN{p=0} /^\r?$/{p=1; next} p{print}')
fi

# 3) 2xx만 성공. 이미 받은 BODY_TXT를 python3 표준 라이브러리로 파싱해 두 값 추출.
#    추가 API 호출 없음 — 외부 jq 바이너리 불필요, gh의 --jq는 별개 호출 시에만 등장.
case "$HTTP_CODE" in
  2*)
    read ISSUE_URL ISSUE_NUMBER <<<"$(printf '%s' "$BODY_TXT" \
      | python3 -c 'import sys,json; o=json.load(sys.stdin); print(o["html_url"], o["number"])')"
    ;;
  *)
    # → config.retry.* 진입. 재시도 시에는 마지막 ISSUE_TYPE 상태(2차에 들어갔으면 빈 문자열)를
    # 그대로 유지해 1차 422를 누적시키지 않는다. build_call이 동일 인자 모양을 재구성한다.
    ;;
esac
```

> **대안**: `gh api ... --jq '"\(.html_url) \(.number)"'`를 한 번 더 호출하면 외부 jq 없이도 두 값을 한 줄로 받을 수 있다. 다만 **이슈가 두 번 생성**되므로 `-i`로 받은 본문(`BODY_TXT`)을 재파싱하는 위 패턴이 안전하다.

### 부분 실패·재시도

- 호출 실패(2xx 외) → SKILL.md `config.retry.*` 진입. 재시도 시에는 마지막 `ISSUE_TYPE` 상태(2차에서 type fallback에 들어갔으면 빈 문자열)를 그대로 유지해 1차 422를 누적시키지 않는다.
- 재시도 직전 멱등 가드: `gh issue list --repo <repo> --state all --search "\"crashlytics_issue_id: <issue_id>\" in:body" --json number,url --jq '.[0]'` (gh 내장 `--jq`라 외부 jq 불필요). 매칭되면 기존 이슈 재사용.
- 이슈 생성은 성공·메모 기록 실패 → 메모만 재시도. 최종 실패해도 GitHub 이슈는 유지.

## Rationale

- **Why English field keys**: language-neutral for distribution across teams with different working languages.
- **Why a collapsed stack trace**: long stacks pollute the issue list preview; one click to expand keeps details one gesture away.
- **Why HTML comment meta**: downstream parsers (CI scripts, dashboards) can read `app_id`, `platform`, `crashlytics_issue_id`를 마크다운 표 파싱 없이 얻을 수 있다. 특히 `crashlytics_issue_id`는 이 스킬의 **멱등 키**로 쓰인다 — `gh issue list --search '"crashlytics_issue_id: <id>" in:body' --state all`로 왕복 조회가 가능해, 제목 문자열(모듈명 비결정성)에 의존하지 않는 결정적 중복 탐지가 된다.
- **Why `schema_version` in a comment**: future-proofing. If the template changes, consumers can detect the version and adapt.
