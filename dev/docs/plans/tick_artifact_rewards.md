# Tick Artifact Rewards

## Goal

Replace the point-balanced reward generator with a Risk-of-Rain-style artifact system: every reward is an artifact that stacks contributions into the run-scoped build store, offered three at a time, with difficulty pressure moved out of per-offer pricing and into milestone curses. This collapses the reward system's most complex code (point pricing, rejection sampling, the nested fallback) into flat rarity-weighted rolls, unifies the Minor/Major split into one artifact concept the player can inspect, and keeps art cost to one placeholder icon per artifact.

## Requirements

1. Every reward is one artifact — a named, described, icon-bearing pickup that applies a list of effect contributions to the run build. The Minor/Major distinction stops being a type split and becomes data (rarity, stack rule, exclusivity), because the player should read "artifacts of different power," not two parallel systems.
2. Rewards are offered three at a time, always distinct within an offer, rolled flat-random from a rarity pool as the first pass — the point-balancing generator (profiles, target points, rejection sampling, nested fallback) is deleted, because a three-choice artifact roll needs none of it.
3. Difficulty pressure moves out of per-offer pricing into milestone curses: every fifth wave forces a curse three-choice (all downside) alongside a Major three-choice, so risk is a deliberate periodic decision rather than a hidden cost bundled into every upside pick.
4. The Major three-choice offers behavior-changing artifacts capped per run; when none is available (all owned, capped, or excluded) it falls back to offering two Minors, so a milestone never wastes its reward beat.
5. A run's owned artifacts and their summed effect totals are inspectable on demand through a simple panel, because a stacking build is only legible if the player can audit what they hold.
6. Art cost stays at one placeholder icon per artifact; readability comes from rarity color and the effect list, not bespoke card art.

## Design

### Reward cadence

| Wave kind                  | Offer                                                                      |
| -------------------------- | -------------------------------------------------------------------------- |
| Normal (1-4, 6-9, ...)     | Minor three-choice                                                         |
| Milestone (5, 10, 15, ...) | Curse three-choice (downside) + Major three-choice, with Minor ×2 fallback |

Milestone waves already spawn a milestone elite; the curse+Major beat rides that same existing cadence. Majors are therefore first reachable at wave 5 purely by construction — no explicit wave gate is needed. A per-artifact minimum wave survives only as an optional pacing knob to push individual strong artifacts to later milestones, not as the mechanism that makes Majors start at 5.

The first build-defining pick landing at wave 5 (four Minor picks precede it) is a deliberate rhythm — early Minors shape the build, the first Major is an identity spike — but its exact feel is a playtest tuning question, not fixed here.

### The unified artifact

An artifact is one concept carrying identity (name, description, icon), a rarity that drives roll weight and card color, a stack rule (stackable like today's Minors, or unique like today's Majors), an optional exclusivity group, and a curse flag. Its behavior is a list of effect contributions rather than a hard-coded apply body; each contribution is one of a small fixed set:

- a signed amount on a build-store channel — today's Minors, and every curse;
- a mobility-slot payload replacement — today's Smash;
- a mobility-slot trigger activation — today's Guard Shredder, Execution, and Flowing Strike.

Applying an artifact applies each of its contributions in turn. Smash, Guard Shredder, Execution, and Flowing Strike carry over unchanged in behavior; they are simply re-expressed as artifacts whose contribution lists hold a payload or trigger operation instead of belonging to a separate Major class.

The run-wide cap that limits behavior-changing effects today generalizes to a legendary-slot cap keyed on rarity: once the cap is full, the milestone Major three-choice takes its Minor ×2 fallback. Offer eligibility is one rule for every artifact — within its minimum wave, not already owned if unique, no exclusivity conflict, and a free legendary slot if it is legendary.

### Downside economy

The four enemy-pressure contributions (future count, health, damage, defense) survive unchanged as the curse pool's payloads; only their delivery moves — from a price subtracted inside a balanced offer to a chosen curse at each milestone. This preserves the "the player raises their own difficulty" decision that point pricing provided, without any of the pricing machinery, and keeps the pressure channels live rather than orphaning them.

## Non-Goals

1. No weighted rarity tuning, deck-building economy, or permanent progression in this pass — flat random first, weights later.
2. No manual terrain targeting, obstacle-grid work, or curse content beyond re-homing the existing four pressure channels.
3. No full HUD refactor — the simple inspection panel here is the MVP that the later HUD refactor absorbs.
4. No change to how the build store projects totals into player stats, wave scaling, or combat — artifacts write the same channels those readers already consume.
5. No new Major behaviors — Smash, Guard Shredder, Execution, and Flowing Strike carry over as artifacts unchanged.

## Design authority note

This plan supersedes the reward-side of the tick arena structure consolidation: the former channel-effect collapse and the roll-fallback rewrite are folded into this system's children (the data model absorbs the collapse; the fallback is deleted with the generator). Consolidation retains only its combat and run-loop cleanups.

## Children

Child documents live alongside this plan as `tick_artifact_rewards_0N_*.sketch.md`. They are optional exploration notes for child slices; implementation always runs from child implementation specs written against the live codebase when each child is next to land.

| Child | Focus                                                                                                                                                                                                                                           | Form   |
| ----- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ |
| 01    | Artifact data model: the unified artifact plus effect-contribution composition, rarity/stack/exclusivity/curse, legendary-slot cap generalization, and the legacy-player seam removal; absorbs the former consolidation channel-effect collapse | sketch |
| 02    | Roll, cadence, and curses: rarity-weighted distinct three-choice, the milestone curse+Major beat with Minor ×2 fallback, the curse pool built from the pressure channels, and point-generator removal                                           | sketch |
| 03    | Build inspection panel: a settings-button-style toggle opening a panel that lists owned artifacts and the current build's summed effect totals                                                                                                  | sketch |

Order: 01 first (the data model everything else reads), then 02 and 03 in either order.

## Acceptance Criteria

1. Every reward offered is an artifact with a name, icon, rarity, and effect list; picking one applies its contributions to the run build.
2. Normal waves offer three distinct Minors; milestone waves offer a curse three-choice plus a Major three-choice that falls back to two Minors when no Major is available.
3. The point-balancing generator and its fallback no longer exist; offers are flat-random distinct picks from a rarity pool.
4. Carried-over Smash, Guard Shredder, Execution, and Flowing Strike behave exactly as before, now expressed as artifacts.
5. The player can open a panel that lists owned artifacts and the summed effect totals of the current build.
6. Enemy pressure enters a run only through chosen curses, and the difficulty curve stays driven by milestone tier plus chosen curses.
