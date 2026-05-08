# 단일 이슈 PR 본문 템플릿

본 스킬이 생성하는 PR은 **이슈 1건당 PR 1개**다. 항상 아래 7개 섹션을 가지며, 섹션 순서·헤더 텍스트는 고정. 빈 섹션은 "해당 없음"으로 명시(섹션 자체를 생략하지 않음).

## 템플릿

````markdown
## 연결된 GitHub Issue

본 PR은 다음 이슈를 닫는다.

- Closes #<issue_number> — <issue_title>

원본 이슈: [#<issue_number>](issue_url)

## 이슈 요약

| 항목             | 값                                  |
| ---------------- | ----------------------------------- |
| 영향받는 앱 / OS | `<app_display_name>` / `<platform>` |
| Crashlytics ID   | `<crashlytics_issue_id>`            |
| events / users   | `<events>` / `<users>`              |
| first seen       | `<first_seen_at>`                   |
| last seen        | `<last_seen_at>`                    |

> 통합 이슈(iOS+Android)인 경우 행을 추가해 앱별로 분리 표기. Crashlytics 메타가 이슈 본문에 없으면 해당 칸을 "해당 없음"으로 표기.

## Crashlytics 콘솔 링크

- <firebase_console_url>

> 통합 이슈인 경우 앱별로 한 줄씩 추가.

## 변경 요약

**산출물 라벨** (SKILL.md Step 5-2 정의 — 검토자가 한 줄로 원인·검증 방식을 파악하기 위함):

```
[cause: <cause_label>] [verify: <verification_summary>] entry: <entry_point>
```

- 예시 (언어 무관, 본인 프로젝트 경로로 치환):
  - `[cause: null_dereference] [verify: test_added] entry: src/services/payment.ts:128:processRefund`
  - `[cause: race_condition] [verify: manual_only] entry: internal/worker/dispatcher.go:67:Run`
  - `[cause: unhandled_exception] [verify: test_added] entry: lib/feature/foo/foo_view.dart:42:_handleTap`

라벨 다음 줄부터 자유 서술:

<원인 1~2문장 + 수정 방향 1~2문장. 코드 한 줄 짜리라도 _왜_ 그렇게 고쳤는지를 적는다. `cause_label`이 `unknown`이면 사유를 1줄 명시.>

## 변경 파일 목록

`git diff --stat <BASE_BRANCH>...HEAD` 결과를 코드블록으로 (예시 — 본인 프로젝트 경로로 치환):

```
 src/services/payment.ts        | 12 ++++++------
 src/services/payment.test.ts   |  8 ++++++++
 2 files changed, 14 insertions(+), 6 deletions(-)
```

## 테스트 결과

- 추가/수정한 테스트: `<test 경로 목록 또는 "추가 없음(재현 불가)">`
- 실행 결과:
  ```
  <프로젝트의 테스트 명령 출력 요약. 실패가 없는 한 last lines만>
  ```
- 수동 검증: <시나리오 1~3개 또는 "해당 없음">

## 회귀 위험 및 점검 포인트

- 회귀 위험: <낮음/중간/높음 + 한 줄 사유>
- 영향받는 코드 경로: <함수·클래스 경로>
- PR 리뷰어가 추가로 확인하면 좋은 점:
  - <항목 1>
  - <항목 2>
````

## 채우기 가이드

- **변수명 표시**: 사용자가 채울 자리는 `<...>` 또는 `` `<...>` ``로 표기. 실제 PR에서는 모두 치환된 값으로만 남는다.
- **빈 섹션 처리**: 섹션을 생략하지 않는다. 빈 칸은 "해당 없음" 또는 "추가 없음(재현 불가)" 같은 명시적 표현 사용.
- **Closes 키워드**: `Closes #<n>`은 GitHub 자동 닫힘 트리거다. PR 머지 시 이 키워드 덕분에 이슈가 자동 닫힘.
- **변경 파일 목록 형식**: `git diff --stat <BASE_BRANCH>...HEAD`의 raw 출력을 그대로 사용. 가독성을 위해 정렬·요약하지 않는다.
- **events / users 자동 보강**: SKILL.md Step 5-3에서 PR 본문 작성 시 이슈 본문의 `(app_id, crashlytics_issue_id)` 쌍에 대해 `mcp__firebase__crashlytics_get_issue`를 호출해 통계를 채운다. 본문 추출 또는 호출이 실패한 항목만 "해당 없음"으로 둔다.
- **통합 이슈 처리**: 한 GitHub 이슈가 iOS와 Android Crashlytics 양쪽에 매핑된 경우(본문에 `(app_id, crashlytics_issue_id)` 쌍이 2개 이상), "이슈 요약" 표와 "Crashlytics 콘솔 링크" 섹션을 앱별로 행을 늘려 표기.

## 운영 팁

- Crashlytics 콘솔 URL 형식은 `https://console.firebase.google.com/project/<project_id>/crashlytics/app/<platform>:<bundle_id_or_package>/issues/<crashlytics_issue_id>`. 실제 콘솔에서 한 번 열어 보고 형식을 검증한 뒤 템플릿에 박는다.
- PR 제목 형식 권장: `fix(#<issue_number>): <한 줄 요약>`. 이슈 번호가 제목·본문·커밋 메시지 모두에 일관되게 등장하도록 한다.
- `--body-file` 사용 절차는 SKILL.md Step 5-3에 정리되어 있다 — 본 문서에 중복 기재하지 않는다.
