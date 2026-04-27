# 사이클 종료 보고서 템플릿

스킬의 모든 사이클이 종료되고 PR 일괄 검토·머지까지 끝난 뒤, 사용자에게 한 번에 보여주는 마무리 보고서. 헤더 텍스트·표 컬럼은 고정.

## 템플릿

```markdown
# crashlytics-issue-to-fix 사이클 결과

## 요약

- 베이스 브런치: `<BASE_BRANCH>`
- 처리한 이슈 수: <total>
- 결과 분포:
  - merged: <merged>
  - conflict: <conflict>
  - user_rejected: <user_rejected>
  - failed: <failed>
  - not_planned: <not_planned> (Step 4에서 미선택)
- 실행 시각: <ISO 8601 with timezone>

## 이슈별 결과

| #     | 제목      | 결과          | PR 링크         | Crashlytics 상태 | 비고                                        |
| ----- | --------- | ------------- | --------------- | ---------------- | ------------------------------------------- |
| `<n>` | `<title>` | merged        | [#<pr>](pr_url) | CLOSED           | -                                           |
| `<n>` | `<title>` | conflict      | [#<pr>](pr_url) | OPEN (수동 처리) | 머지 시 충돌. PR 수동 rebase 필요           |
| `<n>` | `<title>` | user_rejected | [#<pr>](pr_url) | OPEN (수동 처리) | Step 6-2에서 머지 대상 미선택. PR OPEN 유지 |
| `<n>` | `<title>` | failed        | -               | OPEN (수동 처리) | <Step 5 사이클 중 실패 사유 1줄>            |
| `<n>` | `<title>` | not_planned   | -               | CLOSED           | Step 4에서 미선택                           |

## 결과 라벨 정의

- `merged`: PR이 머지되었고, GitHub 이슈와 Crashlytics가 모두 종결됨.
- `conflict`: Step 6-4 머지 시도에서 `MERGE_CONFLICT`로 거절. 사용자가 "건너뛰기" 선택. PR·이슈·Crashlytics OPEN 유지. 워크트리·브런치 보존.
- `user_rejected`: Step 6-2에서 사용자가 머지 대상에서 제외. PR·이슈·Crashlytics OPEN 유지. 워크트리·브런치 보존.
- `failed`: Step 5 사이클 도중 실패(예: pre-commit hook 실패, 수정 코드 작성 불가)로 PR 생성에 도달하지 못함. 비고 컬럼에 사유 명시. 워크트리·브런치는 보존(사용자 직접 검토용).
- `not_planned`: Step 4에서 사용자가 미선택. GitHub은 not-planned로 닫고 Crashlytics도 동기 종결됨(PR 자체가 없음).

## 잔여 작업

- **보존된 워크트리·브런치** (사용자 직접 처리 필요):
  | # | PR | 브런치 | 워크트리 경로 |
  | --- | --- | --- | --- |
  | `<n>` | [#<pr>](pr_url) 또는 - | `fix/issue-<n>` | `<repo-root>/.worktrees/fix-issue-<n>/` |

  > `conflict`·`user_rejected`·`failed` 결과 이슈만 나열. `merged`는 워크트리·브런치가 정리됐다.

- **수동 처리 필요한 Crashlytics 이슈**: 본문에서 issue id 추출이 실패해 동기 종결이 안 된 항목이 있다면 여기에 명시.
  - #<n> — Crashlytics ID 추출 실패. Firebase 콘솔에서 직접 CLOSED 처리 필요.

## 다음 액션 제안

- `conflict` 결과인 경우: 보존된 워크트리에서 `git fetch origin <BASE_BRANCH> && git rebase origin/<BASE_BRANCH>` 후 `git push --force-with-lease`. 그 다음 GitHub UI 또는 `gh pr merge <pr> --<merge_method>`로 직접 머지.
- `user_rejected` 결과인 경우: PR을 직접 검토하고, 코멘트 반영 후 커밋을 추가하거나 `gh pr merge` / `gh pr close`로 마무리.
- `failed` 결과인 경우: 비고 사유를 보고 재시도 여부 결정. 단순 일시적 실패면 `/crashlytics-issue-to-fix <번호>`로 단건 재실행. 보존된 워크트리에서 직접 작업 가능.
- 워크트리·브런치 일괄 정리: `git worktree list`로 잔존 항목 확인 후 본 스킬을 다시 호출하면 Step 6-6에서 일괄 정리 옵션 제공.
```

## 채우기 가이드

- **표 컬럼 6개 고정**: `#`, `제목`, `결과`, `PR 링크`, `Crashlytics 상태`, `비고`. 비어 있어도 컬럼은 유지.
- **PR 링크**: 이슈별로 다른 PR을 가리킨다. `failed`·`not_planned`는 PR 자체가 없으므로 `-`로 표기.
- **결과 라벨 정의 섹션**은 보고서마다 포함해 사용자가 라벨을 즉시 해석할 수 있도록 한다.
- **보존된 워크트리 표**는 본 보고서 작성 _시점에_ 잔존하는 항목만 나열. `merged` 항목은 Step 6-4에서 워크트리가 정리됐으므로 표에 등장하지 않는다.
- **요약의 "결과 분포"**: 카운트가 0인 라벨도 명시(예: `conflict: 0`)해 한 눈에 분포를 파악할 수 있게 한다.
