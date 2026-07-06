# Tick Combat Rework 04: Major Wire And Smash

Skeleton sketch written ahead of the phase; revise against the codebase at phase start. The codebase wins every disagreement.

## Goal

Ship the command-style input grammar, the main Major ability-override wire, and Smash as the first real slot-replacing Major effect.

## Requirements

1. Input intent grammar changes to command-style targeting: holding Alt selects Mobility Mode and releasing it returns to Attack Mode, left click confirms the current mode's target, and right click cancels any pending/armed command. Dash versus Smash is not an intent mode; it is the mobility payload read from the run build, while Phase 04a owns debug controls for swapping payloads on demand.
2. Attack Mode: left click confirms the hovered attack target and executes the normal attack. Mobility Mode with Dash payload: left click confirms the hovered landing cell, then the dash begins and ends in one committed tick using the displayed path and outcomes.
3. Windup grammar: Mobility Mode with Smash payload uses left click on a legal landing cell to arm Smash for one tick (the player's own telegraph and target area light up, enemies act one beat), the next left click releases the locked Smash regardless of the current mouse cell, and right click cancels the armed Smash without refunding the spent windup tick.
4. Smash cancel has a confirmation warning that can be disabled in settings, because cancelling an armed Smash discards a paid windup beat; once disabled, right click cancels directly.
5. The main Major ability-override wire lets real Major effects replace the mobility payload through the run-scoped build store, with Dash remaining the default and Smash becoming the first real replacement.
6. Smash is authored into the same exclusivity group as the future Chain Dash — the group mechanism already exists from the reward rework; this phase only authors the membership.
7. Smash: choose a landing cell within range 3, leap there on release, hit the 3x3 around the locked landing with dash-class damage; windup 1 tick; cooldown longer than dash (initial: 6 ticks vs dash 4, tuned in playtest). Its trade reads as "give up instant mobility for a delayed area guard-breaker".
8. Smash feedback reuses existing combat/audio seams where possible, with temporary modular tween VFX/SFX helpers for windup and impact until final content assets exist.

## Design

- Smash direction rule: landing cell is the attack origin for every target in the area, using the standard angle resolver (no special no-direction case; deferred-list item if playtest disagrees).
- The input grammar deliberately separates intent mode from ability payload. Holding Alt chooses whether left click means normal attack or mobility confirm; the run build chooses whether the mobility confirm executes Dash or Smash. This keeps future perks from adding new input branches when they only replace the mobility payload.
- This phase intentionally ships only one real Major behavior. Guard Shredder and Execution follow in Phase 04b once the mobility override, debug controls, and Smash grammar have proven the main Major wire.

## Sketch (non-normative)

- `RunBuild` gains a real mobility-payload override path that accepts Smash in addition to Dash; triggered-effect storage is deferred to Phase 04b.
- Windup state lives on the player actor (armed flag + locked landing target), as in the prototype; the arena controller interprets left click as arm/release while Smash is the active mobility payload.
- The input layer emits command-intent events (Alt mode set on press/release, left confirm, right cancel) rather than Dash/Smash-specific verbs; the arena root maps Mobility Mode confirms through the run-build payload.
- A small temporary feedback helper owns the tween VFX/SFX calls for Smash windup and Smash impact, so the interim presentation can be replaced later without chasing scattered one-off tweens.

## Non-Goals

1. No Guard Shredder, Execution, Chain Dash, Shockwave Dash, or other additional Majors — Phase 04b owns the two dash-triggered Majors, and later content owns the rest.
2. No speed stats (phase 5).
3. No debug-panel Major toggles; Phase 04a owns the debug surface for all Major effects.
4. No tick-arena reward loop restoration, reward-choice UI rework, wave pacing, or next-wave flow; Phase 04c owns the minimal reward bridge, and Phase 6 owns full run-loop recalibration.

## Acceptance Criteria

1. Holding Alt selects Mobility Mode and releasing it returns to Attack Mode; left click confirms the active mode; right click cancels pending/armed commands.
2. Applying Smash swaps the mobility slot's payload for the rest of the run; in Mobility Mode, left click arms a legal Smash landing for one tick, a later left click releases the locked Smash, and right-click cancel never refunds the spent windup tick.
3. Dash remains a one-click committed default mobility payload in Mobility Mode, with preview and commit still agreeing on landing path and hit outcomes.
4. Smash and a synthetic Chain Dash identifier are mutually exclusive through the existing group mechanism, and the four-Major cap still holds.
5. Smash windup and Smash impact are not silent mechanics: they emit temporary modular VFX/SFX through reused feedback seams.
