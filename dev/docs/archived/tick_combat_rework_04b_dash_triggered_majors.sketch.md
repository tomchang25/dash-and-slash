# Tick Combat Rework 04b: Dash-Triggered Majors

Skeleton sketch split out during Phase 4 planning; revise against the codebase at phase start. The codebase wins every disagreement.

**Mid-phase revision**: the phase name and title keep the "dash-triggered" wording for continuity with the plan table, but the shipped seam is **mobility-slot-triggered**, not Dash-specific. An initial pass scoped Guard Shredder and Execution to the Dash verb only; that would strand a chosen Major dead the moment a run later swaps the mobility slot to Smash, with no way back short of re-picking it. The hooks now live on the mobility slot itself and fire for whichever payload (Dash or Smash) occupies it. Every "dash hit" phrase below means "a mobility-slot strike, whichever payload is active" unless a requirement calls out Dash or Smash specifically.

## Goal

Ship Guard Shredder and Execution as the first mobility-slot-triggered Major effects, proving that triggered run-build effects can modify the same hit outcome used by preview and commit for whichever payload (Dash or Smash) occupies the mobility slot, and wire both effects into the Phase 04a debug controls for immediate validation.

## Requirements

1. Guard Shredder: a back-angle mobility-slot strike zeroes the target's guard and staggers it immediately, bypassing the max(half_guard, 32) table. Each payload keeps its own direction rule: Dash's hit angle is measured from the cell the victim was struck from along its travel path; Smash's hit angle is measured from the locked landing cell (Phase 04's Smash direction rule). Guard Shredder does not change either direction rule — it only reads whichever angle that payload already produces.
2. Execution: a mobility-slot strike on an already-staggered target kills instantly, replacing the 2.0x stagger multiplier. Execution is not angle-gated.
3. Mobility-slot strike resolution queries the run build's mobility-slot triggered-effect hooks so Shredder and Execution modify the shared hit resolver's result rather than forking either payload's resolution code path; the hooks are the same seam later Majors can reuse. The hooks are payload-agnostic by design, so a Guard Shredder or Execution pick keeps working across a mid-run Dash-to-Smash (or Smash-to-Dash) mobility-slot swap.
4. Prediction honesty extends to triggered Majors: with Shredder or Execution active, outcome badges show the upgraded BREAK or KILL result before commit, for whichever payload is currently being previewed.
5. Both effects apply to all enemy kinds initially, including elite enemies, because elite immunity remains a later tuning knob rather than a Phase 04b rule.
6. Temporary modular tween VFX/SFX helpers provide visible Shredder instant-break and Execution kill feedback until final assets exist.
7. Guard Shredder and Execution are wired into the Phase 04a debug controls as independent toggles, because these effects need to be tested alone, together, and across a mobility-payload swap (Dash and Smash) before reward-loop acquisition exists.

## Design

Guard Shredder and Execution are deliberately not mobility payloads. Dash and Smash remain the payloads; these Majors are triggered modifiers that rewrite mobility-slot-strike outcomes under narrow conditions. This keeps the input grammar and movement behavior stable while proving that Major effects can change combat resolution.

The trigger seam lives on the mobility slot, not on any one payload: `RunBuild`'s trigger flags are payload-agnostic, and both the Dash and Smash commit paths (and their previews) read the same flags before calling the shared resolver. Each payload still supplies its own attack origin to that resolver — Dash's per-victim travel-path cell, Smash's locked landing cell — so Guard Shredder's back-angle check and Execution's stagger check are only ever answered by the resolver's existing angle math, never by payload-specific branching in the trigger logic itself.

The debug wire is part of this phase, not a separate follow-up: the effects are not considered implementable until a developer can enable and disable each one through the debug surface and immediately verify preview and commit behavior for both payloads.

## Sketch (non-normative)

- Add triggered-effect records or hooks to the run-scoped build store, keyed by effect id and read by whichever payload's resolution path is active — separate from the mobility payload override used by Smash.
- Apply triggered hooks inside the shared prediction/commit hit path so preview badges and committed effects cannot diverge, and so both Dash and Smash read the identical trigger state.
- Use resolver metadata such as `major_trigger` or equivalent to let presentation distinguish Shredder and Execution from generic guard break or kill while preserving fallback feedback.
- Add independent Guard Shredder and Execution toggles to the Phase 04a debug controls by writing through the same run-build triggered-effect state that real rewards will use.

## Non-Goals

1. No Smash payload _behavior_ changes; Phase 4 owns Smash's own mechanics (windup, area, damage). This phase only makes Smash's existing hit resolution visible to the same trigger hooks Dash already reads.
2. No debug-panel redesign; Phase 04a owns the debug surface, and this phase only adds effect-specific wiring to it.
3. No reward-loop wiring; Phase 04c owns earning these effects through the reward flow.
4. No Chain Dash, Shockwave Dash, or additional Majors.

## Acceptance Criteria

1. With Guard Shredder active, a back-angle mobility-slot strike (Dash or Smash) breaks any guarded target immediately and enters stagger.
2. With Execution active, a mobility-slot strike (Dash or Smash) on an already-staggered target kills immediately.
3. Preview badges show Shredder BREAK and Execution KILL outcomes before the strike commits, for whichever payload is active.
4. The triggered effects modify shared hit outcomes rather than duplicating either payload's resolution code.
5. Shredder and Execution emit temporary but distinct readable feedback.
6. In debug mode, Guard Shredder and Execution can each be toggled independently through the Major debug controls, and stay active across a mobility-payload swap without needing to be re-toggled.
