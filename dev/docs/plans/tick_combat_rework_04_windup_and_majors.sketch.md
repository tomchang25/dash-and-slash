# Tick Combat Rework 04: Windup And First Real Majors

Skeleton sketch written ahead of the phase; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Ship the windup grammar and the first three real Major effects — Smash (slot-replacing), Guard Shredder and Execution (dash-triggered) — proving the override and trigger seams with real content instead of another placeholder.

## Requirements

1. Windup grammar: pressing a windup verb arms it for one tick (the player's own telegraph and target area light up, enemies act one beat), the next press of the same verb releases, any other verb cancels the arm without refunding the spent tick, and holding the verb key releases automatically on the next repeat pulse ("hold = two beats, one strike").
2. Smash: choose a landing cell within range 3, leap there on release, hit the 3x3 around the landing with dash-class damage; windup 1 tick; cooldown longer than dash (initial: 6 ticks vs dash 4, tuned in playtest). Its trade reads as "give up instant mobility for a delayed area guard-breaker".
3. Smash is authored into the same exclusivity group as the future Chain Dash — the group mechanism already exists from the reward rework; this phase only authors the membership.
4. Guard Shredder (dash-triggered Major): a back-angle dash hit zeroes the target's guard and staggers it immediately, bypassing the max(half_guard, 32) table.
5. Execution (dash-triggered Major): a dash hit on an already-staggered target kills instantly, replacing the 2.0x stagger multiplier.
6. Trigger seam: dash resolution queries the run build's triggered-effect hooks (on-dash-hit) so Shredder and Execution modify the shared hit resolver's result rather than forking the dash code path; the hooks are the same seam later Majors (Shockwave Dash, Chain Dash) will use.
7. All three ship as pickable Major reward effects through the existing pool, respecting the run-wide cap of four.
8. Major and windup feedback reuses existing combat/audio seams where possible, adding only distinct Shredder instant-break and Execution kill events where the design document calls for stronger separation.

## Design

- Prediction honesty extends to Majors: with Shredder or Execution held, the outcome badges must show the upgraded results (BREAK on back dashes, KILL on staggered targets) — the hooks run inside the shared resolver so previews get them for free.
- Whether Shredder/Execution apply to the elite stays an open design-document question (v0.5 §11.3); initial implementation applies them to everything, an elite-immunity flag is a later tuning knob.
- Smash direction rule: landing cell is the attack origin for every target in the area, using the standard angle resolver (no special no-direction case; deferred-list item if playtest disagrees).

## Sketch (non-normative)

- `RunBuild` gains a `triggered_effects` channel; effect objects for the three Majors follow the existing per-effect-object pattern (own eligibility, own apply) and write `ability_overrides.mobility_payload = "smash"` or append trigger hooks.
- Windup state lives on the player actor (armed flag + locked target), as in the prototype; the input layer's repeat pulses drive arm/release.
- SFX/VFX per the design document: Shredder's instant break and Execution's kill get distinct feedback from the generic break/kill events (wire to existing audio and combat feedback seams; final sounds/assets are content work).

## Non-Goals

1. No Chain Dash, Shockwave Dash, or other additional Majors — follow-up content once these seams exist.
2. No speed stats (phase 5).
3. No reward-choice UI rework; the three Majors ride the existing overlay.

## Acceptance Criteria

1. Picking Smash swaps the mobility slot's payload for the rest of the run; the windup arm/release/cancel grammar matches the prototype's validated behavior, including no tick refund on cancel.
2. With Guard Shredder held, a back dash hit breaks any guard instantly; with Execution held, a dash hit on a staggered target kills instantly — and the preview badges show both upgraded outcomes before the commit.
3. Smash and a synthetic Chain Dash identifier are mutually exclusive through the existing group mechanism, and the four-Major cap still holds.
4. Windup, Smash impact, Shredder break, and Execution kill are not silent mechanics: they emit the reused or distinct VFX/SFX called for by the resolver result.
