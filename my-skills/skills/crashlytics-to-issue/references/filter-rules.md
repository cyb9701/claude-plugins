# Issue Filtering Rules — Duplicate & Regression Detection

각 Crashlytics 이슈에 대해 아래 다섯 분류 중 하나를 결정한다.

| Outcome                    | 의미                                                                         |
| -------------------------- | ---------------------------------------------------------------------------- |
| `REGISTER(new)`            | 추적 기록 없음 + GitHub 본문 매칭 없음. 신규 GitHub 이슈 생성.                |
| `REGISTER(regression)`     | GitHub 이슈는 close됐는데 close 이후 새 이벤트가 관측됨. 새 이슈 생성.       |
| `SKIP(already_registered)` | GitHub 이슈가 `OPEN` 상태. 기존 링크 보존.                                   |
| `SKIP(already_fixed)`      | GitHub 이슈가 `CLOSED`(`completed`)이고 close 이후 새 이벤트 없음. 링크 보존. |
| `SKIP(closed_not_planned)` | GitHub 이슈가 `CLOSED`(`not_planned`). 재등록하지 않음.                      |
| `SKIP(legacy_linked)`      | 추적 메모가 없지만 GitHub 본문에서 Crashlytics ID가 매칭됨. 링크 보존.       |

## Pseudocode

```
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
        fields=["state", "closedAt", "stateReason"],
    )

    if gh.state == "OPEN":
        return SKIP(reason="already_registered", link=tracking.url)

    # CLOSED
    if gh.stateReason == "not_planned":
        return SKIP(reason="closed_not_planned", link=tracking.url)

    # 안전장치: closedAt이 None인 비정상 CLOSED는 회귀로 승격한다
    # (재오픈 후 close 경합 등 GitHub API 이상 상태).
    if gh.closedAt is None:
        return REGISTER(
            reason="regression",
            context={
                "previous_issue_number": tracking.number,
                "previous_issue_url": tracking.url,
                "closed_at": None,
                "last_seen_at": issue.last_seen_at,
            },
        )

    # 완결 close (`completed`): close 이후에 새 이벤트가 있었으면 회귀
    grace = timedelta(hours=config.regression.grace_hours)   # 기본 1h, 외부화됨
    if issue.last_seen_at > gh.closedAt + grace:
        return REGISTER(
            reason="regression",
            context={
                "previous_issue_number": tracking.number,
                "previous_issue_url": tracking.url,
                "closed_at": gh.closedAt,
                "last_seen_at": issue.last_seen_at,
            },
        )

    return SKIP(reason="already_fixed", link=tracking.url)
```

## 구성 요소 설명

### `parse_latest_tracking_note`

`note-schema.md`의 정규식(`^\[crashlytics-to-issue\] #(\d+) (https://\S+)$`)으로 본문을 파싱해 `(number, url)`을 추출한다. 복수 메모가 있으면 `created_at` 최대값이 현재 기록. **tie-break**: `created_at`이 ms 동률인 경우 `issue_number`가 큰 쪽(회귀 재등록은 항상 번호가 증가).

### 이슈 상태 조회 — k개 배치

반환 필드 (세 경로 모두 동일):
- `state`: `"OPEN"` 또는 `"CLOSED"`
- `closedAt`: ISO 8601 datetime (close되지 않았으면 `null`)
- `stateReason`: close 이유. `"completed"` / `"not_planned"` / `"reopened"` 중 하나. OPEN이면 `null`.

선택 경로 (k = tracking note가 붙은 이슈 수):

#### 1차: `gh issue view` 병렬 (권장 기본값, k ≤ ~20)

```bash
gh issue view <number> --repo <owner>/<repo> --json state,closedAt,stateReason
```

추적 메모가 붙은 이슈가 k개라면 한 어시스턴트 턴 안에서 k개의 Bash 호출을 병렬 tool_use로 발행. wall-clock은 1회 호출 수준으로 수렴한다. 구현이 단순하고 모든 필드가 신뢰성 있게 반환된다.

#### 2차: GraphQL 단일 호출 배치 (k ≥ ~20 또는 rate-limit이 빡빡할 때)

```bash
gh api graphql -f query='
  query {
    repository(owner: "<owner>", name: "<repo>") {
      i1: issue(number: 105) { state closedAt stateReason }
      i2: issue(number: 106) { state closedAt stateReason }
      i3: issue(number: 107) { state closedAt stateReason }
    }
  }'
```

- 단일 API 호출로 k개 이슈 상태를 한 번에 조회한다.
- `closedAt`·`stateReason`이 `gh issue view`와 동일하게 반환된다.
- 단점: 쿼리 문자열 조립 로직이 필요하고, 존재하지 않는 번호가 섞이면 해당 alias만 `null`로 돌아와 개별 체크가 필요.

#### 비권장: `gh search issues`

검색 엔진은 인덱싱 지연이 있고 `stateReason` 제공이 일관적이지 않다. `gh issue view` 병렬 또는 GraphQL 배치를 선택할 것.

### Regression Grace Period

`config.regression.grace_hours` (기본 1). PR 머지로 이슈가 close되고 나서 **릴리스 빌드가 스토어에 배포되기 전**에 발생하는 마지막 이벤트를 회귀로 오판하지 않도록 하는 완충 시간.

1시간이 너무 짧거나 길다면 사용자 인스턴스(`${CLAUDE_PLUGIN_DATA}/crashlytics-to-issue/projects/<PROJECT_KEY>/config.json`)에서 값만 조정한다. 번들 템플릿(`${CLAUDE_SKILL_DIR}/config.json`)은 플러그인 업데이트 시 교체되므로 편집 대상이 아니다. 2026년 기준 모바일 앱의 TestFlight·Internal Testing 배포가 수 분 내 가능하지만, 프로덕션 릴리스는 수 시간~수 일 소요되기도 한다. **보수적으로** 회귀 트리거를 늦추려면 24~72로 늘릴 수 있다.

**경계 규약**: `issue.last_seen_at > gh.closedAt + grace` — 등호는 SKIP 쪽(`already_fixed`)에 포함된다.

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

1. **앱별 개별 분류**: 각 앱의 Crashlytics `issue_id`에 대해 위 규칙을 개별 실행.
2. **집계**:
   - 하나라도 `REGISTER(*)`면 통합 결과도 `REGISTER(*)`. 그중 regression이 있으면 regression 우선.
   - 전부 `SKIP`이면 통합 결과도 `SKIP`. 사유 우선순위: `already_registered` > `already_fixed` > `closed_not_planned` > `legacy_linked`.
3. **메모 기록은 앱별**: 각 앱의 Crashlytics `issue_id`에 각각 같은 GitHub URL을 가리키는 1줄 메모를 쓴다.

## Classification Telemetry

Step 5 요약 표는 모든 관측 이슈에 분류 사유를 표기한다. 운영 데이터로서의 의미:

- `new` 비율이 예상외로 높다 → 메모 쓰기 실패 또는 Firebase 권한 이슈.
- `legacy_linked`가 많다 → 구 이슈를 마이그레이션할 여지(수동으로 1줄 메모 추가).
- `regression` 발생 → 해당 Crashlytics 이슈에 대해 GitHub이 close된 시점 이후 실제 이벤트가 다시 관측됐다는 뜻. 회귀 PR 필요.
- `closed_not_planned` → 운영자가 "재현 불가" 등으로 종결한 이슈. 다시 올라오면 수동 재평가 필요(자동 재등록하지 않음).

## 설계 원칙

- **단일 진실 원천**: 메모는 포인터(어디로?), GitHub은 상태(어떻게 됐나?). 책임 분리.
- **self-contained 회귀 감지**: 외부 CI 훅 없이 이 스킬만으로 회귀 감지가 작동한다. 사용자의 설치 마찰이 낮다.
- **보수적 기본값**: `REGRESSION_GRACE_HOURS=1`, 메모 없음 + 폴백 매칭 있음이면 `SKIP`(재등록 하지 않음). false-positive로 이슈를 스팸하는 것보다 false-negative로 한 번 놓치는 편이 복구 쉽다.
