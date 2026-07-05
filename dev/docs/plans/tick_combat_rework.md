# Tick Combat Rework: Player-Clocked Grid Combat Conversion

## Goal

Convert the game from real-time free player movement over grid-locked enemies to a fully player-clocked tick architecture — every player input advances the world exactly one tick — because the current split time domain is the root cause of unreadable enemy behavior, trivialized telegraphs, and a flank system with no positioning cost, while every combat-identity system already built (telegraphs, facing, guard, the applied-effect store) is grid-native and carries over. The grey-box prototype gate passed with a go verdict on 2026-07-05 (its plan is archived and its learnings are folded into the v0.5 design document), so the conversion phases are cleared to start.

## Requirements

1. The tick arena is built in parallel, grown out of the prototype scene, and the current real-time arena remains playable until the tick arena reaches run-loop parity — the game stays shippable through the whole conversion, and the old path is deleted only at cutover.
2. Combat identity carries over by reuse, not reinvention: the guard/stagger damage tables, tile-offset attack pattern data, telegraph rendering, enemy grid-move reservation priority, and the run-scoped applied-effect store all survive; the pivot changes the player's time and space domain, not what makes combat this game's combat.
3. Enemy behavior converts from second-based timers to tick counts, with telegraph countdowns denominated in player actions and per-kind pursuit speeds carried on the energy skeleton the prototype proved (slower pursuers leak distance so chases never lock on forever), so enemy intent and pressure are always expressed in the one currency the player controls.
4. Player speed becomes three independent, data-driven stats projected from the applied-effect store — a free-step charge meter for movement, windup-tick reduction for attacks, and cooldown ticks for the mobility slot — so speed rewards stack per domain without ever making a telegraph lie.
5. The mobility slot is an ability-override seam: Dash is the default payload, Smash is the first slot-replacing Major effect, and Guard Shredder and Execution ship as dash-triggered Majors — the override and trigger seams are proven with real content, not another placeholder.
6. Player previews carry resolved outcomes, not just geometry — a landing ghost and per-victim angle/result badges computed by the same deterministic hit math that resolves the commit — because the prototype showed geometry-only previews read as no preview at all.
7. The wave and terrain loop is recalibrated for tick pacing — fewer concurrent enemies, with composition and geometry as the pressure knobs instead of raw density, because in tick combat each enemy is a puzzle piece and density past legibility is noise.
8. The design document is brought to v0.5 as the single design truth, and this plan closes out through the project's standard closeout workflow.
9. Player-facing action timing never uses hidden variable costs — movement, attacks, mobility verbs, waits, windup arms, and windup releases are public integer-tick steps, because action costs like "this attack spends three ticks of world time" were rejected for making enemy countdowns mathematically untrustworthy.

## Design

### Phase overview

| Phase | Focus                           | One-line description                                                                                                                                                       |
| ----- | ------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1     | Tick core and player controller | Productionize the prototype's tick scheduler, player verbs, and input feel in a parallel arena scene.                                                                      |
| 2     | Enemy tick conversion           | Every enemy kind's states count ticks instead of seconds; telegraphs count player actions; reservations, attack executors, and per-kind energy-skeleton speeds are reused. |
| 3     | Mobility slot and previews      | Dash on the grid, the preview-is-truth targeting layer with landing ghost and resolved-outcome badges, and the ability-override seam for the slot payload.                 |
| 4     | Windup and first real Majors    | The windup grammar; Smash as the slot-replacing Major; Guard Shredder and Execution as dash-triggered Majors.                                                              |
| 5     | Speed stats                     | The three player speed stats as applied-effect-store projections offered as Minor effects, on the energy skeleton the prototype already proved.                            |
| 6     | Run loop recalibration          | Wave scaling, concurrent-enemy target, terrain cadence, and arena size retuned for tick pacing.                                                                            |
| 7     | Cutover and closeout            | Remove the real-time player path, route production scenes to the tick arena, sync the design document, close out.                                                          |

Phases land strictly in order. Each is independently shippable behind the parallel-arena boundary, so the main branch stays green throughout the conversion.

Each phase has a skeleton sketch written ahead (`tick_combat_rework_0N_*.sketch.md`) capturing its decisions, key concepts, and initial tuning values in non-normative form. At phase start the sketch is revised against the codebase as it exists at that moment — the codebase wins every disagreement, per the sketch standard — and is upgraded to an implementation spec where cross-system ownership warrants verified coordinates (most likely phases 2 and 6). This keeps the lesson of the reward-effect rework, where a spec written ahead of its predecessor phases had to be superseded: nothing normative is ever written against a codebase that earlier phases will change, but the thinking is banked early where it is cheap to revise.

### Design guardrails

The rework keeps a bottom-layer energy skeleton only for actor scheduling, skipped beats, explicit extra actions, and visible free-step rules. It does not expose fractional or variable player action costs: if an action needs to be slow, it becomes a visible windup sequence; if an action needs to be fast, it becomes a visible free action, cooldown change, or earned extra opportunity. This guardrail is what keeps "N ticks until danger" equal to "N committed player inputs" instead of a hidden simulation budget the player cannot audit.

The rejected direction set is also part of the plan boundary. A fixed metronome world, a discrete-space continuous-time arena, and a return to fully continuous melee were all rejected for this conversion because they either reintroduce timing pressure that can make telegraphs feel unfair, weaken the facing/flank systems the codebase already owns, or discard the existing grid-native combat assets. Player-clocked tick combat is chosen because it preserves the tactical systems already built while letting the player decide moment by moment whether to flow quickly or stop and read the board.

The target play loop is not only parity with the legacy arena. A run should feel complete because each local situation is a readable positional puzzle and the build changes the price of solutions — hard front damage, flanking, dash-throughs, stagger setups, terrain baiting, or mobility escapes — without needing meta progression or future content volume to rescue the core loop.

### Division of design authority

The tick system's behavioral design — the time contract, resolution order, occupancy rules, input grammar, speed model, and combat numbers — lives in the v0.5 design document, not here. This plan owns only gating, phase sequencing, and carry-over discipline, so the two documents never compete as sources of truth.

## Non-Goals

1. No new enemy content beyond conversion — the small-enemy pattern director and the sprite readability scaffold remain separate follow-up work, re-anchored to the tick architecture after cutover.
2. No Chain Dash and no additional Majors beyond Smash, Guard Shredder, and Execution — they are follow-up content once the override and trigger seams exist.
3. No meta progression, no manual terrain targeting, and no reward-choice UI rework.
4. No change to the applied-effect store architecture itself — the speed channels are additions on the existing store, not a redesign of it.

## Acceptance Criteria

1. The whole run loop — waves, rewards, terrain cadence, death and restart — is playable end to end in the tick arena, and at cutover the old real-time arena is removed with no production scene routing to it.
2. Every reward effect that exists at conversion time still offers and applies correctly in the tick arena, with numeric projections unchanged where the stat still exists and explicitly re-mapped where the pivot redefined it.
3. Enemy telegraph countdowns are denominated in player actions everywhere, and over a full run no attack resolves outside its displayed tiles or displayed timing.
4. Speed rewards demonstrably stack within their own domains — movement, windup, cooldown — without changing what any displayed telegraph promised.
5. Playtest parity includes the new loop's fun target: low-density encounters create readable positional decisions, and rewards change which solutions are cheap rather than only raising numbers.
6. The v0.5 design document matches shipped behavior, and after closeout no open-work pointer to this plan or its phase files remains outside the shipped-work archive.
