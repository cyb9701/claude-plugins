# Module Inference — LLM-based

이슈 제목의 `{module}` 토큰은 **LLM이 직접 추론**해 채우는 짧은 현장 언어 단어다. regex 매핑이나 설정 파일은 사용하지 않는다.

## 추론 입력

각 크래시마다 LLM이 읽는 데이터:

- `display_name` — Crashlytics 자동 요약 (예: `NSRangeException at transactions:42`)
- `error_type` — `FATAL` / `NON_FATAL` / `ANR`
- `stack_trace` — 전체 스택 트레이스

## 출력 규칙

1. **1~2 단어**. 가능하면 단일 명사.
2. **언어는 `config.module.language`로 고정** (기본 `"ko"`). 재실행마다 한/영이 흔들리지 않아야 운영 리포트가 안정적이다.
3. **feature 레벨**. 클래스·메서드명이 아니라 기능 단위로 고른다 (`출금` > `TransactionListView`).
4. **app 코드 프레임이 없으면 `Unknown`**. 외부 SDK·프레임워크만 보일 때.

## 예시

### Flutter → 한국어

```
#0  TransactionList.build (package:some_app/feature/withdrawal/ui/list.dart:42)
```

→ `{module}` = `출금`

### Android (Kotlin) → 영어

```
at com.example.app.home.HomeViewModel.fetchBalance(HomeViewModel.kt:15)
```

→ `{module}` = `Home`

### iOS (Swift) → 한국어

```
0  MyApp  0x... AdsBannerViewController.viewDidLoad () in AdsBannerViewController.swift:28
```

→ `{module}` = `광고`

### 외부 SDK만 → `Unknown`

```
at android.view.ViewRoot.doFrame(...)
```

→ `{module}` = `Unknown`

## LLM 판단 가이드

스택에서 모듈명을 짚을 때 참고하는 단서(우선순위 순):

1. **앱 자체 코드 경로** — `package:*_app/feature/<name>/...`, `com.example.app.<name>.*` 같은 패턴. `<name>`이 곧 모듈 후보.
2. **스크린/ViewController 이름** — `HomeFragment` → `Home`, `AdsBannerViewController` → `광고`.
3. **예외 메시지** — `FirebaseAuthException`, `AdMob SDK ...` 등 도메인 키워드.
4. **그 외** — `Unknown`. 추측보다 빈 라벨이 낫다.

## 비결정성

같은 크래시에 대해 실행마다 모듈명이 미세하게 바뀔 수 있다(예: `결제` vs `결제 플로우`). 치명적이지 않은 이유:

- 이슈 dedup은 본문의 `<!-- crashlytics_issue_id: <id> -->` 메타 주석으로 수행 (제목에 의존하지 않음).
- 제목은 사람이 읽는 라벨이지 primary key가 아니다.

언어 변동만 예외다 — `광고` vs `Ads`는 모듈 집계를 두 갈래로 쪼갠다. 이 비결정성은 `config.module.language`로 제거한다.
