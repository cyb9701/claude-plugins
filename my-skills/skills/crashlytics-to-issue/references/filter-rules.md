# Issue Filtering Rules — Duplicate, Regression & Outdated-Version Detection

각 Crashlytics 이슈에 대해 아래 일곱 분류 중 하나를 결정한다.

| Outcome                               | 의미                                                                                                                                     |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `REGISTER(new)`                       | 추적 기록 없음 + GitHub 본문 매칭 없음. 신규 GitHub 이슈 생성.                                                                           |
| `REGISTER(regression)`                | GitHub 이슈가 close된 후, **닫힌 이슈 본문의 `max_app_version`보다 큰 앱 버전에서** 새 이벤트가 관측됨. 새 이슈 생성.                    |
| `SKIP(already_registered)`            | GitHub 이슈가 `OPEN` 상태. 기존 링크 보존.                                                                                               |
| `SKIP(already_fixed)`                 | GitHub 이슈가 `CLOSED(completed)`인데 버전 정보 누락·파싱 불가로 회귀 판정 불가. **보수적 SKIP** (false-positive 회피).                  |
| `SKIP(closed_not_planned)`            | GitHub 이슈가 `CLOSED(not_planned)`. 재등록하지 않음.                                                                                    |
| `SKIP(legacy_linked)`                 | 추적 메모는 없지만 GitHub 본문에서 Crashlytics ID가 매칭됨. 링크 보존.                                                                   |
| `CLOSE_CRASHLYTICS(outdated_version)` | GitHub 이슈가 close된 뒤 새 이벤트의 `max_app_version`이 닫힌 이슈 본문의 `max_app_version` **이하**. 구버전 잔존 → Firebase 자동 close. |

## Pseudocode

```python
def classify(issue, config):
    tracking = parse_latest_tracking_note(issue.notes)

    if tracking is None:
        # 멱등 재확인: 본문 메타 주석으로 정확 매칭
        legacy_match = search_github_body_meta(issue.issue_id, config.github.repo)
        if legacy_match is not None:
            return SKIP(reason="legacy_linked", link=legacy_match.url)
        return REGISTER(reason="new")

    # 추적 메모 존재 → GitHub이 현재 상태의 단일 진실 원천
    gh = gh_issue_view(
        number=tracking.number,
        repo=config.github.repo,
        fields=["state", "stateReason", "body"],
    )

    if gh.state == "OPEN":
        return SKIP(reason="already_registered", link=tracking.url)

    # CLOSED
    if gh.stateReason == "not_planned":
        return SKIP(reason="closed_not_planned", link=tracking.url)

    # CLOSED(completed) → 버전 비교로 회귀 vs 구버전 판정
    closed_max_version = parse_max_app_version_from_body(gh.body)
    new_max_version = issue.max_app_version

    if closed_max_version is None:
        return SKIP(reason="already_fixed", link=tracking.url, warning="missing_app_version_meta")
    if new_max_version is None:
        return SKIP(reason="already_fixed", link=tracking.url, warning="missing_crashlytics_version")

    cmp = semver_compare(new_max_version, closed_max_version)
    if cmp is None:
        return SKIP(reason="already_fixed", link=tracking.url, warning="version_parse_failed")

    if cmp <= 0:
        # new_max_version <= closed_max_version → 구버전 잔존 사용자
        result = CLOSE_CRASHLYTICS(
            reason="outdated_version",
            context={
                "previous_issue_number": tracking.number,
                "previous_issue_url": tracking.url,
                "closed_issue_max_version": closed_max_version,
                "crashlytics_max_version": new_max_version,
            },
        )
        # auto_close가 꺼져 있으면 close 액션 발생시키지 않고 SKIP으로 다운그레이드
        if not config.regression.auto_close:
            return SKIP(
                reason="already_fixed",
                link=tracking.url,
                warning="auto_close_skipped",
                context=result.context,
            )
        return result

    # new_max_version > closed_max_version → 회귀
    return REGISTER(
        reason="regression",
        context={
            "previous_issue_number": tracking.number,
            "previous_issue_url": tracking.url,
            "closed_issue_max_version": closed_max_version,
            "crashlytics_max_version": new_max_version,
        },
    )
```

## 구성 요소

### `parse_latest_tracking_note`

`note-schema.md`의 정규식(`^\[crashlytics-to-issue\] #(\d+) (https://\S+)$`)으로 `(number, url)` 추출. 복수 메모는 `created_at` 최댓값이 현재 기록. 동률이면 `issue_number`가 큰 쪽(회귀 재등록은 항상 번호가 증가).

### 이슈 상태 조회

추적 메모가 붙은 k개 이슈를 한 어시스턴트 턴 안에서 **k개 Bash tool_use 병렬 발행**:

```bash
gh issue view <number> --repo <owner>/<repo> --json state,stateReason,body
```

반환 필드:

- `state`: `"OPEN"` 또는 `"CLOSED"`
- `stateReason`: `"completed"` / `"not_planned"` / `"reopened"` / OPEN이면 `null`
- `body`: 이슈 본문 markdown (`parse_max_app_version_from_body`의 입력)

병렬 발행으로 wall-clock은 1회 호출 수준으로 수렴한다.

### `parse_max_app_version_from_body`

GitHub 이슈 본문의 `App Versions` 행에서 `{min} ~ {max}` 패턴을 정규식으로 매칭, max 값을 문자열로 반환.

```
정규식: r"^\|\s*App Versions\s*\|\s*(\S+)\s*~\s*(\S+)\s*\|"  (multiline)
Group 2 = max_app_version
```

매칭 실패 케이스 → None 반환:

- 운영자가 수동 작성한 이슈
- 통합 이슈에서 행 포맷이 멀티라인으로 변형된 경우 (issue-template.md의 Unified Issues 규칙으로 방지)

호출부는 None을 받으면 `SKIP(already_fixed, warning="missing_app_version_meta")`로 처리.

### `semver_compare`

[semver 2.0.0](https://semver.org/) 기준 두 버전 비교. `-1` / `0` / `+1`, 비교 불가하면 `None`.

규칙:

- 빌드 메타데이터(`+...`)는 무시 (`1.0.3+45 == 1.0.3`).
- pre-release(`-beta.1`)는 표준대로 정상 버전보다 낮음.
- 단순 `MAJOR.MINOR.PATCH`는 정수 튜플 비교.
- 비표준 자릿수(`1.2`, `1.2.3.4`)는 0으로 채워 비교(`1.2` → `(1,2,0)`).
- 양쪽 모두 비표준 + 정수화 불가 토큰이면 `None`.

호출부는 `None`을 받으면 `SKIP(already_fixed, warning="version_parse_failed")`로 처리.

### `search_github_body_meta` — 본문 메타 기반 멱등 탐지

추적 메모가 없을 때의 재확인 경로. 본문의 HTML 메타 주석을 정확 매칭한다.

```bash
gh issue list \
  --repo <config.github.repo> \
  --search "\"crashlytics_issue_id: <issue_id>\" in:body" \
  --state all \
  --json number,url,title \
  --limit 5
```

매칭되면 `SKIP(legacy_linked)`. 폴백 매칭 결과로 메모를 백필하지 않는다(잘못된 매칭 시 Firebase 상태 오염 방지).

GitHub 검색 인덱싱은 신규 이슈 반영에 수 초~수 분이 걸릴 수 있다. 같은 실행 내에서 방금 만든 이슈를 재탐지해야 한다면 **메모에 적힌 이슈 번호**로 `gh issue view`를 직접 호출한다.

## Unified Issues (여러 앱에 동일 displayName)

iOS + Android 등에서 같은 `display_name`이 관측되면 GitHub 이슈 1건으로 통합한다.

1. **앱별 개별 분류**: 각 앱의 Crashlytics `issue_id`에 대해 위 `classify()`를 개별 실행.
2. **사유 우선순위**: `regression > new > already_registered > close_crashlytics > already_fixed > closed_not_planned > legacy_linked`. 하나라도 `REGISTER(*)`면 통합 결과도 `REGISTER(*)`. regression이 있으면 regression 우선.
3. **혼재 케이스**: 한 앱은 `CLOSE_CRASHLYTICS`, 다른 앱은 `REGISTER(regression)`인 경우 → 통합 결과는 `REGISTER(regression)`이지만 close 액션은 해당 앱에 대해서만 별개로 수행.
4. **메모·close 액션은 앱별**: 각 앱의 Crashlytics `issue_id`에 각각의 액션. tracking 메모는 같은 GitHub URL을 가리키지만 close 액션은 해당 앱의 max_app_version 비교 결과에 따른다.

## 설계 원칙

- **단일 진실 원천**: 메모는 포인터(어디로?), GitHub은 상태·임계점(어떻게 됐나? 어떤 버전까지 영향?). 책임 분리.
- **버전 기반 회귀 감지**: 시간 grace는 구버전 잔존 사용자(false-positive)를 거를 수 없다. 버전 비교가 회귀의 본질을 직접 측정한다.
- **보수적 기본값**: 버전 메타 누락·파싱 실패 시 `REGISTER(regression)`이 아니라 `SKIP(already_fixed, warning=...)`. 잘못된 회귀 등록보다 한 번 놓치는 편이 복구 쉽다.
