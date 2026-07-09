# Tick Artifact Rewards 02a: Roll Collapse

Parent Plan: `tick_artifact_rewards.md`

## Goal

Replace the point-balancing multi-effect roll with a flat, kind-filtered picker that offers three distinct single artifacts, and slim `Artifact` of the roll metadata that only the deleted generator read. This is the first half of child 02; the milestone curse+Major cadence and the curse pool follow in child 02b.

## Summary

Child 01 landed the artifact data model under "Choice A": it kept the point-balancing generator alive and left `Artifact` carrying `point_value`, `magnitude`, and `allowed_profiles` purely to feed it. That generator assembles a random _number_ of effects per card (1–4 by profile), balanced to a target point value. The artifact model does not need any of that — an offer is one artifact, and magnitude scales by picking it repeatedly (in-run stacking), not by rolling a per-offer stack count. This child cuts the machinery the parent plan always meant to delete.

`WaveRewardChoiceGenerator` collapses from a point-balancer to a picker: filter the pool by _kind_ and the child-01 eligibility predicate, shuffle, take three distinct artifacts. Every profile/target-point/rejection-sampling/upside-downside/fallback helper is deleted. `WaveRewardChoice` simplifies to wrap one artifact (the separate `WaveRewardEffect` owned-wrapper folds into it), and the overlay renders the artifact's name and description instead of a profile label and a points line. `Artifact` loses `point_value`, `allowed_profiles`, and `allows_profile()`; `magnitude` stays because it is the per-stack number the description formats. Applying a choice still routes through the child-01 registry (`RunBuild.acquire_artifact` then `Artifact.apply`), so stacking, uniqueness, exclusivity, and the legendary cap are unchanged.

**Behavior after this child:** every wave clear offers three distinct Minor artifacts, each applied at +1 stack; picking the same artifact across waves accumulates stacks through the existing registry. Two deliberate, documented regressions are handed to child 02b and must be visible on approval:

- **Legendaries are temporarily un-offerable.** Smash, Guard Shredder, Execution, and Flowing Strike stay authored in the pool with their data, apply path, and registry intact, but the picker is only ever asked for the Minor kind this child. Child 02b restores them through the milestone Major three-choice. Under the old point generator they reached the player via the AGGRESSIVE profile; that path is gone here and the milestone path does not exist yet.
- **Enemy-pressure artifacts stay Minors for now.** `future_enemy` and the three enemy-pressure artifacts remain in the Minor pool and can be offered on normal waves, exactly as today. Child 02b re-homes them into the curse pool; this child does not touch their classification.

The picker is built with full `kind` support (Minor / Major / curse) even though only the Minor call is wired, so 02b adds the milestone Major and curse calls without reworking the roll. No unit test exercises the roll or overlay, so the offer flow is editor-verified; the changed unit tests only cover the artifact/registry surface from child 01.

## Relational Context

- `WaveRewardChoiceGenerator` is called from exactly one production site: `TickRunController._open_reward_choice()` via `WaveRewardChoiceController.open_reward_choice()`. No other caller rolls choices.
- Call direction is unchanged: the run controller asks the choice controller to open an offer; the choice controller asks the generator to roll and, on selection, applies the picked choice. Only the payload shape changes (single artifact, no target points).
- `WaveRewardChoice` becomes the single owned-offer unit `{ artifact, stacks }`. Its `apply(context)` calls `RunBuild.acquire_artifact(artifact, stacks)` then `artifact.apply(context, stacks)` — the same two-step registry write child 01 defined. `RunBuild` and `Artifact.is_eligible` are owned by child 01 and are **not** modified here.
- Kind classification is derived, not stored: Minor = not curse and not legendary; Major = legendary rarity; curse = `is_curse`. The generator owns this mapping. Only the Minor kind is requested this child.
- `WaveRewardOverlay` reads the choice's artifact display name and its description line; the profile-based `display_name`, the `Points: x / y` line, and `target_points` are removed. The vestigial terrain-mutation note path is out of scope and left as-is.
- `Artifact` drops `point_value`, `allowed_profiles`, and `allows_profile()`. `magnitude` is retained as the description's per-stack amount, not roll metadata. `max_stacks` is retained — it still drives unique-vs-stackable eligibility in child 01's predicate.
- The child-01 unit tests construct `Artifact.new(...)` with a trailing `allowed_profiles` argument (`[WaveRewardChoiceGenerator.Profile.AGGRESSIVE]`). Removing that constructor parameter re-touches all of them; they must drop the argument and the `Profile` reference while keeping their existing assertions.

## Scope

### Included

- Collapse `WaveRewardChoiceGenerator` to a kind-filtered distinct picker; delete all point/profile/fallback machinery.
- Fold `WaveRewardEffect` into a simplified single-artifact `WaveRewardChoice`.
- Slim `Artifact`: remove `point_value`, `allowed_profiles`, `allows_profile()`, and the `Profile` enum on the generator.
- Update the overlay to render artifact name + description; drop the points line and `target_points` threading.
- Update the single call site and delete `_reward_target_points`.
- Re-touch the eight child-01 unit tests to drop the removed constructor argument.

### Excluded

- Milestone curse+Major cadence, the Minor ×2 fallback, and the curse pool — child 02b.
- Rarity-weighted rolls and rarity card color — flat shuffle first; color is later polish.
- Placeholder icons and the inspection panel — child 03.
- `.tres` authoring migration — deferred until the artifact shape is final after this child.
- Any change to `RunBuild`, `Artifact.is_eligible`, or the channel/payload/trigger read API.

## Files to Change

| File                                                                                                                                                                                                                                                                                                | Change Size | Purpose                                                                                                                           |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `game/tick_arena/reward/wave_reward_choice_generator.gd`                                                                                                                                                                                                                                            | Large       | Collapse to a kind-filtered distinct picker; delete point/profile/fallback helpers; add the `RewardKind` enum and classification. |
| `game/tick_arena/reward/wave_reward_choice.gd`                                                                                                                                                                                                                                                      | Medium      | Wrap one artifact + stacks; own `description()` and `apply()`; drop profile/target-point/display-name-by-profile.                 |
| `game/tick_arena/reward/wave_reward_effect.gd`                                                                                                                                                                                                                                                      | Delete      | Folded into `WaveRewardChoice`.                                                                                                   |
| `game/tick_arena/reward/artifact.gd`                                                                                                                                                                                                                                                                | Small       | Remove `point_value`, `allowed_profiles`, `allows_profile()`; keep `magnitude`/`max_stacks`.                                      |
| `game/tick_arena/reward/wave_reward_choice_controller.gd`                                                                                                                                                                                                                                           | Small       | `open_reward_choice()` drops `target_points`; selection applies via `choice.apply()`.                                             |
| `game/tick_arena/reward/wave_reward_overlay.gd`                                                                                                                                                                                                                                                     | Small       | Render artifact name + description; remove the points line and `target_points`.                                                   |
| `game/tick_arena/run/tick_run_controller.gd`                                                                                                                                                                                                                                                        | Small       | Drop `target_points` from the open call; delete `_reward_target_points`.                                                          |
| `test/unit/test_major_effect.gd`, `test_smash_major_effect.gd`, `test_guard_shredder_major_effect.gd`, `test_execution_major_effect.gd`, `test_mobility_free_action_major_effect.gd`, `test_run_build_reward_channels.gd`, `test_speed_and_mobility_cooldown_effects.gd`, `test_run_build_reset.gd` | Small each  | Drop the `allowed_profiles` constructor argument and the `Profile` reference; keep assertions.                                    |

## Execution Outline

1. Slim `Artifact` (remove `point_value`, `allowed_profiles`, `allows_profile()`) and delete the `Profile` enum from the generator, updating the eight tests to the shorter constructor in the same beat so the project compiles.
2. Fold `WaveRewardEffect` into `WaveRewardChoice` as `{ artifact, stacks }` with `description()` and `apply()`, then delete `wave_reward_effect.gd`.
3. Rewrite `WaveRewardChoiceGenerator` as `roll(kind, count, wave_number, context)` — filter by kind + `is_eligible` + `min_wave`, shuffle, take `count` distinct — and expose the three-Minor roll the controller needs.
4. Update `WaveRewardChoiceController.open_reward_choice()` and selection, the overlay formatting, and `TickRunController` (drop `target_points`, delete `_reward_target_points`).
5. Lint every changed `.gd` file; hand the offer/apply flow to manual editor verification (no roll/overlay unit coverage exists).

## Implementation Notes

- **Stacks are not rolled.** Each offered choice is the artifact at one stack; repeated picks accumulate through `RunBuild.acquire_artifact`. Do not reintroduce a per-offer stack count — that is the dynamic-magnitude mechanism being removed.
- **Kind is derived at classification time**, so no field is added to `Artifact`. Keep the mapping in one private helper on the generator.
- **Distinctness is by construction**: shuffling the eligible pool and slicing `count` guarantees no repeat within an offer, replacing the old `picked_ids` guard.
- **Empty-pool edge:** if fewer than `count` artifacts are eligible, return what exists; the overlay already renders a disabled "No reward" card for empty slots. Do not fabricate filler.
- **Do not delete the legendary artifacts or their authoring** — they must remain in the pool for 02b. Only their _offer path_ is dormant.
- **Keep `magnitude` semantics identical** to child 01: `description()` formats `magnitude * stacks`, which at one stack reads exactly as before.

## Edge Cases

| Case                                      | Expected Handling                                                                             |
| ----------------------------------------- | --------------------------------------------------------------------------------------------- |
| Fewer than three eligible Minors          | Offer the eligible ones; remaining overlay slots show the existing disabled "No reward" card. |
| Same artifact already owned and stackable | Still eligible and offerable; a pick increments its registry stacks.                          |
| Legendary artifact in the pool            | Never selected this child — the Minor kind filter excludes it; restored by 02b.               |
| Picking a Minor across several waves      | Registry accumulates stacks; the summed channel total grows accordingly.                      |

## Acceptance Criteria

1. Every wave-clear offer is three distinct single artifacts of the Minor kind, each applied at one stack; none repeats within an offer.
2. No point-balancing, profile, target-point, or fallback code remains; the roll is a filtered shuffle.
3. Picking the same artifact across waves increases its stack count and its summed channel contribution.
4. The offer overlay shows each artifact's name and description with no points line.
5. Lint passes on all changed files and the unit suite passes.
