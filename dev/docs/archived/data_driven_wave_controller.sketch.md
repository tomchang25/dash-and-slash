# Data-Driven Wave Controller

## Goal

Replace the fixed short wave sequence with data-driven run wave definitions that support four normal waves, a wave 5 boss with support enemies, enemy pool selection, and future enemy count modifiers from reward profiles.

## Requirements

1. The run uses wave definitions instead of hard-coded two-wave-plus-boss transitions.
2. Waves 1 through 4 spawn normal enemies using base counts of 5, 6, 7, and 8.
3. Wave 5 spawns exactly one boss plus support enemies from wave data and completes the run when the boss dies and remaining support enemies are force-cleared.
4. Future enemy count modifiers increase later normal/support enemy spawns after the modifier is gained without increasing the boss count.
5. Enemy types unlocked or selected by earlier run state remain available in later normal and boss-support spawns.
6. Waves spawn their enemies at wave start rather than mid-wave.

## Design

The wave controller owns run-wave progression and wave-local spawn planning, not player stats, terrain truth, or reward UI. Its durable run state for this phase is the current wave index, accumulated enemy count modifier, and available support enemy pool.

Normal/support enemy count is:

```txt
support_enemy_count = base_count_for_wave + future_enemy_count_modifier
```

Boss count remains one boss in this phase. The pressure modifier is meant to raise normal/support enemy density, not duplicate the boss. Boss death starts boss wave resolution: remaining support enemies are force-cleared, then the run completes.

## Sketch (non-normative)

Suggested wave data shape:

```gdscript
const WAVE_DEFINITIONS := [
    { "index": 1, "kind": "normal", "base_count": 5 },
    { "index": 2, "kind": "normal", "base_count": 6 },
    { "index": 3, "kind": "normal", "base_count": 7 },
    { "index": 4, "kind": "normal", "base_count": 8 },
    { "index": 5, "kind": "boss", "boss_id": "first_boss", "support_base_count": 8 },
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
func _get_support_spawn_count(wave: Dictionary) -> int:
    if wave["kind"] == "boss":
        return int(wave.get("support_base_count", 0)) + _future_enemy_count_modifier
    return int(wave["base_count"]) + _future_enemy_count_modifier
```

Suggested boss spawn count:

```gdscript
func _get_boss_spawn_count(wave: Dictionary) -> int:
    return 1 if wave["kind"] == "boss" else 0
```

Migration steps:

1. Replace enum-driven next-wave branching with a wave index and wave definition lookup.
2. Move normal and boss-support enemy base counts into data owned by the wave flow.
3. Add future enemy count modifier state and a public effect entry point for reward application.
4. Keep the current enemy scene pool as the initial available support enemy pool.
5. Keep boss spawning as a boss wave definition with a separate fixed boss count.
6. Preserve wave-complete behavior: normal wave clear opens reward choice, boss death force-clears remaining support enemies and completes the run.

## Non-Goals

1. Do not add mid-wave spawning.
2. Do not data-drive every enemy property in this slice.
3. Do not apply future enemy count modifiers to the boss count.
4. Do not implement a full enemy unlock economy.

## Acceptance Criteria

1. The run progresses through four normal waves and then a wave 5 boss.
2. Normal and boss-support enemy counts use base counts plus accumulated future enemy modifiers.
3. The boss wave spawns one boss plus support enemies and completes the run when the boss dies after support enemies are force-cleared.
4. Enemy pool state can be extended by rewards without rewriting the wave progression code.
