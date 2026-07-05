# Tick Enemy Ownership Rework

## Goal

Phase 2 of the tick combat conversion left enemy behavior ownership split across three owners — the state machine, the shared enemy base, and the tick engine — and concentrated nearly every other enemy rule in the shared base. This rework settles ownership before phases 3–5 stack previews, windup, and speed stats onto the same seams: the state machine is deliberately narrowed to an intent layer, clocked combat statuses move into a dedicated per-enemy tick combat runtime, and pure computation leaves the shared base.

## Requirements

1. The enemy state machine becomes a deliberate intent/decision layer: states own action selection and dispatch (plan, step, turn, commit), while clocked statuses — telegraph countdown, recovery window, action freeze — are owned by a per-enemy tick combat runtime. Timers stay out of states because the engine's staged world resolution (detonations, then status, then funded actions) is a global ordering concern; states would otherwise need one hook per resolution stage.
2. Each enemy owns exactly one tick combat runtime instance, and the enemy entity remains the engine-facing actor facade with an unchanged hook contract, so the scheduler and later phases (previews, windup, speed stats) integrate against the same three-stage seam.
3. Per-kind combat differences (detonation side effects such as the charge dash-along-line, mode re-roll after resolve, telegraph presentation) stay on the enemy kind layer, invoked by the runtime at the right lifecycle moments — the runtime owns when, kinds own what.
4. Normal-flow state transitions are decided inside states; entity code may request only interrupt transitions (stagger, death), restoring a single readable rule for who moves the machine.
5. Tick-clocked facing changes flow through one turn-capped funnel, and instant-facing entry points are removed, so no enemy kind can bypass the flank turn cap. The cap is a core positioning-cost mechanic, so bypassing it must be structurally impossible rather than reviewer-enforced.
6. Path search/scoring and hit-outcome math are extracted into stateless helpers; the shared enemy base retains only grid identity, occupancy and reservation interaction, health/guard/death bridging, and the actor facade. Hit prediction and hit resolution keep sharing one implementation so previews can never disagree with resolved hits.
7. Real-time-only enemy states and the real-time-only support surface they depend on are deleted now rather than at cutover, because they are unreachable in tick flow and keeping them would mean porting dead code onto the new runtime; rollback remains version control plus the exported baseline build.
8. The on-screen debug state readout continues to show telegraph and recovery truth after states stop owning those windows, and the project state-machine guidance is updated to record the narrowed FSM role for tick enemies.

## Design

### Target ownership map

| Concern                                                                                | Owner after rework                                       |
| -------------------------------------------------------------------------------------- | -------------------------------------------------------- |
| Action selection and dispatch (plan, reposition, turn, commit)                         | State machine states                                     |
| Telegraph countdown, escalation timing, recovery window, busy freeze, danger reporting | Per-enemy tick combat runtime                            |
| World resolution order, energy banking, disabled-actor gating                          | Tick engine (unchanged)                                  |
| Detonation side effects and telegraph presentation per kind                            | Enemy kind layer, invoked by the runtime                 |
| Path search, endpoint ranking, reservation-aware claims                                | Stateless planning helper                                |
| Hit outcome math (angle, guard, lethality)                                             | Stateless resolution helper shared by preview and commit |
| Grid identity, occupancy, reservations, health/guard/death bridging, actor facade      | Shared enemy base                                        |

### State machine after narrowing

Surviving states are the ones that make decisions or represent interrupts: idle (plan and dispatch), reposition (step along a planned path), face-target (turn under the cap), mode-change (for the mode-rolling kind), staggered, and dead. The telegraph and recovery label states disappear: committing an attack happens directly from the deciding state, and a committed or recovering enemy is simply frozen by the runtime until the window ends — the machine stays in its last decision state. Attack-phase states from the real-time architecture (generic attack, charge dash, puff expansion, puff pre-charge) are deleted along with their identifiers.

Kind hooks that today answer "which state should I enter" become "may I commit an attack right now" predicates, and the deciding states call the commit directly; existing per-kind readiness checks already express these predicates. The mode-rolling kind keeps its dedicated pre-decision state because rolling a mode is a genuine multi-tick decision behavior, not a label.

### Staging

Five reviewable steps, each leaving the tick arena playable: extract hit resolution (behavior-neutral), extract path planning (behavior-neutral), introduce the runtime and migrate clocked state, narrow the state machine, then delete the real-time-only surface and sync docs. Behavior-affecting steps come last so any parity regression bisects to a small diff.

## Non-Goals

1. No change to the tick engine's resolution order, energy model, or actor contract.
2. No new enemy behavior, content, or tuning — tick-for-tick behavior parity is the bar.
3. No phase 3–5 features (previews, windup grammar, speed stats); this rework only prepares their seams.
4. No removal of the real-time player or arena scenes — full cutover deletion remains phase 7; only enemy-side dead code goes now.

## Acceptance Criteria

1. A full tick-arena run plays with enemy behavior parity: pursuit pacing, telegraph counts, detonation footprints and timing, recovery windows, stagger, and death behave exactly as before the rework.
2. Danger reporting and hit prediction produce the same data as before, and predictions still match resolved outcomes exactly.
3. No state script owns a clocked countdown, and the only entity-requested transitions are the stagger and death interrupts.
4. No code path can turn an enemy past the per-action turn cap.
5. The debug readout still surfaces telegraph and recovery status, the state-machine guidance documents the narrowed role, both source probes are archived with their decision recorded, and standards lint passes on all touched files.
