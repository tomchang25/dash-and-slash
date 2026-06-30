# Data-Driven Player Stats

## Goal

Create a stable player-stat data path so reward cards can modify numeric player values without hard-coding each buff directly into card or UI code.

## Requirements

1. Player combat stats used by Minor cards are represented through a data-owned stat layer.
2. Runtime stat changes apply to the active player through a clear stat owner rather than through reward-controller fields.
3. The first supported stats include normal attack damage, normal attack cooldown, dash attack damage, dash cooldown, and max health.
4. Stat changes are run-scoped for this phase and do not create permanent progression.
5. Max-health changes define whether current health also changes when the maximum increases, because the health user experience should be deterministic.

## Design

The stat layer separates base player defaults from run modifiers. Minor cards modify run stats, and the player reads or receives the resolved values. The reward system should not know which node field stores a damage number; it should ask the stat owner to apply a named numeric effect.

For first-pass max health, increasing max health should also increase current health by the same amount. This makes a max-health reward immediately useful and avoids making it feel weaker than damage rewards.

## Sketch (non-normative)

Suggested data shape:

```gdscript
@export var normal_attack_damage := 20.0
@export var normal_attack_cooldown := 0.25
@export var dash_attack_damage := 80.0
@export var dash_cooldown := 2.0
@export var max_health := 100.0
```

Suggested data resource shape:

```gdscript
class_name PlayerStatsData

@export var max_health := 100.0
@export var normal_attack_damage := 20.0
@export var normal_attack_cooldown := 0.25
@export var dash_attack_damage := 80.0
@export var dash_cooldown := 2.0
```

Migration steps:

1. Identify the player numeric fields that Minor cards need to affect in the first pass, including normal attack cadence.
2. Add a run-local mutable copy of the base player stat resource.
3. Route player numeric reads through the resolved stat values.
4. Add an effect entry point for reward cards to apply named stat modifiers.
5. Define max-health increase behavior and keep health UI snapshots consistent.

## Non-Goals

1. Do not add permanent progression.
2. Do not build a full RPG stat formula system.
3. Do not implement weapon class attack variants.
4. Do not add save migration work unless the chosen implementation stores stats beyond the current run.

## Acceptance Criteria

1. Minor-card target stats have a single run-scoped owner.
2. Reward effects can apply numeric stat modifiers without direct reward-controller ownership.
3. Player combat behavior reflects modified stat values.
4. Increasing max health also updates current health in the defined way.
