# Tick Combat Rework 02: Enemy Tick Conversion

Skeleton sketch written ahead of the phase; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Convert every production enemy kind (small, puff, charge, and the mode-cycling elite) from second-based timers to tick counts driven by the phase 1 engine, so enemy intent is always denominated in player actions.

## Requirements

1. Conversion is in place: the existing production enemy stack — the grid base, the four kinds, their states, and the shared executors — is itself modified to tick clocking, with no tick-prefixed forks anywhere, because maintaining two enemy implementations costs more than the in-repo fallback is worth. The state-machine framework stays — behavior delegation per kind is the right shape — but states advance on engine tick callbacks instead of frame-time accumulation, and every duration field (telegraph, attack active, recovery, stagger) is authored as a tick count.
2. Telegraph countdowns display in player actions everywhere, and detonation resolves as cell-membership checks against the player's post-action cell — replacing physics hit-volume overlap for enemy-to-player damage, which is the tick translation of "telegraph tiles are the attack".
3. The tile-offset attack pattern data and the shared cell/point attack executors are reused for footprint, telegraph phases, and per-cell resolution; the pivot changes their clock, not their data or ownership.
4. Grid reservation priority (active step > attack intent > closer to player > registration order) carries over unchanged as the deterministic arbiter for enemy stage-3 movement.
5. Per-kind pursuit speed rides the energy skeleton with fixed tuning values, following the prototype's finding that baseline-speed pursuit locks on forever.
6. Enemy facing gains a per-tick turn cap as the flank-depth knob, and guard stagger converts from a wall-clock timer to a tick countdown with guard refilling when stagger ends.
7. Guard break clears the enemy's accumulated action energy, and staggered enemies neither act nor accumulate new action energy until the stagger countdown ends, because a just-recovered enemy should not surprise the player with banked movement.
8. Converted enemies register with the tick arena's engine and implement its actor entry points (status countdown, energy-funded action, detonation resolution); the phase ends by spawning the converted kinds in the tick arena and deleting the interim grey-box actors.
9. Converted enemies preserve existing combat feedback responsibilities — status bars, damaged/blocked/death SFX, guard-break/shield/full-damage VFX, and telegraph phase presentation — with tick detonation and resolver events replacing the old physics/timer triggers.

## Design

- Initial per-kind speeds (tuned in playtest): small 75, puff 75, charge 100, elite 100. Slower kinds simply skip a beat — the prototype confirmed this reads naturally without extra signaling; only faster-than-baseline actors would need the loud double-move telegraphing, and none ship in this phase.
- Initial duration conversions (tuned in playtest): small-enemy telegraphs 1-2 ticks by pattern, charge telegraph 2 ticks, puff expansion 2 ticks, elite patterns 2-3 ticks, stagger 3 ticks, recoveries 1-2 ticks.
- Turn cap initial: 90 degrees per tick for all kinds; the elite may later get a faster cap as a threat knob.

## Sketch (non-normative)

- The `Guard` component's `_start_stagger()` wall-clock timer becomes a tick countdown stepped by the owning enemy's tick callback; `Health` needs no change.
- Enemy states (`enemy_telegraph_state`, `enemy_attack_state`, `enemy_recovery_state`, etc.) swap `delta`-accumulation for an `advance_tick()` entry point; the state machine wiring itself is untouched.
- `EnemyAttackData` duration fields reinterpret as tick counts (int); data `.tres` files under the enemy feature folder update alongside.
- Enemy-to-player damage: at detonation, ask the engine whether the player's cell is in the attack's locked tiles; the enemy-side `Hitbox`/hit-volume path for hitting the player retires here or in phase 7, whichever the spec-at-start finds cheaper.
- Enemy energy is an action-progress meter, not a hidden banked turn queue: stagger, death, and hard attack interruption clear any pending progress that would otherwise resolve after the disabling state ends.
- Existing enemy feedback seams stay live where their meaning still matches: a shielded tick hit should still read like a shielded hit, guard break should still read like guard break, and enemy death should still fire the established death feedback even though the hit source is now grid resolution.
- The prototype's melee/charger behaviors are throwaway references, not ports — production kinds keep their own (converted) state machines; `tick_melee_enemy` / `tick_charge_enemy` and their scenes are deleted at the end of this phase.
- The legacy real-time arena stops functioning at this phase (its enemies no longer understand seconds); it stays in-repo, unrouted and broken, until phase 7 deletes it — rollback is version control plus the exported baseline build.

## Non-Goals

1. No new attack patterns or kinds — the pattern director stays follow-up work.
2. No changes to wave spawning or scaling (phase 6).
3. No player-side changes.

## Acceptance Criteria

1. All four enemy kinds fight the player in the tick arena with correct tick-denominated telegraphs; over a session no attack resolves outside its displayed tiles or displayed countdown.
2. Reservation-driven movement stays deterministic (same seed and inputs, same outcome).
3. Guard break, stagger, and recovery windows all count in ticks, stagger still refills guard on end, and a recovering enemy never spends action energy accumulated while disabled.
4. The tick arena runs on the converted production kinds, the interim grey-box actors are deleted, and no tick-prefixed enemy fork exists anywhere in the repo.
5. Enemy damage, blocked hits, guard breaks, stagger, and death still emit the established readable VFX/SFX feedback through tick-world events.
