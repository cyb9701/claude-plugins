# Crashlytics Note Schema

이 스킬은 Crashlytics 이슈에 두 종류의 메모를 기록한다.

| 메모 종류           | Prefix                                    | 책임                                                                    |
| ------------------- | ----------------------------------------- | ----------------------------------------------------------------------- |
| **Tracking Note**   | `[crashlytics-to-issue] #<num> <url>`     | "이 크래시는 어떤 GitHub 이슈로 추적되고 있는가" — 한 줄짜리 **포인터** |
| **Auto-close Note** | `[crashlytics-to-issue] auto-closed: ...` | "왜 Firebase에서 이 이슈를 닫았는가" — **감사 로그**                    |

두 메모는 책임이 다르므로(SRP) 서로 다른 정규식으로 파싱하며, tracking 정규식은 auto-close 메모를 매칭하지 **않는다**.

## Tracking Note Format

```
[crashlytics-to-issue] #<issue_number> <issue_url>
```

예:

```
[crashlytics-to-issue] #105 https://github.com/owner/repo/issues/105
```

세 토큰이 공백 하나로 구분된다:

1. `[crashlytics-to-issue]` — 리터럴 prefix. 파싱 식별자.
2. `#<issue_number>` — GitHub 이슈 번호(정수, `#` 접두).
3. `<issue_url>` — 전체 URL.

### Tracking Parsing

정규식:

```
^\[crashlytics-to-issue\] #(\d+) (https://\S+)$
```

- Group 1: `issue_number` (정수 문자열, 사용 시 `int()` 변환)
- Group 2: `issue_url`

잘못된 형식이거나 prefix가 다른 메모(특히 `auto-closed:` prefix)는 무시한다.

## Auto-close Note Format

`CLOSE_CRASHLYTICS(outdated_version)` 분류된 이슈를 Firebase API로 close하면서 함께 append하는 감사용 메모.

```
[crashlytics-to-issue] auto-closed: <reason> v<crashlytics_max_version> <= closed #<previous_issue_number> v<closed_issue_max_version>
```

예:

```
[crashlytics-to-issue] auto-closed: outdated_version v1.0.3 <= closed #105 v1.0.3
```

토큰 의미:

1. `[crashlytics-to-issue]` — 리터럴 prefix(공통).
2. `auto-closed:` — 메모 종류 식별자.
3. `<reason>` — 현재는 `outdated_version` 단일 값. 향후 다른 자동 close 사유가 추가되면 enum 확장. 정규식은 영숫자·언더스코어·하이픈을 모두 허용(`[\w-]+`)해 `outdated-version` / `out_of_support` 등 어떤 토큰 스타일이 채택돼도 lock-in 없이 받아들일 수 있다.
4. `v<crashlytics_max_version>` — close 시점의 Crashlytics 측 max_app_version.
5. `<= closed #<previous_issue_number> v<closed_issue_max_version>` — 비교 기준이 된 닫힌 GitHub 이슈와 그 이슈의 max_app_version.

### Auto-close Parsing

정규식:

```
^\[crashlytics-to-issue\] auto-closed: ([\w-]+) v(\S+) <= closed #(\d+) v(\S+)$
```

- Group 1: `reason` (예: `outdated_version`)
- Group 2: `crashlytics_max_version`
- Group 3: `previous_issue_number`
- Group 4: `closed_issue_max_version`

이 메모는 tracking 정규식과 **상호 배타적**이다 — `auto-closed:` 토큰 때문에 `^\[crashlytics-to-issue\] #(\d+)` 패턴과 일치하지 않는다. 따라서 `parse_latest_tracking_note` 호출 시 자동으로 무시된다.

## 최신 메모 선택 (Tracking 한정)

한 Crashlytics 이슈에 여러 트래킹 메모가 존재할 수 있다 (최초 등록 + 회귀 재등록). 분류 시점에는 **Crashlytics API가 제공하는 note `created_at` 타임스탬프가 가장 큰 것**을 현재 기록으로 사용한다.

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

`auto-closed:` 메모는 패턴 매칭 자체가 안 되어 자동으로 제외된다.

## 설계 원칙

- **책임 분리**: tracking 메모는 "어디로?"의 답(포인터), auto-close 메모는 "왜 닫았는가?"의 답(감사 로그). 두 책임을 한 메모에 합치면 정규식 하나로 두 의미를 동시에 해석하게 되어 drift 위험.
- **포인터만, 상태는 저장 안 함**: 이슈의 해결 상태·해결 버전·제목 등은 GitHub이 단일 진실 원천. tracking 메모에 중복 저장하면 drift 위험. (auto-close 메모는 close **시점의** 비교 결과를 기록하는 스냅샷이지 현재 상태가 아니다.)
- **append-only**: Firebase Crashlytics API는 메모 편집을 지원하지 않는다. 새 이슈(회귀)로 재등록되면 새 tracking 메모를 append. close 액션이 일어나면 auto-close 메모도 append. 과거 메모는 절대 삭제·변경하지 않는다.
- **버전 prefix 없음**: 포맷이 극단적으로 단순해 스키마 버전 번호가 불필요. 향후 변경 시에도 정규식만 갱신하면 된다.

## 회귀 감지와의 관계

회귀 여부는 이 메모 자체에서 판정하지 않는다. 대신 메모에서 얻은 `issue_number`로 `gh issue view <N>`을 호출해 GitHub의 `state`·`stateReason`·`body`를 가져와, 본문의 `App Versions` 행에서 `max_app_version`을 추출해 Crashlytics 측 `max_app_version`과 semver 비교한다. 상세는 `filter-rules.md` 참고.

이 설계는 외부 CI 훅이나 소비 도구에 대한 의존을 완전히 제거한다 — GitHub 이슈 본문 자체가 "수정됐는가" + "어느 버전까지 영향받았는가"의 권위 있는 답이기 때문이다.

## Public Contract — 외부 도구 호환

| Prefix                                | 정규식                                                                            | 외부 도구가 얻을 수 있는 정보                                        |
| ------------------------------------- | --------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| `[crashlytics-to-issue] #`            | `^\[crashlytics-to-issue\] #(\d+) (https://\S+)$`                                 | 이 크래시가 연결된 GitHub 이슈 번호·URL                              |
| `[crashlytics-to-issue] auto-closed:` | `^\[crashlytics-to-issue\] auto-closed: ([\w-]+) v(\S+) <= closed #(\d+) v(\S+)$` | 자동 close 시점의 비교 결과(어떤 버전이 어떤 닫힌 이슈와 비교됐는가) |

두 정규식 모두 lock-in이다 — 이 스킬을 쓰는 다른 도구·대시보드는 이 정규식을 신뢰하고 의존할 수 있다. 변경 시 메이저 버전 bump.
