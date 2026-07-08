# Tick Artifact Rewards 02b: Cadence And Curses

Parent Plan: `tick_artifact_rewards.md`

## Goal

Complete the remaining child 02 reward behavior by keeping normal waves on Minor three-choice offers, making every milestone offer testable as `Minor x2 / Major-or-Minorx2 / Major-or-Minorx2`, and moving enemy-pressure artifacts into an automatic post-selection curse reveal. Difficulty pressure reaches the run only through the forced milestone curse, while the milestone reward choice itself stays a clean upside decision.

## Summary

Child 02a already collapsed the point-balanced generator into `WaveRewardChoiceGenerator.roll(kind, count, wave_number, context)`, and the generator already derives Minor, Major, and curse pools from `Artifact` data. The live gap is cadence and choice shape: `WaveRewardChoiceController.open_reward_choice()` always rolls three single Minor artifacts, `WaveRewardChoice` wraps one artifact, and `TickRunController._on_reward_choice_applied()` always unlocks input and starts the next wave after one selected card.

This spec changes milestone cadence to a single visible three-choice reward offer followed by one forced curse confirmation. On waves 5, 10, 15, 20, and every later milestone, slot 1 is always a `Minor x2` bundle. Slots 2 and 3 try to use eligible Major artifacts; each missing Major slot is filled by another `Minor x2` bundle, so milestone offers always present three enabled choices. A full Major pool produces `Minor x2 / Major / Major`; one eligible Major produces `Minor x2 / Major / Minor x2`; zero eligible Majors produces `Minor x2 / Minor x2 / Minor x2`.

`Minor x2` means two distinct Minor artifacts shown inside one choice card and applied one after the other at one stack each. It is not a two-stack copy of one Minor. This requires `WaveRewardChoice` to become a small bundle value object that can hold one or more artifacts while preserving the existing acquire-then-apply path for every contained artifact.

After the player picks any milestone reward option, the run automatically rolls one curse artifact and shows it as a confirmation/reveal, not as a choice. The player acknowledges the curse, the curse applies through the same reward application path, then the next wave starts. This keeps the curse as the milestone cost instead of turning the downside into a second optimization step.

The four pressure artifacts already exist in the default pool and already write the correct `RunBuild` channels: future enemy count, future enemy health, future enemy damage, and future enemy defense. They should keep those effects and scale conventions, but flip to `is_curse = true` so the generator classifies them as curses instead of Minors. Positive player-growth Minors remain in the normal-wave and `Minor x2` pools, and Legendary artifacts remain the Major pool.

## Relational Context

- `WaveController` owns milestone detection and emits the completed wave number plus milestone flag; it does not roll rewards, apply artifacts, or know about curses.
- `TickRunController` owns between-wave sequencing: it locks input on wave completion, starts the reward overlay after the banner, chooses normal versus milestone cadence, opens the forced curse confirmation after a milestone reward pick, and only starts the next wave after the final required confirmation.
- `WaveRewardChoiceController` owns displaying one visible offer/confirmation, pausing while it is open, applying the selected or confirmed `WaveRewardChoice`, hiding the overlay, and emitting completion for that one UI step. It should not decide wave milestone cadence.
- `WaveRewardChoiceGenerator` owns pool filtering only. Its kind mapping stays derived: curse = `is_curse`, Major = Legendary rarity and not curse, Minor = non-curse non-Legendary. Do not add a new artifact-kind field.
- `WaveRewardChoice` changes from `{ artifact, stacks }` to a bundle of one or more `{ artifact, stacks }` entries. `apply(context)` must still call `RunBuild.acquire_artifact()` before `Artifact.apply()` for each entry; no milestone, fallback, or curse path may bypass this write contract.
- `Minor x2` bundles are assembled by the reward controller or run controller from two distinct Minor choices returned by the generator. Do not represent `Minor x2` as one artifact with `stacks = 2`.
- `RunBuild` remains the single authority for channel totals, owned artifacts, legendary cap, and exclusivity. Curses write the same pressure channels Minors temporarily wrote after 02a; `WaveController` continues to read those totals when computing future wave pressure.
- Major fallback is per slot and happens before display. If a Major slot cannot be filled, that slot becomes an enabled `Minor x2` bundle rather than a disabled card.
- The forced curse is a confirmation step, not a choice. If no curse can be rolled, show a developer-visible error path and continue only with an explicit no-curse confirmation instead of silently skipping the milestone cost.
- The old terrain-mutation argument is still only a compatibility value for the shared overlay signature in the tick arena; this child does not revive terrain mutation.

## Scope

### Included

- Normal wave reward cadence: one Minor three-choice.
- Milestone reward cadence: three enabled choices where slot 1 is always `Minor x2` and slots 2-3 are Major or `Minor x2` fallback.
- Forced post-milestone curse reveal/confirmation after any milestone reward selection.
- Curse-pool migration for the four existing pressure artifacts.
- Bundle support in reward choices so one card can show/apply two distinct Minor artifacts.
- A reusable overlay title/confirmation hook so normal rewards, milestone rewards, and curse reveals are visibly distinct.
- Focused tests or verification for generator classification, `Minor x2` bundle semantics, and milestone sequencing.

### Excluded

- Rarity weighting, card color polish, icons, chain-link paired-card UI, and full reward-card visual redesign.
- Player choice among curses; the chosen design is automatic curse reveal/confirmation.
- New curse content beyond the four existing pressure channels.
- Any change to `RunBuild` pressure readers, `WaveScaling`, enemy spawning formulas, or combat projection.
- Build inspection panel work from child 03.
- Removing the vestigial terrain-mutation compatibility parameter unless the implementation naturally replaces it across all current call sites.

## Files to Change

| File                                                                                                     | Change Size | Purpose                                                                                                                                                                                                                     |
| -------------------------------------------------------------------------------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `game/tick_arena/reward/wave_reward_choice_generator.gd`                                                 | Small       | Mark the four pressure artifacts as curses while preserving their effects, magnitudes, stackability, and percent multipliers; keep flat distinct rolls by kind.                                                             |
| `game/tick_arena/reward/wave_reward_choice.gd`                                                           | Medium      | Change the value object from one artifact to a bundle of one or more artifact entries; expose display/description helpers for single-artifact, `Minor x2`, and curse-confirmation cards.                                    |
| `game/tick_arena/reward/wave_reward_choice_controller.gd`                                                | Medium      | Let callers show prepared choices as an offer or confirmation, apply the selected/confirmed bundle, and keep pause/unpause scoped to one UI step.                                                                           |
| `game/tick_arena/reward/wave_reward_overlay.gd`                                                          | Medium      | Set the existing title label from the UI request and support a confirmation mode for one forced curse while keeping three-card choice mode for reward offers.                                                               |
| `game/tick_arena/run/tick_run_controller.gd`                                                             | Medium      | Build normal and milestone offers, fill milestone Major slots with `Minor x2` fallback, open the forced curse confirmation after milestone selection, and advance only after the final UI step.                             |
| `test/unit/test_wave_reward_choice_generator.gd`                                                         | New Small   | Cover default-pool classification: pressure artifacts roll as curses, normal Minors exclude pressure and Legendary artifacts, and Majors respect the existing eligibility cap.                                              |
| `test/unit/test_wave_reward_choice.gd`                                                                   | New Small   | Cover bundle apply semantics: a `Minor x2` choice applies two distinct artifacts through the owned-artifact registry at one stack each.                                                                                     |
| `test/unit/test_tick_run_controller_reward_sequence.gd` or nearest practical reward-controller test seam | New/Small   | Cover or document the milestone sequence: first slot is always `Minor x2`, missing Major slots are filled by `Minor x2`, curse confirmation follows any milestone reward, and the next wave starts only after confirmation. |

## Execution Outline

1. Add focused generator coverage first, using the default artifact pool and a fresh `WaveRewardContext`, then flip the four pressure artifacts to `is_curse = true` and adjust names/descriptions only if needed for readable curse presentation.
2. Convert `WaveRewardChoice` into a bundle value object and add tests proving two distinct Minor artifacts in one choice apply as two one-stack acquisitions, not one two-stack acquisition.
3. Generalize the reward controller/overlay boundary so the run controller can pass prepared choices for a normal three-choice offer, a milestone three-choice offer, or a one-card curse confirmation with distinct title text.
4. Rework `TickRunController` reward state so the wave-complete banner opens either a normal Minor offer or a milestone offer assembled as fixed slot 1 `Minor x2`, then two Major slots with per-slot `Minor x2` fallback.
5. After any milestone reward pick applies, roll one curse, show it as confirmation, apply it on confirmation, and only then unlock input and start the next wave.
6. Clear pending reward/confirmation state in restart and death cleanup so stale milestone steps cannot reopen or apply after the run resets.
7. Add the narrowest practical cadence test. If direct scene-level unit coverage is too costly, keep generator and bundle tests in code and record manual editor verification for wave 4 to wave 5 completion, fixed first `Minor x2` slot, Major-short fallback slots, curse confirmation, and wave 6 start.
8. Run the standards linter on changed `.gd`, `.tscn` if touched, and test files; run the relevant unit tests for reward generator/controller changes.

## Implementation Notes

- Keep milestone state explicit in `TickRunController`, for example named states for no pending offer, awaiting milestone reward selection, awaiting forced curse confirmation, and finishing reward flow. A single boolean is easy to invert incorrectly after restarts or death cleanup.
- Restart and death cleanup must clear any pending reward-sequence state alongside hiding the overlay and unpausing the tree.
- Milestone reward and forced curse rolls both use the completed wave number, not the next wave number. Do not call `start_next_wave()` until after the curse confirmation applies.
- A `Minor x2` bundle should request two eligible Minors from the same flat Minor pool. If fewer than two Minors are available, build the bundle from whatever exists and show the missing line as unavailable; normal content volume should make this rare, but the code should not crash.
- Distinctness for a `Minor x2` bundle is internal to that card. The fixed `Minor x2` slot and fallback `Minor x2` slots may contain overlapping Minors across different cards because the player can only choose one card.
- Curses should remain stackable unless the implementation deliberately changes max-stack semantics across all artifacts. The current `max_stacks` logic treats values greater than 1 as repeatable and does not enforce an upper stack cap.
- Percent pressure channels keep their existing scale: health and damage descriptions show `+5%`, while `ChannelArtifactEffect` records `0.05` through the `0.01` multiplier.
- Pure add-enemy pressure in the Minor pool is a 02a transition artifact, not the target design. After this child, `future_enemy` must only appear through the forced curse reveal.

## Edge Cases

| Case                                                               | Expected Handling                                                                                                                                                |
| ------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Normal completed wave                                              | Shows three single Minor choices; picking one applies it and starts the next wave.                                                                               |
| Milestone completed wave with at least two eligible Majors         | Shows `Minor x2 / Major / Major`; picking any option then opens one forced curse confirmation.                                                                   |
| Milestone completed wave with one eligible Major                   | Shows `Minor x2 / Major / Minor x2`; all three slots are enabled.                                                                                                |
| Milestone completed wave with zero eligible Majors                 | Shows `Minor x2 / Minor x2 / Minor x2`; all three slots are enabled.                                                                                             |
| `Minor x2` roll finds fewer than two eligible Minors               | The bundle shows and applies the eligible Minor(s) without duplicating one artifact into two stacks; missing content is visible rather than silently fabricated. |
| Forced curse roll succeeds                                         | Shows one curse confirmation; confirming applies the curse and starts the next wave.                                                                             |
| Forced curse roll finds no eligible curse                          | Shows an explicit no-curse/dev-error confirmation path and starts the next wave only after confirmation.                                                         |
| Restart or death while a reward offer or curse confirmation exists | Hides the overlay, clears pending reward state, unpauses the tree, and prevents stale callbacks from opening or applying rewards.                                |
| Pressure artifacts after migration                                 | Never appear in normal Minor offers or `Minor x2` bundles; appear only in forced curse reveals and still increase future wave pressure through `RunBuild`.       |

## Acceptance Criteria

1. Normal wave clears offer three distinct single Minor artifacts and advance to the next wave after one selection.
2. Every milestone wave clear offers exactly three enabled reward choices, with slot 1 always being `Minor x2`.
3. Milestone slots 2 and 3 use eligible Majors when available and otherwise become enabled `Minor x2` fallback choices.
4. `Minor x2` choices contain two distinct Minor artifacts when two are available, and choosing one applies both artifacts at one stack each.
5. After any milestone reward selection, the run shows one automatic curse confirmation before starting the next wave.
6. The four enemy-pressure artifacts are no longer available from normal Minor offers or `Minor x2` bundles and can only be acquired through forced curse reveals.
7. Confirmed curses apply their existing pressure effects to future waves through the run build, without changing wave-scaling formulas.
8. Restart and death cleanup cannot leave a stale pending reward step, paused tree, or hidden overlay callback.
9. Standards lint and the relevant reward/wave unit tests pass.
