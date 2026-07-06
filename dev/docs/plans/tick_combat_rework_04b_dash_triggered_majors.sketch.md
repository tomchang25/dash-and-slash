# Tick Combat Rework 04b: Dash-Triggered Majors

Skeleton sketch split out during Phase 4 planning; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Ship Guard Shredder and Execution as the first dash-triggered Major effects, proving that triggered run-build effects can modify the same hit outcome used by preview and commit, and wire both effects into the Phase 04a debug controls for immediate validation.

## Requirements

1. Guard Shredder: a back-angle dash hit zeroes the target's guard and staggers it immediately, bypassing the max(half_guard, 32) table.
2. Execution: a dash hit on an already-staggered target kills instantly, replacing the 2.0x stagger multiplier.
3. Dash resolution queries the run build's on-dash-hit triggered-effect hooks so Shredder and Execution modify the shared hit resolver's result rather than forking the dash code path; the hooks are the same seam later Majors can reuse.
4. Prediction honesty extends to triggered Majors: with Shredder or Execution active, outcome badges show the upgraded BREAK or KILL result before commit.
5. Both effects apply to all enemy kinds initially, including elite enemies, because elite immunity remains a later tuning knob rather than a Phase 04b rule.
6. Temporary modular tween VFX/SFX helpers provide visible Shredder instant-break and Execution kill feedback until final assets exist.
7. Guard Shredder and Execution are wired into the Phase 04a debug controls as independent toggles, because these effects need to be tested alone, together, and alongside Smash before reward-loop acquisition exists.

## Design

Guard Shredder and Execution are deliberately not mobility payloads. Dash remains the payload; these Majors are triggered modifiers that rewrite dash-hit outcomes under narrow conditions. This keeps the input grammar and movement behavior stable while proving that Major effects can change combat resolution.

The debug wire is part of this phase, not a separate follow-up: the effects are not considered implementable until a developer can enable and disable each one through the debug surface and immediately verify preview and commit behavior.

## Sketch (non-normative)

- Add triggered-effect records or hooks to the run-scoped build store, separate from the mobility payload override used by Smash.
- Apply triggered hooks inside the shared prediction/commit hit path so preview badges and committed effects cannot diverge.
- Use resolver metadata such as `major_trigger` or equivalent to let presentation distinguish Shredder and Execution from generic guard break or kill while preserving fallback feedback.
- Add independent Guard Shredder and Execution toggles to the Phase 04a debug controls by writing through the same run-build triggered-effect state that real rewards will use.

## Non-Goals

1. No Smash payload work; Phase 4 owns Smash.
2. No debug-panel redesign; Phase 04a owns the debug surface, and this phase only adds effect-specific wiring to it.
3. No reward-loop wiring; Phase 04c owns earning these effects through the reward flow.
4. No Chain Dash, Shockwave Dash, or additional Majors.

## Acceptance Criteria

1. With Guard Shredder active, a back dash hit breaks any guarded target immediately and enters stagger.
2. With Execution active, a dash hit on an already-staggered target kills immediately.
3. Preview badges show Shredder BREAK and Execution KILL outcomes before the dash commits.
4. The triggered effects modify shared hit outcomes rather than duplicating dash resolution.
5. Shredder and Execution emit temporary but distinct readable feedback.
6. In debug mode, Guard Shredder and Execution can each be toggled independently through the Major debug controls.
