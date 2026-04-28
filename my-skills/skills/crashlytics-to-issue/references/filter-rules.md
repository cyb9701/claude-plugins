# Issue Filtering Rules — Duplicate, Regression & Outdated-Version Detection

각 Crashlytics 이슈에 대해 아래 일곱 분류 중 하나를 결정한다.

| Outcome                               | 의미                                                                                                                                                                |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `REGISTER(new)`                       | 추적 기록 없음 + GitHub 본문 매칭 없음. 신규 GitHub 이슈 생성.                                                                                                      |
| `REGISTER(regression)`                | GitHub 이슈가 close된 후, **닫힌 이슈 본문의 `max_app_version`보다 큰 앱 버전에서** 새 이벤트가 관측됨. 새 이슈 생성.                                               |
| `SKIP(already_registered)`            | GitHub 이슈가 `OPEN` 상태. 기존 링크 보존.                                                                                                                          |
| `SKIP(already_fixed)`                 | GitHub 이슈가 `CLOSED`(`completed`)인데, 본문 메타 또는 Crashlytics 측 버전 정보가 누락·파싱 불가해 회귀 판정이 불가. **보수적**으로 SKIP(false-positive 회피).     |
| `SKIP(closed_not_planned)`            | GitHub 이슈가 `CLOSED`(`not_planned`). 재등록하지 않음.                                                                                                             |
| `SKIP(legacy_linked)`                 | 추적 메모가 없지만 GitHub 본문에서 Crashlytics ID가 매칭됨. 링크 보존.                                                                                              |
| `CLOSE_CRASHLYTICS(outdated_version)` | GitHub 이슈가 close된 뒤 들어온 새 이벤트의 `max_app_version`이 닫힌 이슈 본문의 `max_app_version` **이하**. 구버전 잔존 사용자로 판정 → Firebase API로 자동 close. |

## Pseudocode

```python
def classify(issue, config):
    tracking = parse_latest_tracking_note(issue.notes)   # note-schema.md 참조

    if tracking is None:
        # 멱등 재확인: 본문의 <!-- crashlytics_issue_id: <id> --> 메타 주석으로 정확히 매칭.
        # (이전 실행에서 이슈 생성은 성공했는데 메모 기록만 실패한 경우를 회복)
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

    # 양측 어느 쪽이라도 버전 정보가 없거나 비교 불가 → 보수적 SKIP
    if closed_max_version is None:
        return SKIP(
            reason="already_fixed",
            link=tracking.url,
            warning="missing_app_version_meta",
        )
    if new_max_version is None:
        return SKIP(
            reason="already_fixed",
            link=tracking.url,
            warning="missing_crashlytics_version",
        )

    cmp = semver_compare(new_max_version, closed_max_version)
    if cmp is None:
        # 두 버전 중 하나라도 파싱 실패
        return SKIP(
            reason="already_fixed",
            link=tracking.url,
            warning="version_parse_failed",
        )

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
        # 다운그레이드 분기: auto_close가 꺼져 있으면 close 액션을 발생시키지 않고
        # 단순 SKIP으로 변환. 운영 디버깅을 위해 warning 토큰을 분리해 둔다.
        if not config.regression.auto_close:
            return SKIP(
                reason="already_fixed",
                link=tracking.url,
                warning="auto_close_disabled",
                context=result.context,   # 결과 표에 비교 결과 그대로 노출
            )
        return result

    # new_max_version > closed_max_version → 진짜 회귀
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

**주**: `--no-auto-close` 플래그는 메인 세션이 진입 시점에 `config.regression.auto_close`를 in-memory로 `False`로 덮어쓰는 방식으로 구현한다(파일은 수정하지 않는다). 따라서 `classify()`는 두 진입점을 같은 한 줄 분기로 흡수한다. 한편 Step 4-bis 진입 직전 도구 검증 실패에 의한 다운그레이드는 `auto_close_unsupported`라는 다른 warning 토큰으로 표기되며, 이는 SKILL.md Step 4-bis 단계에서 처리한다(`classify()` 외부).

## 구성 요소 설명

### `parse_latest_tracking_note`

`note-schema.md`의 정규식(`^\[crashlytics-to-issue\] #(\d+) (https://\S+)$`)으로 본문을 파싱해 `(number, url)`을 추출한다. 복수 메모가 있으면 `created_at` 최대값이 현재 기록. **tie-break**: `created_at`이 ms 동률인 경우 `issue_number`가 큰 쪽(회귀 재등록은 항상 번호가 증가).

`auto-closed:` prefix 메모는 이 정규식과 매칭되지 않는다(별도 감사 로그 책임 — `note-schema.md`).

### 이슈 상태 조회 — k개 배치

반환 필드 (세 경로 모두 동일):

- `state`: `"OPEN"` 또는 `"CLOSED"`
- `stateReason`: close 이유. `"completed"` / `"not_planned"` / `"reopened"` 중 하나. OPEN이면 `null`.
- `body`: 이슈 본문 markdown. `parse_max_app_version_from_body`의 입력.

선택 경로 (k = tracking note가 붙은 이슈 수):

#### 1차: `gh issue view` 병렬 (권장 기본값, k ≤ ~20)

```bash
gh issue view <number> --repo <owner>/<repo> --json state,stateReason,body
```

추적 메모가 붙은 이슈가 k개라면 한 어시스턴트 턴 안에서 k개의 Bash 호출을 병렬 tool_use로 발행. wall-clock은 1회 호출 수준으로 수렴한다. 구현이 단순하고 모든 필드가 신뢰성 있게 반환된다.

#### 2차: GraphQL 단일 호출 배치 (k ≥ ~20 또는 rate-limit이 빡빡할 때)

```bash
gh api graphql -f query='
  query {
    repository(owner: "<owner>", name: "<repo>") {
      i1: issue(number: 105) { state stateReason body }
      i2: issue(number: 106) { state stateReason body }
      i3: issue(number: 107) { state stateReason body }
    }
  }'
```

- 단일 API 호출로 k개 이슈 상태·본문을 한 번에 조회한다.
- 단점: 쿼리 문자열 조립 로직이 필요하고, 존재하지 않는 번호가 섞이면 해당 alias만 `null`로 돌아와 개별 체크가 필요. 본문 길이가 큰 이슈가 많으면 응답 크기 주의.

#### 비권장: `gh search issues`

검색 엔진은 인덱싱 지연이 있고 `stateReason` 제공이 일관적이지 않으며 본문은 별도 호출이 필요. 위 두 경로 중 하나를 선택할 것.

### `parse_max_app_version_from_body`

GitHub 이슈 본문의 `App Versions` 행에서 `{min} ~ {max}` 패턴을 정규식으로 매칭, max 값을 문자열로 반환한다.

```
정규식: r"^\|\s*App Versions\s*\|\s*(\S+)\s*~\s*(\S+)\s*\|"  (multiline)
Group 2 = max_app_version
```

매칭 실패 시 `None` 반환. 다음 케이스에 None이 발생할 수 있다:

- `schema_version: 1` 등 구 템플릿으로 만들어진 이슈
- 운영자가 수동 작성한 이슈
- 통합 이슈에서 행 포맷이 멀티라인으로 변형된 경우 (issue-template.md의 Unified Issues 규칙)

호출부는 None을 받으면 `SKIP(already_fixed, warning="missing_app_version_meta")`로 처리해 false-positive 회귀를 방지한다.

### `semver_compare`

[semver 2.0.0](https://semver.org/) 기준 두 버전을 비교해 `-1` / `0` / `+1`을 반환한다. 비교 불가하면 `None`.

규칙:

- 빌드 메타데이터(`+...`)는 비교에서 무시 (`1.0.3+45 == 1.0.3`).
- pre-release(`-beta.1`)는 표준대로 정상 버전보다 낮음 (`1.1.0-beta.1 < 1.1.0`, 그러나 `1.1.0-beta.1 > 1.0.99`).
- 단순 `MAJOR.MINOR.PATCH` 형식은 정수 튜플 비교.
- 비표준 자릿수(`1.2`, `1.2.3.4`)는 누락된 자리를 0으로 채워 정수 비교(`1.2` → `(1,2,0)`).
- 양쪽 모두 비표준이고 정수화 불가능한 토큰이 섞이면 `None`.

호출부는 `None`을 받으면 `SKIP(already_fixed, warning="version_parse_failed")`로 처리.

### `search_github_body_meta` — 본문 메타 기반 멱등 탐지

추적 메모가 없을 때의 재확인 경로. 이슈 본문의 HTML 메타 주석 `<!-- crashlytics_issue_id: <id> -->`를 정확 매칭한다 — 제목 포맷(모듈명 비결정성) 의존을 제거한다.

```bash
gh issue list \
  --repo <config.github.repo> \
  --search "\"crashlytics_issue_id: <issue_id>\" in:body" \
  --state all \
  --json number,url,title \
  --limit 5
```

매칭되면 `SKIP(legacy_linked)` 처리. 단, 스킬은 **폴백 매칭 결과를 기반으로 메모를 백필하지 않는다** (잘못된 매칭 시 Firebase 상태 오염 방지). 회귀 감지가 필요한 경우 운영자가 수동으로 해당 Crashlytics 이슈에 1줄 메모를 추가한다.

**인덱싱 지연 유의**: GitHub 검색은 신규 이슈 인덱싱에 수 초~수 분이 걸릴 수 있다. 같은 실행 내에서 방금 만든 이슈를 재탐지해야 한다면 검색이 아니라 **메모에 이미 적힌 이슈 번호**로 `gh issue view`를 직접 호출한다.

## Unified Issues (여러 앱에 동일 displayName)

iOS + Android 등에서 같은 `display_name`이 관측되면 GitHub 이슈 1건으로 통합한다.

1. **앱별 개별 분류**: 각 앱의 Crashlytics `issue_id`에 대해 위 `classify()`를 개별 실행.
2. **집계 — 사유 우선순위**:
   ```
   regression > new > already_registered > close_crashlytics
                    > already_fixed > closed_not_planned > legacy_linked
   ```
   하나라도 `REGISTER(*)`면 통합 결과도 `REGISTER(*)`. 그중 regression이 있으면 regression 우선.
3. **혼재 케이스 명시 처리**: 한 앱은 `CLOSE_CRASHLYTICS`, 다른 앱은 `REGISTER(regression)`인 경우 → 통합 결과는 `REGISTER(regression)`이지만, **close 액션은 해당 앱에 대해서만** 별개로 수행한다(GitHub 이슈는 1건 등록 + Firebase 측 close 1건).
4. **메모·close 액션은 앱별**: 각 앱의 Crashlytics `issue_id`에 각각의 액션을 수행. tracking 메모는 같은 GitHub URL을 가리키지만 close 액션은 해당 앱의 max_app_version 비교 결과에 따른다.

## Classification Telemetry

Step 5 요약 표는 모든 관측 이슈에 분류 사유를 표기한다. 운영 데이터로서의 의미:

- `new` 비율이 예상외로 높다 → 메모 쓰기 실패 또는 Firebase 권한 이슈.
- `legacy_linked`가 많다 → 구 이슈를 마이그레이션할 여지(수동으로 1줄 메모 추가).
- `regression` 발생 → 닫힌 이슈의 max_app_version 이상에서 실제로 다시 관측됐다는 뜻. 회귀 PR 필요.
- `close_crashlytics(outdated_version)` 다수 → 구버전 사용자 잔존 비율 높음. 강제 업데이트 정책 검토 트리거.
- `closed_not_planned` → 운영자가 "재현 불가" 등으로 종결한 이슈. 다시 올라오면 수동 재평가 필요(자동 재등록하지 않음).
- `already_fixed` 사유에 `warning="missing_app_version_meta"`가 자주 보이면 → 과거 이슈가 구 템플릿이라는 뜻. 운영자가 본문 보강 시 다음 실행부터 정확한 회귀 판정 가능.

## 설계 원칙

- **단일 진실 원천**: 메모는 포인터(어디로?), GitHub은 상태·임계점(어떻게 됐나? 어떤 버전까지 영향?). 책임 분리.
- **self-contained 회귀 감지**: 외부 CI 훅·pubspec.yaml·외부 config 없이 이 스킬만으로 회귀 감지가 작동한다. 닫힌 이슈 본문 자체가 자기 회귀 임계점을 들고 다닌다.
- **버전 기반 우선, 시간 grace 폐기**: 시간 grace는 구버전 잔존 사용자(false-positive)를 본질적으로 거를 수 없다. 버전 비교는 회귀의 본질을 직접 측정한다.
- **보수적 기본값**: 버전 메타 누락·파싱 실패 시 `REGISTER(regression)`이 아니라 `SKIP(already_fixed, warning=...)`로 fallback. 잘못된 회귀 등록으로 이슈를 스팸하는 것보다 한 번 놓치는 편이 복구 쉽다.
- **양방향 동기화 한정 도입**: 스킬이 Firebase 상태를 변경하는 건 `CLOSE_CRASHLYTICS` 한 경우뿐. 그 외 모든 경로는 read-only + append-only 메모로 유지해 부수효과 범위를 최소화.
