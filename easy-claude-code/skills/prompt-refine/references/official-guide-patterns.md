# Anthropic 공식 가이드 → 자동 변환 매핑

이 문서는 Anthropic 공식 prompt engineering 가이드 (`prompting-best-practices`, `console-prompting-tools`)의 핵심 권장이 본 스킬의 어떤 자동 변환으로 매핑되는지 Before/After 사례로 정리한다. **자동 적용 4·5·7·8번을 판단할 때 참조**한다.

> **핵심 구분**: 권장 중 "정보 표현 방식 개선"에 해당하는 것만 자동 적용한다. "정보 추가"에 해당하는 권장(페르소나, 예시, CoT, 출력 형식 명시)은 1회 확인 프로토콜의 대상이다.

---

## 1. Be clear and direct → 표현 정리 (자동 적용 1번)

> "Claude responds well to clear, explicit instructions."
> "Show your prompt to a colleague with minimal context. If they'd be confused, Claude will be too."

이 권장은 본 스킬의 자동 적용 1번(표현 정리)으로 이미 반영되어 있다. **모호한 동사·장황한 한국어 표현 → 구체적·능동 문장**으로 다듬되, **원문에 없는 수치·기준은 만들지 않는다.**

**Before**

```
이 글을 좀 잘 써줘
```

**After (자동)**

```
이 글의 표현을 더 자연스럽게 다듬는다.
```

→ "잘 써줘"는 동사가 모호하지만, 원문이 가진 정보 안에서 "표현을 다듬는다" 정도까지만 구체화. "분량을 늘려라" "예시를 추가해라" 같은 정보 추가는 하지 않는다.

---

## 2. Add context (the why) → why 컨텍스트 분리 (자동 적용 4번)

> "Providing context or motivation behind your instructions, such as explaining to Claude why such behavior is important, can help Claude better understand your goals."
> "Claude is smart enough to generalize from the explanation."

원문에 **명시적 인과·목적 표현**이 있을 때만 `<context>` 블록으로 분리한다. 추측한 이유는 추가하지 않는다.

**Before**

```
응답에 줄임표(...)는 절대 쓰지 마. 음성 합성기가 발음을 못하니까.
```

**After (자동)**

```
<context>
이 응답은 텍스트-음성 합성기가 읽는다. 줄임표(`...`)는 합성기가 발음하지 못한다.
</context>

<instructions>
응답에 줄임표(`...`)를 쓰지 않는다.
</instructions>
```

→ 원문의 "음성 합성기가 발음 못하니까"라는 인과 표현이 명시적이라 분리. **원문에 없던 "TTS는 SSML을 지원한다" 같은 정보는 추가하지 않는다.**

### 적용 안 하는 사례

**Before**

```
500자 이내로 요약해줘
```

→ 인과·목적 표현이 없다. "왜 500자인가"를 추측해서 컨텍스트로 만들지 않는다. 단순 정리만.

---

## 3. XML tags → 공식 권장 태그명 표준화 (자동 적용 5번)

> "XML tags help Claude parse complex prompts unambiguously, especially when your prompt mixes instructions, context, examples, and variable inputs."

자동으로 XML 태그를 도입할 때는 **공식 권장 태그명을 우선** 사용한다.

| 의미                            | 공식 권장 태그                         | 도메인별 대안 (의미가 명백할 때만) |
| ------------------------------- | -------------------------------------- | ---------------------------------- |
| 지시문                          | `<instructions>`                       | `<task>`                           |
| 배경·이유·정책                  | `<context>`                            | `<background>`, `<policy>`         |
| 입력 데이터                     | `<input>`                              | `<text>`, `<source>`, `<code>`     |
| 출력 형식 (원문 단서 있을 때만) | `<output_format>`                      | `<format>`, `<schema>`             |
| 예시 (원문에 이미 있을 때만)    | `<example>` / `<examples>`             | —                                  |
| 다중 문서                       | `<documents>` / `<document index="N">` | —                                  |
| 범위·제약                       | `<scope>`, `<constraints>`             | `<rules>`                          |

**Before**

```
사용자 가이드 작성해줘. 대상은 초보자이고, 길이는 1페이지, 코드 예시 포함.
```

**After (자동)**

```
초보자 대상 사용자 가이드를 작성한다.

<scope>
- 대상: 초보자
- 길이: 1페이지
- 코드 예시 포함
</scope>
```

→ 원문에 명백한 "범위" 의미가 있어 `<scope>` 사용. 단, 공식명 `<context>` 또는 `<input>`도 등가로 적절하다. 도메인별 명을 강제하지는 않는다.

---

## 4. Long context placement → 데이터 상단 재배치 (자동 적용 8번)

> "Put longform data at the top: place your long documents and inputs near the top of your prompt, above your query, instructions, and examples."
> "Queries at the end can improve response quality by up to 30%."

원문에 큰 데이터 블록이 지시 뒤에 위치할 때 **자동으로 상단으로 옮긴다**. 다중 문서면 `<documents>`로 감싼다.

**Before**

```
다음 텍스트의 핵심 주제 3가지를 뽑아줘:

[5천 단어 분량의 보고서 텍스트…]
```

**After (자동)**

```
<input>
[5천 단어 분량의 보고서 텍스트…]
</input>

위 텍스트의 핵심 주제 3가지를 뽑는다.
```

### 다중 문서 사례

**Before**

```
이 두 보고서를 비교해서 차이점을 정리해.
보고서 A: [3천 단어]
보고서 B: [3천 단어]
```

**After (자동)**

```
<documents>
  <document index="1">
    <source>보고서 A</source>
    <document_content>
[3천 단어]
    </document_content>
  </document>
  <document index="2">
    <source>보고서 B</source>
    <document_content>
[3천 단어]
    </document_content>
  </document>
</documents>

위 두 보고서의 차이점을 정리한다.
```

### 적용 안 하는 사례

**Before**

```
다음 한 줄을 영어로 번역해줘: "안녕하세요"
```

→ 전체가 30줄 이내로 짧다. 가독성을 위해 원순서 유지.

---

## 5. Tell Claude what to do, not what not to do → 부정→긍정 변환 (자동 적용 7번)

> "Instead of: 'Do not use markdown in your response' — Try: 'Your response should be composed of smoothly flowing prose paragraphs.'"

단순 부정형은 의미 동치 긍정형으로 자동 변환. 강한 금지는 강도를 살리는 긍정형(`~만 허용한다`)으로만 변환.

**Before**

```
이모지 쓰지 마. 느낌표 쓰지 마. 반말 쓰지 마.
```

**After (자동)**

```
일반 텍스트, 단정 어조의 존댓말로 작성한다.
```

→ 3개의 부정 지시가 "일반 텍스트 + 단정 + 존댓말"이라는 단일 긍정형으로 압축됨. **의미 손실 없음을 검증한 뒤에만** 압축한다.

### 강한 금지 → 강한 긍정

**Before**

```
외부 라이브러리는 절대 사용하지 마.
```

**After (자동)**

```
표준 라이브러리만 사용한다.
```

→ "절대" 강도를 "만"으로 살림. 두 표현은 의미 동치.

### 적용 안 하는 사례

**Before**

```
개인정보(주민번호, 카드번호)는 출력에 절대 포함하지 않는다 — GDPR/PIPA 위반 가능성.
```

→ 부정 자체가 규제 요구이고, "절대 ~하지 않는다"의 명시적 강조가 안전 의미를 가진다. 원형 유지.

---

## 6. Match prompt style to the desired output → 보수적 적용

> "The formatting style used in your prompt may influence Claude's response style. Removing markdown from your prompt can reduce the volume of markdown in the output."

원문에 "산문으로", "마크다운 없이" 같은 단서가 있으면, 정리본 자체도 과도한 마크다운·목록 사용을 회피한다. 자동 적용은 **보수적**으로만 — 원문에 명백한 단서가 있을 때.

**Before**

```
이 답변은 음성으로 읽힐 거야. 산문으로 자연스럽게 풀어 써줘. 목록 쓰지 마.
```

**After (자동)**

```
이 답변은 음성으로 읽힐 것이다. 산문으로 자연스럽게 작성하며, 목록·번호·글머리 기호를 사용하지 않는다.
```

→ 정리본 자체에서도 목록을 만들지 않고 한 문장으로 표현. **원문이 산문 출력을 요구하면 정리본도 산문에 가깝게**.

---

## 7. More literal instruction following (Opus 4.7) → 범위 표현 보존

> "If you need Claude to apply an instruction broadly, state the scope explicitly (for example, 'Apply this formatting to every section, not just the first one')."
> "Claude Opus 4.7 will not silently generalize an instruction from one item to another."

원문의 범위 표현(`모든 ~`, `각 ~`, `매 ~마다`, `전체 ~`)을 약화시키지 않는다. 자동 적용 1번(표현 정리)에서 압축하는 과정에서 범위가 사라지지 않도록 주의한다.

**Before**

```
모든 함수에 doc string 달아줘. 각 함수가 받는 인자랑 반환값 설명도 같이.
```

**After (자동, 올바름)**

```
**모든** 함수에 docstring을 단다. **각 함수마다** 다음을 포함한다:
- 받는 인자
- 반환값
```

→ "모든", "각 함수마다"가 원형으로 보존됨.

**잘못된 정리 (피해야 할 사례)**

```
함수에 docstring을 단다. 인자와 반환값을 설명한다.
```

→ "모든"·"각"이 사라지면 "일부에만 달면 되는가?"의 모호성이 생긴다. Opus 4.7은 이런 표현을 literal하게 따른다.

---

## 8. 정보 추가형 권장은 자동 적용하지 않는다 (1회 확인만)

다음 공식 권장은 **정보 추가**에 해당하므로, 본 스킬은 자동 반영하지 않는다. 신호가 명확할 때 1회 확인 프로토콜로만 묻는다.

| 공식 권장                                                       | 본 스킬 처리         |
| --------------------------------------------------------------- | -------------------- |
| **Give Claude a role** ("You are a senior engineer...")         | 1회 확인 (페르소나)  |
| **Use examples (few-shot)** ("3-5 examples improve accuracy")   | 1회 확인 (예시)      |
| **Chain-of-thought** ("Think step by step before answering")    | 1회 확인 (CoT)       |
| **Specify output format** ("Output as JSON with these keys...") | 1회 확인 (출력 형식) |

**이유**: 이들은 결과 품질을 향상시킬 수 있지만, 원저자가 의도하지 않은 페르소나·예시·단계가 들어가면 의미가 변형된다. Anthropic Console의 prompt improver는 이런 추가를 자동으로 하는 별개의 도구이며, 본 스킬은 그것을 의도적으로 채택하지 않는다.

---

## 정리: 자동 변환 결정 흐름

```
원문 분석
  │
  ├─ 모호성 6종(A 목록) 또는 보조 요소 신호(B 목록) 감지?
  │   ├─ Yes → AskUserQuestion 1회 호출
  │   └─ No  → 자동 변환 진행
  │
  └─ 자동 적용 1~8번 적용
      ├─ 1. 표현 정리 (모호한 동사 → 구체)
      ├─ 2. 모순·중복 제거
      ├─ 3. 무의미 수식어 제거
      ├─ 4. 정보 계층 정리 + why 컨텍스트 분리 (인과 표현 명시 시)
      ├─ 5. 자연스러운 구조 분리 (XML 공식명 우선, 마크다운 절제)
      ├─ 6. 문장 정리 (수동→능동, 액션 분리)
      ├─ 7. 부정 → 긍정 동치 변환 (의미 손실 0)
      └─ 8. 긴 데이터 상단 재배치 (지시는 하단)
      │
      └─ Step 3 검증 (의도 보존 + 정보 추가 0 + 공식 가이드 정합성)
```
