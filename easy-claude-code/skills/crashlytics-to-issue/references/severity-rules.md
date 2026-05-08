# Severity Auto-Mapping Rules

각 이슈에 자동으로 한 개의 severity 라벨이 부여된다 (`severity:{level}`).

## Default Thresholds

```json
"severity_thresholds": {
  "blocker": {
    "impacted_users_min": 1000,
    "event_count_min": 10000,
    "error_types": ["FATAL"]
  },
  "critical": {
    "impacted_users_min": 100,
    "event_count_min": 1000,
    "error_types": ["FATAL", "ANR"]
  },
  "major": {}
}
```

## Resolution Algorithm

`blocker` → `critical` → `major` 순으로 평가하며, **첫 매칭 레벨이 채택**된다.

### Per-Level Match Rule

레벨의 **모든** 조건이 참이어야 매칭(AND-only):

| Key                  | Condition                             |
| -------------------- | ------------------------------------- |
| `impacted_users_min` | `issue.impacted_users_count >= value` |
| `event_count_min`    | `issue.event_count >= value`          |
| `error_types`        | `issue.error_type in value`           |

생략된 키는 "조건 없음"으로 취급하며 빈 `{}`는 항상 매칭(catch-all).

### Pseudocode

```python
def resolve_severity(issue, thresholds):
    for level_name, rule in thresholds.items():
        if "impacted_users_min" in rule and issue.impacted_users_count < rule["impacted_users_min"]:
            continue
        if "event_count_min" in rule and issue.event_count < rule["event_count_min"]:
            continue
        if "error_types" in rule and issue.error_type not in rule["error_types"]:
            continue
        return level_name
    return "unlabeled"  # `major: {}`가 있으면 발생하지 않음
```

## Examples

| 이슈 | impacted_users | event_count | error_type | → Severity                                        |
| ---- | -------------- | ----------- | ---------- | ------------------------------------------------- |
| A    | 1500           | 20000       | FATAL      | blocker                                           |
| B    | 500            | 5000        | FATAL      | critical                                          |
| C    | 50             | 200         | FATAL      | major                                             |
| D    | 2000           | 500         | NON_FATAL  | major (event_count·error_type 모두 critical 미달) |
| E    | 10             | 10          | NON_FATAL  | major                                             |

D처럼 한 조건이 미달이면 다음 레벨로 떨어진다. 튜닝 후엔 `--dry-run`으로 확인할 것.

## Customization

사용자 인스턴스 (`${CLAUDE_PLUGIN_DATA}/crashlytics-to-issue/projects/<PROJECT_KEY>/config.json`)에서 override한다. 번들 템플릿(`${CLAUDE_SKILL_DIR}/config.json`)은 플러그인 업데이트 시 교체되므로 편집 대상이 아니다.

커스텀 레벨을 추가할 수도 있다(예: `severity:minor`). 단 **추가한 라벨은 GitHub 레포에 사전 등록**되어야 422를 피한다.

```json
{
  "severity_thresholds": {
    "blocker": { "impacted_users_min": 1000, "error_types": ["FATAL"] },
    "critical": { "impacted_users_min": 100, "error_types": ["FATAL", "ANR"] },
    "major": { "impacted_users_min": 10 },
    "minor": {}
  }
}
```

## When to Tune

- **Blocker가 너무 많이 붙음** → 임계치를 올려라. blocker는 페이저 알람 수준이어야 한다.
- **Critical에 거의 안 걸림** → 임계치를 낮추거나 `error_types`를 완화.
- **High-DAU 앱**은 event_count가, **B2B 앱**은 impacted_users가 더 의미 있다.
