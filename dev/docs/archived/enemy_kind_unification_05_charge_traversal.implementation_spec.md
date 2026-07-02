# Enemy Kind Unification — Shared Charge Traversal

## Goal

Make ChargeEnemy and ModeEnemy's CHARGE mode share one charge-traversal implementation — arrival snapping, per-cell telegraph clearing, mid-charge streak VFX — so a charge attack looks and behaves identically regardless of which enemy kind performs it. Depends on the attack-executors spec, since hitbox enable/disable during the charge routes through that spec's point executor.

## Relational Context

- `ChargeEnemyChargeAttackState` (`game/entities/enemies/states/charge_enemy_charge_attack_state.gd`, a dedicated `EnemyState` with `state_id = CHARGE_ATTACK`) is today the only charge implementation with mid-charge streak VFX and per-cell telegraph clearing. It assumes its owner is literally a `ChargeEnemy` (`enemy as ChargeEnemy`) and calls `ChargeEnemy`-specific methods: `get_stored_charge_cells`, `begin_charge_attack`, `end_charge_attack`, `clear_stored_charge_cells`, `get_telegraph`, `get_charge_speed`. Reusing this state for `ModeEnemy` requires widening its assumed interface to methods both kinds can supply, not duplicating the state.
- `ModeEnemy`'s CHARGE mode today runs through the generic `EnemyAttackState` (`state_id = ATTACK`, timer-driven via `get_attack_duration()`), not a dedicated charge state — `mode_enemy.tscn`'s `StateMachine` has no charge-specific child node today, only the shared `Attack` node. `ModeEnemy`'s own `begin_attack()`/`update_attack_motion()` overrides drive the charge manually cell-by-cell with no streak VFX and no per-cell telegraph clear.
- After this change, `ModeEnemy` routes CHARGE-mode attacks through the shared charge state instead. This requires: `ModeEnemy.get_attack_state_id()` (not overridden today, so it always returns the generic `ATTACK` id inherited from `GridEnemy`) to return the charge state's id when `_mode == CHARGE`; and `mode_enemy.tscn`'s `StateMachine` to gain a new child node running the shared charge state script, alongside the existing generic `Attack` node still used for TILE/PUFF.
- `ChargeEnemy` stores its current charge's cell sequence via `get_stored_charge_cells`/`set_stored_charge_cells`/`clear_stored_charge_cells`. `ModeEnemy` stores the equivalent as `_charge_cells`/`_charge_index` with no matching accessor names, populated from `_point_executor.get_cells()` at `begin_attack()`. The shared state needs one common way to read/consume the sequence — either `ModeEnemy` adopts `ChargeEnemy`'s accessor shape, or the shared state is rewritten around whichever shape both already have. The attack-executors spec's point executor does not track cell sequences (it only configures/enables one hitbox), so this ownership stays on the enemy kind itself, not the executor.
- Hitbox enable/disable during the charge already routes through the attack-executors spec's shared point executor on both kinds, not a direct hitbox field write: `ChargeEnemy.begin_charge_attack`/`end_charge_attack` call `_point_executor.set_hitbox_enabled(true/false)`, and `ModeEnemy`'s own `begin_attack`/`end_attack` drive the `Mode.CHARGE` branch through `_point_executor.begin_attack()`/`end_attack()`. The shared charge state must call the same point-executor-mediated enable/disable on both kinds — it must not call a `ChargeEnemy`-specific wrapper method that `ModeEnemy` doesn't have.
- `CombatFeedbackVFX.play_charge_start`/`play_charge_streak` already take position/direction/owner, not a `ChargeEnemy`-typed argument — no change needed there.
- `ModeEnemy.update_attack_motion()`'s CHARGE branch becomes dead code once CHARGE routes through the dedicated state instead of the generic `EnemyAttackState`, since `_physics_update` on the generic attack state is what currently calls it. Decide whether to delete it outright or confirm nothing else calls it.

## Scope

### Included

- One shared charge-traversal implementation (a generalized state) used by both ChargeEnemy and ModeEnemy's CHARGE mode.
- Widening the shared state's assumed interface so it depends on methods both kinds can supply, not `ChargeEnemy`-specific ones.
- Wiring ModeEnemy's state machine to route CHARGE-mode attacks through the shared charge state instead of the generic attack state.

### Excluded

- Profile selection, and the telegraph warning/charge-phase display before the charge begins (already shared via `EnemyTelegraphState`, unaffected).
- ModeEnemy's TILE/PUFF mode attack flow (untouched, still uses the generic `EnemyAttackState`).
- Hitbox configuration itself (owned by the attack-executors spec's point executor).

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `game/entities/enemies/states/charge_enemy_charge_attack_state.gd` | Large | Generalize from a `ChargeEnemy`-only state into the one shared charge-traversal state; interface widens to whatever accessors both kinds can supply. |
| `game/entities/enemies/charge_enemy.gd` | Small | Keep or rename accessors the widened shared state now expects; remove any logic the shared state absorbs. |
| `game/entities/enemies/mode_enemy.gd` | Large | Remove `begin_attack()`'s CHARGE branch, `update_attack_motion()`'s CHARGE handling, and `_move_to_charge_cell()`; add a `get_attack_state_id()` override returning the shared charge state's id when `_mode == CHARGE`; supply whatever accessors the shared state expects (stored charge cells, telegraph, charge speed). |
| `game/entities/enemies/mode_enemy.tscn` | Medium | Add a child node under `StateMachine` running the shared charge-state script, alongside the existing generic `Attack` node used for TILE/PUFF. |

## Implementation Notes

- The generalization surface is the six `ChargeEnemy`-specific calls listed in Relational Context. `get_telegraph()` and `get_charge_speed()` are the two most `ChargeEnemy`-specific today; `ModeEnemy` will need equivalents (it already has `_current_attack_data.charge_speed` inline, and would need a telegraph accessor — it has `_telegraph` but no public getter yet).
- Preserve arrival snapping, per-cell telegraph clear order, and the streak VFX interval exactly — these are the "look and feel identical" acceptance criterion, not incidental detail.
- Decide whether `ModeEnemy` adopts `ChargeEnemy`'s `get_stored_charge_cells`/`set_stored_charge_cells`/`clear_stored_charge_cells` accessor names verbatim (simplest, least churn in the shared state) or the shared state is rewritten around a common shape both kinds implement differently underneath.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| ModeEnemy's CHARGE mode currently has no per-cell telegraph clear and no streak VFX. | After this change it gains both, matching ChargeEnemy — an intentional visual upgrade for ModeEnemy's charge mode, not a regression to guard against. |
| ModeEnemy's CHARGE mode currently ends via a fixed `get_attack_duration()` timeout (`CHARGE_ATTACK_TIMEOUT` = 1.2s) if it never finishes traversing. | The shared state, like ChargeEnemy's today, has no timeout — it only ends on reaching the last cell. Confirm this is acceptable for ModeEnemy, or preserve a timeout safety net if not. |

## Acceptance Criteria

1. A charge attack performed by ChargeEnemy and a charge attack performed by ModeEnemy's CHARGE mode use the same traversal implementation, with identical arrival snapping, per-cell telegraph clearing, and mid-charge streak VFX.
2. ModeEnemy's CHARGE mode routes through a dedicated charge state rather than the generic timed attack state.
3. ChargeEnemy's existing charge behavior is unchanged.
