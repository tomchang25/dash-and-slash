# Tick Artifact Rewards

## Goal

Replace the point-balanced reward generator with a Risk-of-Rain-style artifact system: rewards are named artifacts that stack contributions into the run-scoped build store, offered three at a time, with difficulty pressure moved out of per-offer pricing and into milestone curse reveals. This collapses the reward system's most complex code (point pricing, rejection sampling, the nested fallback) into flat rarity-weighted rolls, unifies the Minor/Major split into one artifact concept the player can inspect, and keeps art cost to one placeholder icon per artifact.

## Requirements

1. Every reward card presents one or more artifacts — named, described, icon-bearing pickups that each apply a list of effect contributions to the run build. Most cards present one artifact; milestone `Minor x2` cards bundle two distinct Minor artifacts as a deliberate fallback/baseline. The Minor/Major distinction stops being a type split and becomes data (rarity, stack rule, exclusivity), because the player should read "artifacts of different power," not two parallel systems.
2. Rewards are offered three at a time, always distinct within an offer, rolled flat-random from a rarity pool as the first pass — the point-balancing generator (profiles, target points, rejection sampling, nested fallback) is deleted, because a three-choice artifact roll needs none of it.
3. Difficulty pressure moves out of per-offer pricing into milestone curses: every fifth wave forces one automatic curse reveal after the player picks the milestone reward, so risk is a clear periodic cost rather than a hidden cost bundled into every upside pick or a second downside optimization step.
4. The milestone reward offer is always three enabled choices: slot 1 is a fixed `Minor x2` baseline, while slots 2 and 3 offer behavior-changing Major artifacts when eligible and fall back per slot to `Minor x2` when Major choices are exhausted.
5. A run's owned artifacts and their summed effect totals are inspectable on demand through a simple panel, because a stacking build is only legible if the player can audit what they hold.
6. Art cost stays at one placeholder icon per artifact; readability comes from rarity color and the effect list, not bespoke card art.

## Design

### Reward cadence

| Wave kind                  | Offer                                                                                   |
| -------------------------- | --------------------------------------------------------------------------------------- |
| Normal (1-4, 6-9, ...)     | Minor three-choice                                                                      |
| Milestone (5, 10, 15, ...) | `Minor x2 / Major-or-Minorx2 / Major-or-Minorx2`, then one automatic curse confirmation |

Milestone waves already spawn a milestone elite; the fixed `Minor x2` baseline, Major slots, and forced curse reveal ride that same existing cadence. Majors are therefore first reachable at wave 5 purely by construction — no explicit wave gate is needed. A per-artifact minimum wave survives only as an optional pacing knob to push individual strong artifacts to later milestones, not as the mechanism that makes Majors start at 5.

The first build-defining pick landing at wave 5 (four Minor picks precede it) is a deliberate rhythm — early Minors shape the build, the first Major is an identity spike, and the fixed `Minor x2` slot keeps every milestone testable and useful even when Major availability is thin — but its exact feel is a playtest tuning question, not fixed here.

### The unified artifact

An artifact is one concept carrying identity (name, description, icon), a rarity that drives roll weight and card color, a stack rule (stackable like today's Minors, or unique like today's Majors), an optional exclusivity group, and a curse flag. Its behavior is a list of effect contributions rather than a hard-coded apply body; each contribution is one of a small fixed set:

- a signed amount on a build-store channel — today's Minors, and every curse;
- a mobility-slot payload replacement — today's Smash;
- a mobility-slot trigger activation — today's Guard Shredder, Execution, and Flowing Strike.

Applying an artifact applies each of its contributions in turn. Smash, Guard Shredder, Execution, and Flowing Strike carry over unchanged in behavior; they are simply re-expressed as artifacts whose contribution lists hold a payload or trigger operation instead of belonging to a separate Major class.

The run-wide cap that limits behavior-changing effects today generalizes to a legendary-slot cap keyed on rarity: once the cap is full, milestone Major slots take their `Minor x2` fallback. Offer eligibility is one rule for every artifact — within its minimum wave, not already owned if unique, no exclusivity conflict, and a free legendary slot if it is legendary.

### Downside economy

The four enemy-pressure contributions (future count, health, damage, defense) survive unchanged as the curse pool's payloads; only their delivery moves — from a price subtracted inside a balanced offer to one automatic curse reveal after each milestone reward choice. This preserves the "the player raises their own difficulty" milestone cost that point pricing provided, without any of the pricing machinery or a second curse-choice optimization step, and keeps the pressure channels live rather than orphaning them.

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
| 01    | Artifact data model: the unified artifact plus effect-contribution composition, rarity/stack/exclusivity/curse, legendary-slot cap generalization, and the legacy-player seam removal; absorbs the former consolidation channel-effect collapse | spec   |
| 02a   | Roll collapse: replace the point-balancing generator with a kind-filtered distinct single-artifact picker, fold the choice/effect wrappers into one owned unit, and slim the artifact of its dead roll metadata (split from the 02 sketch)      | spec   |
| 02b   | Cadence and curses: milestone `Minor x2 / Major-or-Minorx2 / Major-or-Minorx2`, automatic curse confirmation, and the curse pool re-homed from the four pressure channels (remaining half of the 02 sketch)                                     | spec   |
| 03    | Build inspection panel: a settings-button-style toggle opening a panel that lists owned artifacts and the current build's summed effect totals                                                                                                  | sketch |

Order: 01 first (the data model everything else reads), then 02a (collapses the roll and finalizes the artifact shape), then 02b and 03 in either order. The `.tres` authoring migration follows 02a, once the artifact shape is final.

The 02 sketch (`tick_artifact_rewards_02_roll_cadence_curses.sketch.md`) is the umbrella for 02a and 02b: 02a owns the roll/picker collapse, 02b owns the cadence and curse pool.

## Acceptance Criteria

1. Every reward offered is an artifact with a name, icon, rarity, and effect list; picking one applies its contributions to the run build.
2. Normal waves offer three distinct Minors; milestone waves offer three enabled reward choices with a fixed `Minor x2` first slot, Major-or-Minorx2 fallback in the other slots, then one automatic curse confirmation.
3. The point-balancing generator and its fallback no longer exist; offers are flat-random distinct picks from a rarity pool.
4. Carried-over Smash, Guard Shredder, Execution, and Flowing Strike behave exactly as before, now expressed as artifacts.
5. The player can open a panel that lists owned artifacts and the summed effect totals of the current build.
6. Enemy pressure enters a run only through milestone curse reveals, and the difficulty curve stays driven by milestone tier plus confirmed curses.
