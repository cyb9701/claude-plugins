# Crashlytics Note Schema

이 스킬은 Crashlytics 이슈에 두 종류의 메모를 기록한다.

| 메모 종류           | Prefix                                    | 책임                                                                |
| ------------------- | ----------------------------------------- | ------------------------------------------------------------------- |
| **Tracking Note**   | `[crashlytics-to-issue] #<num> <url>`     | "이 크래시는 어떤 GitHub 이슈로 추적되고 있는가" — 한 줄 **포인터** |
| **Auto-close Note** | `[crashlytics-to-issue] auto-closed: ...` | "왜 Firebase에서 이 이슈를 닫았는가" — **감사 로그**                |

두 메모는 책임이 다르므로(SRP) 정규식도 별개다. tracking 정규식은 auto-close 메모를 매칭하지 **않는다**.

## Tracking Note Format

```
[crashlytics-to-issue] #<issue_number> <issue_url>
```

예: `[crashlytics-to-issue] #105 https://github.com/owner/repo/issues/105`

### Tracking Parsing

```
^\[crashlytics-to-issue\] #(\d+) (https://\S+)$
```

- Group 1: `issue_number` (정수 문자열)
- Group 2: `issue_url`

`auto-closed:` prefix 메모는 이 패턴에 매칭되지 않으므로 자동 무시된다.

## Auto-close Note Format

Firebase Crashlytics 이슈를 close하면서 함께 append하는 감사용 메모. 두 가지 포맷이 존재한다 — 닫힌 GitHub 이슈의 `max_app_version`을 비교 컨텍스트로 가질 수 있느냐에 따라 분기.

### Long Format (closed 비교 컨텍스트 있음)

`CLOSE_CRASHLYTICS(outdated_version)` 또는 `REGISTER(regression)`처럼 닫힌 이슈의 `max_app_version`이 명확한 케이스에서 사용.

```
[crashlytics-to-issue] auto-closed: <reason> v<crashlytics_max_version> <= closed #<previous_issue_number> v<closed_issue_max_version>
```

예: `[crashlytics-to-issue] auto-closed: outdated_version v1.0.3 <= closed #105 v1.0.3`

### Short Format (linked 참조만)

`SKIP(already_registered)`처럼 이전 이슈가 OPEN(`auto_close_queue` 자동 라우팅)이거나 `SKIP(legacy_linked, OPEN)`처럼 본문 매칭만 있는 OPEN 케이스, 또는 CLOSED이지만 본문 파싱 실패한 케이스 — 닫힌 시점의 `max_app_version`을 신뢰할 수 없을 때 사용.

```
[crashlytics-to-issue] auto-closed: <reason> v<crashlytics_max_version> linked #<previous_issue_number>
```

예: `[crashlytics-to-issue] auto-closed: auto_close_open_issue v1.0.4 linked #87`

### Auto-close Parsing

두 포맷을 동시에 매칭하는 단일 정규식:

```
^\[crashlytics-to-issue\] auto-closed: ([\w-]+) v(\S+)(?: <= closed #(\d+) v(\S+)| linked #(\d+))$
```

- Group 1: `reason` (예: `outdated_version`, `auto_close_open_issue`, `user_decision_fixed`)
- Group 2: `crashlytics_max_version`
- Group 3: `previous_issue_number` (long format)
- Group 4: `closed_issue_max_version` (long format)
- Group 5: `previous_issue_number` (short format)

호출부는 Group 3과 Group 5 중 매칭된 쪽을 `previous_issue_number`로 사용한다. Group 4가 비어 있으면 short format으로 판정한다.

### Reason Enum

`reason`은 `[\w-]+`로 받아 enum 확장을 lock-in 없이 허용한다. 현재 정의된 값:

| Reason                      | 발생 컨텍스트                                                                      | 사용 포맷                                                                |
| --------------------------- | ---------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| `auto_close_open_issue`     | `SKIP(already_registered)` 분류 — `auto_close_queue` 자동 라우팅 (사용자 미개입).  | Short (OPEN 이슈이므로 closed_max 없음)                                  |
| `auto_close_legacy_open`    | `SKIP(legacy_linked, OPEN)` 분류 — `auto_close_queue` 자동 라우팅 (사용자 미개입). | Short                                                                    |
| `outdated_version`          | `CLOSE_CRASHLYTICS(outdated_version)` 분류된 케이스에서 사용자가 `닫기` 선택.      | Long                                                                     |
| `user_decision_regression`  | `REGISTER(regression)` 분류 + 사용자 `닫기` 선택.                                  | Long                                                                     |
| `user_decision_fixed`       | `SKIP(already_fixed)` 분류 + 사용자 `닫기` 선택.                                   | Long when closed_issue_max_version is present, else Short                |
| `user_decision_not_planned` | `SKIP(closed_not_planned)` 분류 + 사용자 `닫기` 선택.                              | Long                                                                     |
| `user_decision_legacy`      | `SKIP(legacy_linked, CLOSED)` 분류 + 사용자 `닫기` 선택.                           | Long when GitHub issue state == CLOSED and parsing succeeded, else Short |

**접두어 의미**:

- `auto_close_*` — 분류 단계에서 자동 라우팅된 close (사용자 결정 없이 시스템이 안전한 디폴트로 처리).
- `user_decision_*` — Step 3.6 사용자 결정에서 비롯된 close.
- `outdated_version` — 별도 reason (사용자 결정이지만 분류 자체가 명시적이라 접두어 없음).

한 줄만 보고도 close 출처를 자동/사용자로 구분 가능하다.

## Decision Audit Trail

Step 3.6 사용자가 `닫기`를 선택했거나 분류 단계에서 `auto_close_queue`로 자동 라우팅되면 본 메모가 Firebase Crashlytics에 append된다. 이 메모는 다음 실행에서 다음 효과를 보장한다:

1. **멱등 보장**: 이미 close된 Crashlytics 이슈는 다음 실행의 조회 결과(`crashlytics_list_events`)에 등장하지 않는다. 따라서 같은 이슈에 대해 자동 close나 사용자 결정이 반복되지 않는다.
2. **감사 가능성**: `reason` 필드의 `auto_close_*` / `user_decision_*` 접두어로 "왜 닫혔는가"의 컨텍스트를 한 줄에서 즉시 파악 가능 — 자동 close인지 사용자 결정인지 즉시 식별. 운영 회고 시 잘못된 결정·라우팅을 역추적할 수 있다.
3. **수동 reopen 안전성**: 운영자가 Firebase 콘솔에서 close를 reopen하면 다시 조회 결과에 등장하지만, tracking 메모가 그대로 남아 있어 같은 GitHub 이슈와 연결된 상태가 유지된다. 사용자는 새 컨텍스트에서 다시 결정할 수 있다 (`auto_close_*` 케이스라면 같은 분류로 재진입해 다시 auto-close, `user_decision_*`이라면 결정 큐 진입).

설계 원칙: append-only 보존(라인 73) + 멱등 키 분리(tracking 메모 vs auto-close 메모)로 사용자 결정 이력은 누적되며 잃지 않는다.

## 최신 메모 선택 (Tracking 한정)

한 Crashlytics 이슈에 여러 트래킹 메모가 존재할 수 있다(최초 등록 + 회귀 재등록). `created_at` 최대값을 현재 기록으로 사용한다. ms 동률이면 `issue_number`가 큰 쪽(회귀 재등록은 항상 번호가 증가).

```python
def latest_tracking_note(notes):
    matches = [
        (note, m) for note in notes
        for m in [re.match(r"^\[crashlytics-to-issue\] #(\d+) (https://\S+)$", note.body.strip())]
        if m
    ]
    if not matches: return None
    note, m = max(matches, key=lambda pair: pair[0].created_at)
    return { "number": int(m.group(1)), "url": m.group(2) }
```

## 설계 원칙

- **책임 분리**: tracking 메모는 "어디로?"의 답(포인터), auto-close 메모는 "왜 닫았는가?"의 답(감사 로그). 두 책임을 한 메모에 합치면 정규식 하나로 두 의미를 동시에 해석하게 되어 drift 위험.
- **append-only**: Firebase Crashlytics API는 메모 편집을 지원하지 않는다. 회귀 재등록·auto-close 시 새 메모를 append하며, 과거 메모는 보존한다.

## 회귀 감지와의 관계

회귀 여부는 메모 자체가 아니라 메모에서 얻은 `issue_number`로 GitHub 본문의 `App Versions` 행을 읽어 max_app_version을 비교해 판정한다. 상세는 `filter-rules.md` 참고.
