# Module Inference — LLM-based

이슈 제목의 `{module}` 토큰은 **LLM이 직접 추론**해 채우는 짧은 현장 언어 단어다. regex 매핑이나 설정 파일은 사용하지 않는다.

## 추론 입력

각 크래시마다 LLM은 다음을 읽는다:

- `display_name` — Crashlytics가 자동 생성한 요약 (예: `NSRangeException at transactions:42`)
- `error_type` — `FATAL` / `NON_FATAL` / `ANR`
- `stack_trace` — 전체 스택 트레이스 (보통 20~100 프레임)

## 출력 규칙

1. **1~2 단어**. 구(phrase) 금지. 가능하면 단일 명사.
2. **언어는 `config.module.language`로 고정**. 기본 `"ko"` (한국어). `"en"`이면 영어 출력. `"auto"`를 명시적으로 지정한 경우에만 세션 언어에 맞춘다. 재실행마다 한/영이 흔들리지 않아야 제목 dedup과 운영 리포트가 안정적이다.
3. **feature 레벨**. 클래스·메서드명이 아니라 기능 단위를 고른다. `출금`이 `TransactionListView`보다 낫다.
4. **app 코드 프레임이 없으면 `Unknown`**. 스택이 외부 SDK·프레임워크로만 이뤄졌을 때.

## 예시

### Flutter 스택 → 한국어 출력

```
#0  TransactionList.build (package:some_app/feature/withdrawal/ui/list.dart:42)
#1  StatelessElement.build ...
```
→ `{module}` = `출금`

### Android (Kotlin) 스택 → 영어 출력

```
at com.example.app.home.HomeViewModel.fetchBalance(HomeViewModel.kt:15)
```
→ `{module}` = `Home`

### iOS (Swift) 스택 → 한국어 출력

```
0  MyApp  0x... AdsBannerViewController.viewDidLoad () -> () in AdsBannerViewController.swift:28
```
→ `{module}` = `광고`

### 외부 SDK 프레임만 → `Unknown`

```
at android.view.ViewRoot.doFrame(...)
at android.view.Choreographer.doFrame(...)
```
→ `{module}` = `Unknown`

## LLM 판단 가이드

스택에서 모듈명을 짚을 때 LLM이 참고하는 단서(우선순위 순):

1. **앱 자체 코드 경로** — `package:*_app/feature/<name>/...`, `com.example.app.<name>.*`, `<AppName>Core.<Name>Service` 같은 패턴. `<name>`이 곧 모듈 후보.
2. **스크린/ViewController 이름** — `HomeFragment`, `AdsBannerViewController` → `Home`, `광고`.
3. **예외 메시지** — `FirebaseAuthException`, `AdMob SDK ...` 등 도메인 키워드가 보이면 그 도메인.
4. **그 외** — 판단이 서지 않으면 `Unknown`. 추측으로 잘못된 라벨을 다는 것보다 `Unknown`이 낫다.

## 왜 regex가 아닌 LLM인가

사용자가 정규식으로 모듈명을 매핑하는 접근은 실사용에서 취약하다:

- 새 feature가 추가될 때마다 규칙을 갱신해야 한다 — 유지보수 부담.
- 난독화·minify된 빌드에서는 regex가 조용히 실패한다.
- LLM은 스택 전체를 컨텍스트로 받으므로, 인간이 유지하는 패턴 목록보다 더 유연한 판단이 가능.

**결론**: 모듈 추론은 설정의 책임이 아니라 LLM의 책임으로 정의한다.

## 비결정성에 대하여

같은 크래시에 대해 실행마다 모듈명이 미세하게 바뀔 수 있다(예: `결제` vs `결제 플로우`). 이는 다음과 같은 이유로 치명적이지 않다:

- 이슈 dedup은 **본문의 HTML 메타 주석 `<!-- crashlytics_issue_id: <id> -->`**으로 수행된다. 제목 문자열에 의존하지 않는다. 상세: `filter-rules.md`, `issue-template.md`.
- 제목은 사람이 읽는 라벨이지 primary key가 아니다.
- 특정 모듈명이 항상 고정돼야 한다면, 이슈 생성 후 GitHub에서 수동으로 제목을 편집할 수 있다.

**언어 변동만큼은 예외**다. 같은 크래시가 한국어 세션에서는 `광고`, 영어 세션에서는 `Ads`로 나오면 운영 리포트의 모듈 집계가 두 갈래로 쪼개진다. 이 비결정성은 `config.module.language`로 제거되므로 기본값(`"ko"`)을 유지하기를 권장.

조직 차원에서 더 강한 일관성이 필요하다면 이 스킬을 포크해 모듈명을 고정 사전으로 매핑하는 layer를 얹으면 된다.
