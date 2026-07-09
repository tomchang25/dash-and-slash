# Tick Arena Consolidation 04: Combat Contracts

Parent Plan: `tick_arena_structure_consolidation.md`

## Goal

Give production tick combat one hit-angle vocabulary and typed cross-module combat contracts, so player verbs and hit outcomes fail through named fields and enums instead of string-keyed dictionaries with silent defaults. This is a behavior-preserving structural cleanup: hit math, feedback text, preview labels, Major trigger effects, and legacy physics hit behavior stay the same.

## Summary

Production tick combat currently has three avoidable contract risks: `TickCombatRules.HitAngle` duplicates `DirectionResolver.HitAngle`, `TickHitResolver.HitKind` exists only to route three branches to the same guard-damage rule, and the hit outcome dictionary carries ten keys through resolver, enemy, action, preview, and tests. This change removes the duplicate angle vocabulary and dead hit-kind chain, then replaces the player input verb and hit outcome dictionaries with tiny typed value objects.

The implementation should stay deliberately small. Add `TickVerb` for the input seam and `TickHitOutcome` for the resolver seam; do not add a typed target snapshot, do not type preview/display dictionaries, and do not type planner dictionaries. The target snapshot remains a resolver input adapter because it is a single internal seam, while the outcome crosses the real module boundary and is consumed by multiple systems.

The production tick path stops carrying `is_dash` once `HitKind` is deleted: Dash and Smash still pass their explicit Major trigger booleans, but guard damage is angle-based and no longer branches by payload. The legacy physics path remains separate: hurtbox hits still derive guard damage from `Hitbox.GuardDamageProfile`, call the legacy adapter with a precomputed world-space angle and guard damage, and receive the same typed outcome shape back.

The archived prototype folder is explicitly out of scope. It is self-contained and scheduled for a future deletion sweep; this spec only changes the live tick arena and its production enemy bridge.

## Relational Context

- `TickInput` emits verbs and `TickActionController` consumes them directly through the existing scene-root signal connection; after this change the payload is a `TickVerb`, not a dictionary, and `TickActionController` matches `TickVerb.kind` instead of a string.
- `TickVerb` owns only the input command contract: `kind`, `dir`, `mobility`, and `repeat`. It must not grow action legality, cooldown, or world-advance state; those remain owned by `TickActionController`.
- `DirectionResolver.HitAngle` becomes the only production hit-angle enum. `TickCombatRules` consumes and renders that enum, including `NONE` in `angle_name()` for empty outcomes, but no longer declares its own angle enum.
- `TickHitResolver` owns pure hit outcome math. It still receives target state as the current snapshot dictionary, but it returns `TickHitOutcome` and exposes `FeedbackKind` / `MajorTrigger` enums instead of `StringName` constants.
- `TickActionController` remains the only writer of player action state and committed enemy hit effects; it passes origin, damage, and explicit mobility Major trigger booleans to `GridEnemy.take_hit()`, then consumes `TickHitOutcome` fields for messages, Major VFX/SFX, and mobility refund checks.
- `TickPreviewController` remains read-only; it calls `GridEnemy.predict_hit()` and converts the typed outcome into the existing `{cell, label, tier}` preview dictionary consumed by `TickGridView`.
- `GridEnemy.predict_hit()` and `GridEnemy.take_hit()` are the production tick enemy bridge. They return the typed outcome; `take_hit()` alone mutates health/guard and plays feedback, while `predict_hit()` stays pure.
- The legacy physics path remains `Hitbox` / `Hurtbox` / `_on_hit_received()` / `EnemyHitResolver.resolve_outcome()`. It still uses `Hitbox.GuardDamageProfile` to compute legacy guard damage before calling the shared precomputed resolver path; it must not be rewired through tick `take_hit()` or tick payload flags.
- `TickHitResolver.resolve_precomputed()` stays for the legacy adapter and tests that already precompute angle and guard damage. `resolve_hit()` is the production tick-grid entry and no longer accepts hit kind.
- `TickGridView` preview dictionaries, danger dictionaries, `TickActionPlanner` plan dictionaries, and the archived prototype combat scene are outside this blast radius.

## Scope

### Included

- Replace production tick input verb dictionaries with a small typed `TickVerb`.
- Replace production and legacy shared hit outcome dictionaries with a small typed `TickHitOutcome`.
- Collapse the duplicate angle enum into `DirectionResolver.HitAngle`.
- Delete `TickHitResolver.HitKind` and the dead tick-path `is_dash` pass-through.
- Update focused unit tests that asserted the old dictionary contracts.
- Delete dead production stagger multiplier constants if they remain unreferenced outside the archived prototype copy.

### Excluded

- No `TickHitTargetSnapshot` class or typed resolver snapshot.
- No typing of view-facing preview, outcome badge, danger, or planner payload dictionaries.
- No prototype-folder cleanup or prototype contract rewrite.
- No combat number, feedback text, preview label, Major trigger, SFX, VFX, or enemy behavior changes.

## Files to Change

| File                                                       | Change Size | Purpose                                                                                                              |
| ---------------------------------------------------------- | ----------- | -------------------------------------------------------------------------------------------------------------------- |
| `game/tick_arena/player/tick_verb.gd`                      | Small       | New leaf value object for input verb kind and payload fields.                                                        |
| `game/tick_arena/player/tick_input.gd`                     | Medium      | Emit `TickVerb` instances instead of verb dictionaries while preserving polling and repeat cadence.                  |
| `game/tick_arena/combat/tick_hit_outcome.gd`               | Medium      | New leaf value object for hit result fields plus feedback and Major trigger enums.                                   |
| `game/tick_arena/combat/tick_hit_resolver.gd`              | Large       | Return typed outcomes, delete `HitKind`, collapse guard-damage routing, and remove angle adapter functions.          |
| `game/tick_arena/combat/tick_combat_rules.gd`              | Medium      | Use `DirectionResolver.HitAngle` directly and delete duplicate angle/dead production constants.                      |
| `game/tick_arena/combat/tick_action_controller.gd`         | Large       | Consume `TickVerb` and `TickHitOutcome`, remove silent outcome defaults, and stop passing dead tick `is_dash` flags. |
| `game/tick_arena/combat/tick_preview_controller.gd`        | Medium      | Consume typed outcomes while preserving existing preview dictionary output.                                          |
| `game/entities/enemies/grid_enemy.gd`                      | Large       | Return typed outcomes from tick prediction/commit paths and keep legacy physics resolution separate.                 |
| `game/entities/enemies/enemy_hit_resolver.gd`              | Small       | Keep the legacy adapter but return the typed outcome from the shared precomputed resolver.                           |
| `test/unit/test_tick_action_controller_verbs.gd`           | Small       | Build typed verbs in direct controller tests.                                                                        |
| `test/unit/test_tick_hit_resolver_dash_triggers.gd`        | Medium      | Assert typed outcome fields/enums and remove `HitKind` call arguments.                                               |
| `test/unit/test_tick_hit_resolver_mobility_free_action.gd` | Medium      | Use typed outcome arrays and field access for refund-condition tests.                                                |

## Execution Outline

1. Add the two leaf value classes first: `TickVerb` with input kind/payload fields and `TickHitOutcome` with current outcome fields, `FeedbackKind`, `MajorTrigger`, and an empty/default constructor path.
2. Convert the verb seam: update `TickInput` factories and signal type, then update `TickActionController.handle_verb()` and its verb tests to consume `TickVerb.kind`, `mobility`, `repeat`, and `dir`.
3. Convert the angle rules: delete `TickCombatRules.HitAngle`, switch `resolve_angle()`, `guard_damage_for()`, and `hp_bypass_for()` to `DirectionResolver.HitAngle`, keep `angle_name()` handling `NONE`, and delete the unreferenced production stagger multiplier constants if search still shows no live use.
4. Convert the resolver: make `empty_outcome()`, `resolve_hit()`, `resolve_precomputed()`, `_resolve_execution_kill()`, and the refund helpers use `TickHitOutcome`; delete `HitKind`, `_guard_damage_for(hit_kind, ...)`, `_to_direction_angle()`, and `_to_tick_angle()`.
5. Convert the enemy bridge: update `GridEnemy.predict_hit()` / `take_hit()` / `_resolve_tick_hit_outcome()` to remove `is_dash`, return `TickHitOutcome`, and access fields directly; update `_resolve_hit_outcome()` and `EnemyHitResolver` only enough for legacy physics to receive typed outcomes from `resolve_precomputed()`.
6. Convert action and preview consumers: replace outcome dictionary access with typed field/enum access, stop passing `is_dash`, preserve preview badge dictionaries and message strings exactly, and keep explicit Guard Shredder / Execution trigger booleans flowing only from actual mobility-slot strikes.
7. Update focused tests, then run standards lint on changed files and the relevant unit tests for verbs and hit resolver behavior.

## Implementation Notes

- `TickHitOutcome` should preserve the old empty outcome values: `angle = DirectionResolver.HitAngle.NONE`, all booleans false, `hp_damage = 0.0`, `guard_damage = 0`, `feedback_kind = WHIFF`, and `major_trigger = NONE`.
- Prefer enum comparisons at consumers: feedback branches should compare `result.feedback_kind`, Major branches should compare `result.major_trigger`, and refund logic should read `result.killed`, `result.guard_broken`, and `result.angle`.
- Removing `is_dash` applies only to the production tick-grid call chain. Do not remove `Hitbox.GuardDamageProfile` or the local `is_dash` derivation inside `_on_hit_received()`, because that is the legacy physics guard-damage profile path.
- The old `TickHitResolver.FEEDBACK_*` and `MAJOR_TRIGGER_*` constants should disappear with the typed outcome enum, unless a temporary compatibility alias is needed during the edit. The finished code should not leave string-name constants as the public outcome contract.
- Snapshot dictionaries may still use `.get()` inside `TickHitResolver`; this spec targets cross-module output and verb contracts, not the resolver input adapter.

## Edge Cases

| Case                                                     | Expected Handling                                                                                                         |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Input is locked or the Smash cancel confirmation is open | Typed verbs are ignored exactly like the old dictionaries; no mode change or action sneaks through.                       |
| Confirm repeat while not in attack mode                  | The repeat confirm is still suppressed and does not advance the world.                                                    |
| Tick hit target is missing or dead                       | Resolver returns the typed empty outcome and consumers show the same whiff/no-op behavior as before.                      |
| Legacy physics hit enters through a dash-profile hitbox  | Legacy guard damage still comes from `DirectionResolver.dash_guard_damage()` before the shared typed outcome is returned. |
| Mobility strike hits multiple victims                    | Refund checks still refund at most once when any typed outcome qualifies.                                                 |

## Acceptance Criteria

1. Production tick combat has one hit-angle enum, and no adapter functions remain between tick and direction hit-angle vocabularies.
2. Production verb dispatch uses typed verb kind and payload fields, with no string-keyed verb lookups or missing-payload defaults.
3. Hit outcome consumers use typed fields and feedback/Major enums, with no string-keyed outcome lookups or silent defaults across resolver, enemy, action, and preview code.
4. Dash and Smash committed and predicted hits no longer pass a tick `is_dash` or `HitKind` value, while legacy physics hitbox guard profiles still behave unchanged.
5. Hit feedback messages, preview badges, Guard Shredder, Execution, and Mobility Free Action behavior are observably unchanged.
6. Relevant unit tests and standards lint pass after the change.
