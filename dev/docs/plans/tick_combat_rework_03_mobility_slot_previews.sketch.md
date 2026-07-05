# Tick Combat Rework 03: Mobility Slot And Previews

Skeleton sketch written ahead of the phase; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Formalize the dash verb, the preview-is-truth targeting layer with resolved outcomes, and the ability-override seam that lets a Major replace the mobility slot's payload without touching the input grammar.

## Requirements

1. Dash: straight line in 4 directions, cursor picks the landing cell clamped to range (5), obstacles, and occupancy; every enemy passed is hit with the dash damage rules; cooldown counts in ticks. This is the slot's default payload.
2. Hit prediction and hit application share one pure function, so the preview layer structurally cannot disagree with the commit — the prototype's predict/apply split becomes the production shape.
3. Previews show resolved outcomes, not just geometry: a landing ghost plus per-victim angle/result badges (chip, break, kill tiers), because the prototype showed geometry-only previews read as no preview at all.
4. Player-side preview visuals use a palette strictly separated from the enemy telegraph palette (hard rule from the design document).
5. The mobility slot reads its payload from the run build's ability-override channel at verb time; this phase ships the seam with dash as the only payload, proving the read path before phase 4 adds a second payload.
6. The angle resolver quantizes to grid: attacker origin cell (for dash, the cell before entering the target's cell) relative to target facing; diagonal or ambiguous origins resolve to side.

## Design

Outcome badge tiers (from the prototype): tier 0 chip = angle label only, tier 1 = break/burst, tier 2 = kill; higher tiers draw brighter and thicker. Badge density and a hold-to-aim fallback are parked in the design document's deferred list — do not build them here unless production playtest re-raises the problem.

## Sketch (non-normative)

- Proposed shared resolver: `tick_hit_resolver.gd` as a static service (pure computation, no state) exposing `predict(origin_cell, target_snapshot, base_damage, is_dash)` and the angle/guard/bypass/stagger tables; both the preview layer and the commit path call it. It replaces the prototype's `ProtoCombatRules` plus per-enemy `predict_hit`.
- Ability-override read: `RunBuild` gains an `ability_overrides` channel (e.g. `mobility_payload = "dash"`); the input layer asks the build, not a hardcoded enum. The reward-store architecture itself is untouched (rework plan non-goal).
- Preview state flows controller → view as plain dictionaries, as in the prototype; the view stays a dumb renderer.
- Target snapshots for prediction: cell, facing, guard current/max, staggered, hp — read-only copies so prediction can never mutate.

## Non-Goals

1. No Smash, no windup grammar, no triggered effects (phase 4).
2. No speed stats (phase 5); dash cooldown is a constant here.
3. No new input modes — single-press commit with always-on preview stays the grammar.

## Acceptance Criteria

1. Every commit executes exactly what its preview displayed at press time, including clamped landings; preview and commit provably share one code path for hit math.
2. Swapping the ability-override value swaps the slot's behavior with zero input-layer changes (demonstrable with a debug toggle ahead of phase 4's real Major).
3. Outcome badges match the resolved results across angle, break, and kill cases.
