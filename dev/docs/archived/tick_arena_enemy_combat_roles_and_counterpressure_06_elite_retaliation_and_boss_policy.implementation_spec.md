# Tick Arena Enemy Combat Roles And Counterpressure 06: Elite Retaliation And Boss Policy

Parent Plan: `tick_arena_enemy_combat_roles_and_counterpressure.md`

## Goal

Give Mode enemies a readable ten-tick retaliation window after Stagger recovery while preserving per-boss freedom to use the default rule, replace it with encounter-specific behavior, or omit it.

## Summary

Mode will begin ten normal world ticks of retaliation when Stagger recovery completes, alongside the existing five-tick Guard protection. A persistent five-frame Aura will remain visible for the full retaliation window, including five ticks after protection ends, without adding damage labels to the danger overlay.

Every attack committed while the window is active will snapshot one fewer warning tick, with a floor of one, and 1.25 times normal outgoing damage. Retaliation counts down through pathing, windup, and recovery; attack resolution or ordinary cancellation does not end it. The shared enemy tick runtime keeps each committed attack immutable even if retaliation expires during its windup. A new Stagger, death, or reset clears the window early.

The placeholder Mode Boss will use the default retaliation because it currently shares Mode behavior. Mode will expose an overridable post-Stagger policy hook so a future encounter-specific boss script can substitute custom phase behavior or intentionally do nothing without branching shared Mode logic.

## Relational Context

- `Guard` owns Stagger and five-tick protection. Recovery triggers Mode's fresh selection and independent ten-tick policy, leaving five retaliation ticks after protection.
- `ModeEnemy` owns retaliation ticks and the policy hook. Its status pass counts an existing window through pathing, windup, and recovery without consuming the Stagger-ending tick; FSM states remain decision-only.
- `GridEnemy` writes prospective damage with warning and footprint to `EnemyTickRuntime`; the runtime owns that immutable snapshot through countdown zero until resolution or cancellation clears it.
- Mode modifies every prospective commit while retaliation ticks remain. Resolution and ordinary attack cancellation preserve the window; expiry stops future modifiers without changing an existing snapshot.
- Detonation and committed-damage inspection read the runtime, not live `EnemyAttackData` or retaliation time. Danger stays `{cells, ticks}` and reads the committed countdown.
- Guard break, death, and reset clear the window. A later recovery restarts at ten rather than stacking time or multipliers.
- `ModeEnemy` commands semantic visibility, `ModeEnemyVisualPresenter` animates it, and each Mode scene owns its Aura node and feature-owned texture. Debug text observes the same phase without controlling it.
- The placeholder Boss uses `ModeEnemy` and its default hook. Future boss scripts override the hook to replace or omit retaliation; no generic `CUSTOM` data enum is introduced.

## Scope

### Included

- Ten-tick retaliation for Mode and the placeholder Boss.
- Commit-time warning and outgoing-damage snapshots shared by tick enemies.
- A looping, enemy-local Aura cue and retaliation-aware debug inspection.
- Focused lifecycle, snapshot, policy, scene, and regression tests.

### Excluded

- Bespoke boss phases, summons, attacks, or health gates.
- Retaliation for Small, Heavy, Bomb, Ranged, or other roles.
- Enemy damage labels or multiplier badges in the danger overlay.
- A rally action, new enemy FSM state, audio cue, or Guard-protection change.

## Files to Change

| File                                                                        | Change Size | Purpose                                                                     |
| --------------------------------------------------------------------------- | ----------- | --------------------------------------------------------------------------- |
| `game/entities/enemies/enemy_tick_runtime.gd`                               | Medium      | Own committed damage with the attack snapshot.                              |
| `game/entities/enemies/grid_enemy.gd`                                       | Medium      | Capture and resolve snapshotted outgoing damage.                            |
| `game/entities/enemies/mode_enemy.gd`                                       | Large       | Own retaliation, policy, cleanup, presentation commands, and debug context. |
| `game/entities/enemies/mode_enemy_visual_presenter.gd`                      | Medium      | Animate and reset the independent Aura.                                     |
| `game/entities/enemies/mode_enemy.tscn`                                     | Small       | Pre-place the Mode Aura overlay.                                            |
| `game/entities/enemies/mode_boss.tscn`                                      | Small       | Pre-place the scaled Boss Aura overlay.                                     |
| `game/entities/enemies/assets/mode_enemy/retaliation_aura_sprite_sheet.png` | Small       | Feature-owned approved Aura sheet.                                          |
| `test/unit/test_enemy_tick_runtime.gd`                                      | Medium      | Cover snapshot persistence and clearing.                                    |
| `test/unit/test_mode_enemy_attack_cycle.gd`                                 | Large       | Cover retaliation, policy, cleanup, presentation, and debug behavior.       |
| `test/unit/test_grid_enemy_hit_reaction.gd`                                 | Small       | Update its direct runtime fixture.                                          |

## Execution Outline

1. Commit footprint, countdown, and damage together; cover the runtime and update its direct fixture.
2. Add Mode's policy and countdown; cover multi-attack commits, expiry snapshots, cleanup, debug status, and boss override.
3. Copy and pre-place the Aura, then connect presenter animation to retaliation time.
4. Run focused tests, Bomb/Ranged regressions, and standards lint.

## Implementation Notes

### Shared committed attack contract

- Track snapshot existence separately from pending countdown: zero ticks must retain damage until detonation finishes or cancellation clears it.
- Keep one damage read that calculates before commit and returns the snapshot afterward. Preserve danger shape and default enemy math.

### Mode retaliation and policy

- Start at ten before Mode's public recovery signal and decrement only windows active before that status pass.
- Apply modifiers while time remains. Resolution preserves time; Stagger, death, reset, or expiry hides the Aura. A boss override owns its response.

### Aura presentation

- Copy only `assets/Ninja Adventure - Asset Pack/FX/Magic/Aura/SpriteSheet.png`, not the GIF or `.import`; it is 125 by 24 pixels with five horizontal RGBA frames.
- Pre-place hidden, nearest-filtered `%RetaliationAura` nodes under each presenter at sprite scale 5 or 8. Loop near the source cadence; action transforms and sprite tint must not control Aura visibility.

## Edge Cases

| Case                                               | Expected Handling                                                                             |
| -------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| Authored warning is one tick                       | Empowered warning remains one tick.                                                           |
| Attack preparation fails or Mode keeps pathing | Retaliation continues its normal world-tick countdown. |
| Attack resolves or is ordinarily cancelled | Retaliation remains active for later commits until expiry. |
| Window expires during a committed windup | Aura and future modifiers end; committed countdown and damage remain empowered. |
| Mode is Guard-broken again | The old window clears; recovery restarts at ten without stacking. |
| Attack data changes after commit | Countdown and damage remain committed. |
| Death or reset while active | Snapshot, retaliation, Aura, windup, and telegraph clear without detonation. |
| Boss replaces or omits the default policy          | Its override runs without changing shared Mode behavior or requiring a generic policy enum.   |

## Acceptance Criteria

1. Mode visibly carries an Aura-marked retaliation for ten normal world ticks after Stagger recovery, including five ticks after Guard protection ends.
2. Every attack committed during the window displays one fewer warning tick, never below one, and resolves exactly 1.25 times ordinary outgoing damage from values fixed at commit.
3. Retaliation counts down through pathing, windup, and recovery; resolution and ordinary cancellation preserve it, while expiry, another Guard break, death, or reset clears it.
4. The placeholder Mode Boss uses the default retaliation, while an encounter-specific Boss can replace or omit the post-Stagger policy without modifying Mode behavior.
5. Enemy danger countdowns, Mode presentation, committed resolution, and debug inspection agree on remaining retaliation time and empowered snapshots without adding enemy damage labels.
6. Other enemy roles retain their existing warning, damage, cancellation, and danger behavior under the shared committed-damage snapshot contract.
