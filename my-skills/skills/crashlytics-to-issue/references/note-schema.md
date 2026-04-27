# Crashlytics Note Schema

트래킹 메모는 **한 줄짜리 포인터**다. 이 스킬이 Firebase Crashlytics 이슈에 기록하는 유일한 정보는 "이 크래시가 어떤 GitHub 이슈로 추적되고 있는가"이다.

## Format

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

## Parsing

정규식:

```
^\[crashlytics-to-issue\] #(\d+) (https://\S+)$
```

- Group 1: `issue_number` (정수 문자열, 사용 시 `int()` 변환)
- Group 2: `issue_url`

잘못된 형식이거나 prefix가 다른 메모는 무시한다.

## 최신 메모 선택

한 Crashlytics 이슈에 여러 트래킹 메모가 존재할 수 있다 (최초 등록 + 회귀 재등록). 분류 시점에는 **Crashlytics API가 제공하는 note `created_at` 타임스탬프가 가장 큰 것**을 현재 기록으로 사용한다.

```
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

- **포인터만, 상태는 저장 안 함**: 이슈의 해결 상태·해결 버전·제목 등은 GitHub이 단일 진실 원천. 메모에 중복 저장하면 drift 위험.
- **append-only**: Firebase Crashlytics API는 메모 편집을 지원하지 않는다. 새 이슈(회귀)로 재등록되면 새 메모를 append. 과거 메모는 삭제·변경하지 않는다.
- **버전 prefix 없음**: 포맷이 극단적으로 단순해 스키마 버전 번호가 불필요. 향후 변경 시에도 정규식 하나만 갱신하면 된다.

## 회귀 감지와의 관계

회귀 여부는 이 메모 자체에서 판정하지 않는다. 대신 메모에서 얻은 `issue_number`로 `gh issue view <N>`을 호출해 GitHub의 `state`와 `closedAt`을 비교한다. 상세는 `filter-rules.md` 참고.

이 설계는 외부 CI 훅이나 소비 도구에 대한 의존을 완전히 제거한다 — GitHub 자체가 "수정됐는가"의 권위 있는 답이기 때문이다.
