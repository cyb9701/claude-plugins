# 프롬프트 형식 가이드 (Anthropic 공식 문서 기반)

출처: https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/

---

## XML 태그

> "XML tags help Claude parse complex prompts unambiguously, especially when your prompt mixes instructions, context, examples, and variable inputs."

**언제 사용**

- instructions, context, examples, variable inputs이 한 프롬프트에 섞일 때
- 배경·정책(context)과 태스크(instruction)가 혼재할 때

**권장 사항**

- 일관된 태그명 사용
- 계층이 있으면 중첩 사용
- 단순한 프롬프트에는 억지로 넣지 않는다

### 공식 권장 태그명 (자동 도입 시 우선 사용)

자동으로 XML 태그를 도입할 때는 아래 공식 권장 명을 우선 사용한다. 도메인별 명(`<task>`, `<scope>`, `<policy>` 등)은 의미가 명백히 더 잘 전달되는 경우에 한해 허용.

| 의미           | 공식 권장 태그                         | 도메인별 대안 (제한적 허용)    |
| -------------- | -------------------------------------- | ------------------------------ |
| 지시문         | `<instructions>`                       | `<task>`                       |
| 배경·이유·정책 | `<context>`                            | `<background>`, `<policy>`     |
| 입력 데이터    | `<input>`                              | `<text>`, `<source>`, `<code>` |
| 출력 형식      | `<output_format>`                      | `<format>`, `<schema>`         |
| 예시           | `<example>` / `<examples>`             | (대체 권장 안 함)              |
| 다중 문서      | `<documents>` / `<document index="N">` | (대체 권장 안 함)              |
| 범위·제약      | `<scope>`, `<constraints>`             | `<rules>`                      |

다중 문서를 감쌀 때 권장 구조 (공식 가이드):

```xml
<documents>
  <document index="1">
    <source>파일명·출처</source>
    <document_content>
      ...
    </document_content>
  </document>
</documents>
```

---

## 마크다운

> "When writing reports, documents, technical explanations, analyses, or any long-form content, write in clear, flowing prose using complete paragraphs and sentences."
> "DO NOT use ordered lists (1. ...) or unordered lists (\*) unless you're presenting truly discrete items."

**사용 OK**

- 인라인 코드 (`` ` ``)
- 코드 블록 (` ``` `)
- 간단한 제목 (`###` 수준)

**피해야 할 것**

- `**볼드**`, `*이탤릭*`
- 산문으로 쓸 수 있는 내용을 목록으로 쪼개기
- 과도한 번호·글머리 목록

---

## 단순 텍스트

> "Claude responds well to clear, explicit instructions."
> "Golden rule: Show your prompt to a colleague with minimal context. If they'd be confused, Claude will be too."

짧고 의도가 명확한 프롬프트는 XML 없이 평문만으로 충분하다.

---

## `<thinking>` 태그

> "Use `<thinking>` tags inside your few-shot examples to show Claude the reasoning pattern."

- 사용자가 프롬프트에 직접 작성하는 형식이 **아니다**.
- Claude가 Extended Thinking API 모드에서 내부적으로 생성하는 태그.
- 사용자가 쓸 수 있는 경우: Few-shot 예시 안에서 추론 패턴을 보여줄 때만.

---

## 요약

| 형식         | 언제                        | 주의                    |
| ------------ | --------------------------- | ----------------------- |
| XML 태그     | context + instructions 혼재 | 복잡한 프롬프트에만     |
| 마크다운     | 코드 블록, 간단한 제목      | 과도한 목록·볼드 금지   |
| 단순 텍스트  | 짧고 명확한 지시            | 기본값                  |
| `<thinking>` | Few-shot 예시 내부에서만    | 프롬프트 직접 사용 불가 |
