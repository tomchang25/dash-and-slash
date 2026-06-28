# Enemy State Consolidation

## Goal

Remove boilerplate enemy state wrappers after enemies expose a common data-backed attack lifecycle. This keeps the state machine as behavior delegation while reducing duplicated state IDs and duplicate telegraph or attack state scripts.

## Requirements

1. Shared state IDs replace per-enemy state enums where behavior is equivalent.
2. Pure wrapper states are removed only when their behavior is identical, because scene rewiring is riskier than data extraction.
3. Generic telegraph and attack states use the shared attack lifecycle API introduced by earlier phases.
4. Puff-specific state behavior remains separate unless it gains a second clear user.
5. Enemy entities do not become state-dispatch controllers, because state behavior should remain inside state scripts.

## Design

State consolidation starts with states that only differ by ID. Once shared IDs are in place, generic telegraph and attack states can use a common enemy API for durations, attack start/end, and optional attack motion. Behavior-heavy states that are unique to one enemy stay separate until reuse is real.

## Sketch (non-normative)

Proposed shared state ID direction:

```gdscript
enum EnemyStateId {
    NULL = -1,
    IDLE = 0,
    REPOSITION = 1,
    FACE_TARGET = 2,
    TELEGRAPH = 3,
    ATTACK = 4,
    RECOVERY = 5,
    STAGGERED = 6,
    DEAD = 7,
    MODE_CHANGE = 8,
    PUFF = 9,
    CHARGE_ATTACK = 10,
}
```

Proposed generic state set:

```text
EnemyIdleState
EnemyRepositionState
EnemyFaceOnceState
EnemyTelegraphState
EnemyAttackState
EnemyRecoveryState
EnemyStaggeredState
EnemyDeadState
EnemyChargeAttackState
PuffEnemyPuffState or EnemyPuffState
ModeEnemyModeChangeState
```

Proposed common attack-facing API for generic telegraph and attack states:

```gdscript
func begin_attack_telegraph() -> bool:
    return false

func show_attack_charge() -> void:
    pass

func begin_attack() -> void:
    pass

func end_attack() -> void:
    pass

func get_warning_duration() -> float:
    return 0.6

func get_charge_duration() -> float:
    return 0.2

func get_attack_duration() -> float:
    return 0.2

func update_attack_motion(_delta: float) -> bool:
    return false
```

Suggested migration steps:

1. Add shared state IDs while keeping existing behavior.
2. Update enemy state-id getters to return shared IDs.
3. Replace pure wrapper states for idle, reposition, face, recovery, staggered, and dead behavior.
4. Add a generic telegraph state after all participating enemies expose the shared telegraph API.
5. Add a generic attack state after all participating enemies expose the shared attack API.
6. Keep puff and mode-change states separate unless they become reusable.

## Non-Goals

1. Do not consolidate states before the shared attack API exists.
2. Do not move state behavior into enemy physics processing.
3. Do not remove behavior-heavy custom states merely to reduce file count.
4. Do not require puff and mode-change states to become generic in this phase.

## Acceptance Criteria

1. Shared state IDs replace duplicate per-enemy state enums where behavior is equivalent.
2. Pure wrapper state scripts are removed or reduced.
3. Generic telegraph and attack states can drive enemies that expose the shared attack lifecycle API.
4. Unique puff and mode-change behavior remains correct and can stay custom.
5. The state machine remains a behavior-delegation system rather than a label holder.
