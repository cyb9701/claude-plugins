# Severity Auto-Mapping Rules

Each issue is auto-labeled with one severity level. The label is appended to the GitHub issue as `severity:{level}`.

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

Evaluate levels from highest to lowest severity. The **first matching level** wins.

Order of evaluation: `blocker` → `critical` → `major` → (any custom levels you add, in insertion order).

### Per-Level Match Rule

A level matches when **all** of its specified conditions are true (AND-only — `match_mode`는 존재하지 않는다):

| Key                  | Condition                             |
| -------------------- | ------------------------------------- |
| `impacted_users_min` | `issue.impacted_users_count >= value` |
| `event_count_min`    | `issue.event_count >= value`          |
| `error_types`        | `issue.error_type in value`           |

Omitted keys are treated as "no condition" (trivially true). An empty `{}` block always matches — use this as the fallback catch-all.

**OR 매칭이 필요하다면** 한 level을 두 개로 분리한다. 예: "impacted_users ≥ 1000 이거나 event_count ≥ 10000 이면 blocker" → 두 blocker 블록으로 나눠 첫 번째는 `impacted_users_min`만, 두 번째는 `event_count_min`만 지정하고, resolution 알고리즘이 "first matching wins"이므로 먼저 매칭되는 쪽이 선택된다(단, 객체 키 중복은 안 되므로 `blocker_users`/`blocker_events`처럼 이름을 나눠야 한다 — label은 `severity:blocker_users`가 되므로 레포에도 그 라벨을 등록).

### Pseudocode

```
def resolve_severity(issue, thresholds):
    for level_name, rule in thresholds.items():
        if "impacted_users_min" in rule and issue.impacted_users_count < rule["impacted_users_min"]:
            continue
        if "event_count_min" in rule and issue.event_count < rule["event_count_min"]:
            continue
        if "error_types" in rule and issue.error_type not in rule["error_types"]:
            continue
        return level_name
    return "unlabeled"  # only if no level matches (shouldn't happen if `major` is `{}`)
```

## Examples

Using the default thresholds:

| Issue | impacted_users | event_count | error_type | → Severity                               |
| ----- | -------------- | ----------- | ---------- | ---------------------------------------- |
| A     | 1500           | 20000       | FATAL      | blocker                                  |
| B     | 500            | 5000        | FATAL      | critical                                 |
| C     | 50             | 200         | FATAL      | major                                    |
| D     | 2000           | 500         | NON_FATAL  | critical (event_count below blocker min) |
| E     | 10             | 10          | NON_FATAL  | major                                    |

Note on row D: `blocker` requires both `impacted_users_min=1000` AND `event_count_min=10000` AND `error_types=["FATAL"]`. Event count (500) fails blocker. Drop to `critical`: `impacted_users>=100` ✔, `event_count>=1000`? 500 fails. Drop to `major`: `{}` always matches → `major`. **Correction**: D's severity is `major`, not `critical`.

(This kind of subtlety is why you should test with `--dry-run` after tuning.)

## Customization

Override in your `config.json`:

```json
{
  "severity_thresholds": {
    "blocker": {
      "impacted_users_min": 500,
      "event_count_min": 5000,
      "error_types": ["FATAL"]
    },
    "critical": {
      "impacted_users_min": 50,
      "event_count_min": 500,
      "error_types": ["FATAL", "ANR"]
    },
    "major": {}
  }
}
```

### Adding Custom Levels

You can add arbitrary level names. JSON object insertion order is preserved (by convention in most runtimes):

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

Resulting labels: `severity:blocker`, `severity:critical`, `severity:major`, `severity:minor`.

**Make sure the matching labels exist on your GitHub repo** (Settings → Labels), otherwise `gh issue create` returns 422.

## When to Tune

- **Too many blocker labels**: raise thresholds. A blocker label should feel like a pager alert, not a daily occurrence.
- **Almost nothing hits critical**: lower thresholds or relax error_types.
- **Wrong prioritization**: reconsider whether impacted users or event count matters more for your product. For high-DAU apps, events dominate; for B2B apps with few users, impacted users matter more.
