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

`CLOSE_CRASHLYTICS(outdated_version)` 분류된 이슈를 Firebase API로 close하면서 함께 append하는 감사용 메모.

```
[crashlytics-to-issue] auto-closed: <reason> v<crashlytics_max_version> <= closed #<previous_issue_number> v<closed_issue_max_version>
```

예: `[crashlytics-to-issue] auto-closed: outdated_version v1.0.3 <= closed #105 v1.0.3`

### Auto-close Parsing

```
^\[crashlytics-to-issue\] auto-closed: ([\w-]+) v(\S+) <= closed #(\d+) v(\S+)$
```

- Group 1: `reason` (예: `outdated_version`)
- Group 2: `crashlytics_max_version`
- Group 3: `previous_issue_number`
- Group 4: `closed_issue_max_version`

`reason`은 `[\w-]+`로 받아 `outdated_version` / `out-of-support` 등 enum 확장에도 lock-in 없이 대응한다.

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
