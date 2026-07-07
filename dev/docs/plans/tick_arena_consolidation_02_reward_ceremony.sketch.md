# Tick Arena Consolidation 02: Reward Ceremony And Legacy Seam

## Goal

Collapse the reward pipeline's class ceremony: effects whose entire behavior is "record a signed total on one channel" become instances of one parameterized definition, the one-loop applier middleman disappears, and the legacy real-time-player seam leaves the reward context now that the legacy arena no longer exists.

## Requirements

1. One parameterized channel-recording definition replaces the per-channel subclasses, because ten classes that differ only by a channel constant are data pretending to be types.
2. The reward context carries no legacy player reference, and the attack-range effect leaves the pool — it is filtered out of every tick-arena offer today, so no offered content changes.
3. Effects with genuinely distinct behavior keep their subclasses: Major registration, the Smash payload override, and the trigger-activating Majors.
4. The applier middleman is removed; the choice controller applies effects directly, since the applier's only job is a three-line loop.
5. The placeholder Major survives only as a test helper, because production code never rolls it.

## Design

The offered pool, descriptions, point values, stack limits, wave gates, and profile assignments all stay byte-identical. The only pool difference is the removal of a definition that `is_applicable()` already excludes from every tick-arena roll.

## Sketch (non-normative)

- New `ChannelRewardEffect extends WaveRewardEffectDefinition` with two extra constructor arguments: `channel: StringName` and `unit_scale: float` (1.0 for flat channels, 0.01 for the percent-authored enemy health/damage pressure channels). Its `apply()` is `context.run_build.record(channel, magnitude * unit_scale * float(stacks))`.
- Replaced by `ChannelRewardEffect` instances in the generator's pool: `FutureEnemyEffect`, `NormalAttackDamageEffect`, `DashAttackDamageEffect`, `DashRangeEffect`, `SpeedEffect`, `MobilityCooldownEffect`, `MaxHealthEffect`, `EnemyHealthPressureEffect`, `EnemyDamagePressureEffect`, `EnemyDefensePressureEffect` — their files delete. `MaxHealthEffect` folds in cleanly because its legacy-player branch dies with the seam.
- Deleted outright: `player_stat_effect.gd`, `attack_range_effect.gd` (and its pool entry), `wave_reward_applier.gd`.
- `WaveRewardContext` drops the `player` field; constructor becomes `(grid, run_build)`. Update the run controller's construction site and every unit-test call site (they pass `null` today except the attack-range tests, which delete with the effect).
- `WaveRewardChoiceController._on_choice_selected` inlines the apply loop: `for effect in choice.effects: effect.apply(_context)`.
- `major_placeholder_effect.gd` moves under `test/` as the shared test double the Major tests already use; adjust its `class_name` or preload style to whatever the test runner expects.
- Pool construction stays in the generator; a follow-up that moves the pool to data files is out of scope here.

## Non-Goals

1. No pool, balance, description, or roll-logic changes (the fallback rework is child 05).
2. No removal of the legacy player entity itself — the cutover closeout owns that.

## Acceptance Criteria

1. Reward offers, descriptions, and applied numbers are identical to today across all three profiles.
2. The effects folder contains only the Major subclasses and the generic channel definition.
3. Lint and unit tests pass with the context's two-owner shape.
