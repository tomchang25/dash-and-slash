# Tick Arena Consolidation 01: Shared Plan Math

## Goal

Merge the planning helpers and player combat base numbers duplicated between the action and preview controllers into shared pure code, so the preview can never disagree with what a commit resolves. This executes the "later cleanup can merge pure helpers" pass that the 06b ownership spec explicitly deferred.

## Relational Context

- `TickActionController` remains the only writer of player state, enemy health, run-build state, and world time; `TickPreviewController` remains read-only and writes only view payloads. This change moves only side-effect-free code; per the 06b rule, any helper that mutates state stays in the action controller.
- The duplicated members today: `_compute_dash_plan`, `_clamped_smash_target`, `_mouse_cell`, `_aim_direction`, `_chebyshev`, `_normal_attack_damage`, `_mobility_attack_damage`, `_mobility_range_cells`, `_angle_name`, and the constants `PLAYER_ATTACK_DAMAGE`, `PLAYER_DASH_DAMAGE`, `PLAYER_SMASH_DAMAGE`, `DASH_RANGE`, `SMASH_RANGE`, `MAX_MOBILITY_RANGE_BONUS_PERCENT` — byte-identical in both controllers.
- `TickCombatRules` is already the home for tick combat numbers and pure projections (`mobility_cooldown_ticks`, `mobility_range_cells` live there); the base-number constants and the one-line damage/range projection helpers move there, extending the existing pattern. `DASH_COOLDOWN_TICKS` / `SMASH_COOLDOWN_TICKS` move too so every tuning number has one home.
- A new pure static planner class owns the geometry/plan functions (dash plan, smash target clamp, smash area, aim direction, chebyshev). Its functions take `GridArena`, `TickEngine`, cells, and resolved range values as explicit arguments and query them read-only (`is_land`, `enemy_at`); the planner never reads `RunBuild` — callers project totals through `TickCombatRules` and pass results in.
- The preview controller keeps reading last-aim and aim-mode from the action controller (`get_last_aim()`, `is_mobility_mode()`) — that stays the single truth for aim state; the shared aim-direction helper takes last-aim as an argument instead of reaching into either controller.
- The dash-plan dictionary shape (`legal`, `dir`, `path`, `landing`, `victims`) is unchanged here; child 04 owns contract typing.

## Scope

### Included

- New shared static planner class; constants and projection helpers absorbed into `TickCombatRules`.
- Both controllers deleted down to calls into the shared code.
- Header docstring of the preview controller updated — it currently documents the deliberate duplication this spec removes.

### Excluded

- Any behavior, tuning, or contract-shape change.
- Controller merge or ownership boundary changes.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `game/tick_arena/combat/tick_action_planner.gd` (new) | Medium | Pure static geometry/plan functions shared by action and preview |
| `game/tick_arena/combat/tick_combat_rules.gd` | Small | Absorb base-number constants and damage/range projection statics |
| `game/tick_arena/combat/tick_action_controller.gd` | Medium | Delete local copies; call shared planner/rules |
| `game/tick_arena/combat/tick_preview_controller.gd` | Medium | Delete local copies; call shared planner/rules; rewrite header doctrine |
| `test/unit/*` | Small | Add focused planner tests (dash landing/victims, smash clamp, aim fallback) |

## Implementation Notes

- Move `_angle_name` into `TickCombatRules` next to the angle vocabulary it renders; both controllers' copies delete.
- `_compute_dash_plan` takes the resolved max range as a parameter; each controller computes it via the rules projection from its own `RunBuild` reference, which keeps the planner ignorant of run state.
- Keep the planner free of `@export`s, signals, and node state — static functions only, so it is trivially unit-testable.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| Mouse delta zero or perfectly diagonal | Shared aim helper falls back to the passed last-aim, identical for preview and commit |
| Debug-stub mobility payload | Both controllers keep their existing stub branches; only the shared geometry they call moves |

## Acceptance Criteria

1. No planning function or combat base constant exists in more than one file.
2. Preview badges and committed outcomes agree for dash, smash, and normal attack in every aim configuration they agreed on before.
3. Gameplay is observably unchanged; lint and unit tests pass.
