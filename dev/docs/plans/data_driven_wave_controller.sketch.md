# Data-Driven Wave Controller

## Goal

Replace the fixed short wave sequence with data-driven run wave definitions that support four normal waves, a wave 5 boss, enemy pool selection, and future enemy count modifiers from reward cards.

## Requirements

1. The run uses wave definitions instead of hard-coded two-wave-plus-boss transitions.
2. Waves 1 through 4 spawn normal enemies using base counts of 5, 6, 7, and 8.
3. Wave 5 spawns the boss and completes the run when the boss dies.
4. Future enemy count modifiers increase later normal waves after the modifier is gained.
5. Enemy types unlocked or selected by earlier run state remain available in later normal waves.
6. Normal waves spawn their enemies at wave start rather than mid-wave.

## Design

The wave controller owns run-wave progression and wave-local spawn planning, not player stats, terrain truth, or reward UI. Its durable run state for this phase is the current wave index, accumulated enemy count modifier, and available normal enemy pool.

Normal wave count is:

```txt
normal_wave_count = base_count_for_wave + future_enemy_count_modifier
```

Boss wave count remains one boss in this phase. The pressure modifier is meant to raise normal-wave density, not duplicate the boss.

## Sketch (non-normative)

Suggested wave data shape:

```gdscript
const WAVE_DEFINITIONS := [
    { "index": 1, "kind": "normal", "base_count": 5 },
    { "index": 2, "kind": "normal", "base_count": 6 },
    { "index": 3, "kind": "normal", "base_count": 7 },
    { "index": 4, "kind": "normal", "base_count": 8 },
    { "index": 5, "kind": "boss", "boss_id": "first_boss" },
]
```

Suggested run modifier:

```gdscript
var _future_enemy_count_modifier := 0

func add_future_enemy_count(amount: int) -> void:
    _future_enemy_count_modifier += amount
```

Suggested spawn count:

```gdscript
func _get_spawn_count(wave: Dictionary) -> int:
    if wave["kind"] == "boss":
        return 1
    return int(wave["base_count"]) + _future_enemy_count_modifier
```

Migration steps:

1. Replace enum-driven next-wave branching with a wave index and wave definition lookup.
2. Move normal enemy base counts into data owned by the wave flow.
3. Add future enemy count modifier state and a public effect entry point for reward application.
4. Keep the current enemy scene pool as the initial available enemy pool.
5. Keep boss spawning as a boss wave definition.
6. Preserve wave-complete behavior: normal wave clear opens reward choice, boss clear completes the run.

## Non-Goals

1. Do not add mid-wave spawning.
2. Do not data-drive every enemy property in this slice.
3. Do not apply future enemy count modifiers to the boss count.
4. Do not implement a full enemy unlock economy.

## Acceptance Criteria

1. The run progresses through four normal waves and then a wave 5 boss.
2. Normal wave enemy counts use base counts plus accumulated future enemy modifiers.
3. The boss wave spawns one boss and completes the run when cleared.
4. Enemy pool state can be extended by rewards without rewriting the wave progression code.
