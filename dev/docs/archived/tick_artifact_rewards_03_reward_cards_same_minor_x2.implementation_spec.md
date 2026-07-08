# Tick Artifact Rewards 03: Reward Cards And Same-Minor x2

Parent Plan: `tick_artifact_rewards.md`

## Goal

Make reward choices read as actual artifact cards instead of text-filled buttons, and make every milestone `Minor x2` fallback/baseline one Minor artifact at two stacks. This keeps each choice visually singular, preserves the milestone reward value, and avoids chained or stacked multi-card UI inside one choice.

## Summary

The current reward overlay already has the right high-level flow, but the visual and data shapes fight the desired card presentation: each choice is rendered by setting `Button.text`, and `Minor x2` is represented as two distinct artifact entries inside one choice. That makes a Slay-the-Spire-style card difficult because one visible card would need to contain two full artifact identities.

This spec changes the contract: a visible reward choice card presents exactly one artifact identity. Normal reward cards are one stack; milestone `Minor x2` cards are the same eligible Minor artifact at `stacks = 2`; Major cards remain one unique Legendary artifact; curse confirmations remain one curse artifact. `WaveRewardChoice` may keep its internal entry array for compatibility, but reward-card display and milestone `Minor x2` generation must use one entry for normal cards, Major cards, curse cards, and `Minor x2` cards.

Card UI is not a placeholder text button. The implementation adds a reusable `WaveRewardCard` scene with a real card layout: cost/stack badge, rarity frame or side strip, title, icon art panel, optional type/rarity caption, and description text. The overlay owns exactly three pre-placed reward card instances for offer mode and reuses the first card for curse-confirmation mode. The implementation should add placeholder artifact icon data now, even if every artifact uses the same placeholder texture in this slice, so later art swaps are data-only.

The expected result is a three-choice reward overlay where each option is visually scannable as one card: common Minor, legendary Major, or curse confirmation. A milestone fallback card should look like the same artifact with an `x2`/stack badge and doubled effect text, not like two cards connected by a chain or two descriptions crammed into one card body.

## Relational Context

- `Artifact` owns authored display identity for reward cards: id, display name, description template, rarity, curse flag, stack rule, magnitude, effects, and after this spec a placeholder-capable icon texture. Runtime reward UI reads this data; it does not synthesize artifact identity.
- `WaveRewardChoiceGenerator` still rolls distinct eligible artifact identities for a requested kind. It should not know about UI card layout, and it should not create fake duplicate artifacts to express `x2`.
- `TickRunController` owns milestone offer assembly. It chooses whether a card is single-stack or two-stack before display, so `WaveRewardOverlay` only renders prepared choices and does not decide cadence.
- `Minor x2` changes from two distinct Minor artifact entries to one Minor artifact entry with `stacks = 2`. Applying that choice must still call `RunBuild.acquire_artifact(artifact, 2)` and then `Artifact.apply(context, 2)`, so owned stack count and channel totals both reflect two stacks of the same artifact.
- `WaveRewardChoice` owns choice display data at the reward-flow layer: title, description, artifacts/entries, and stack count. It should expose enough read API for card UI to render without reaching into raw dictionaries.
- `WaveRewardOverlay` owns reward-offer presentation and selection signals. It should render cards by calling a narrow public API on three fixed `WaveRewardCard` children, not by assigning multiline `Button.text`.
- `WaveRewardCard` owns visual formatting only. It emits or forwards a pressed signal, stores a supplied `WaveRewardChoice`, and paints its own pre-placed nodes. It does not apply rewards, roll artifacts, pause the tree, or advance waves.
- `RunBuild` remains the single authority for owned artifact stacks and effect totals. Do not add a UI-side build cache, card-side stack tracker, or separate reward-history store.
- Card styling establishes shared reward UI language. Static structure belongs in `.tscn`; reusable static card states should live in theme resources or scene subresources, while only live state selection happens in GDScript.

## Scope

### Included

- Change milestone `Minor x2` generation to one eligible Minor at two stacks.
- Add artifact icon data with a shared placeholder icon assigned to current artifacts.
- Replace text-button reward choices with reusable card components in the wave reward overlay.
- Render stack count, title, icon, rarity/curse visual state, and stack-scaled description.
- Update focused reward-choice and milestone-sequence tests for same-Minor `x2` semantics.

### Excluded

- Chain-linked, vertically stacked, sliding, or hover-expanded multi-card UI.
- Unique bespoke art per artifact; all artifacts may share the same placeholder icon in this slice.
- Full build inspection panel work, now child 04.
- Rarity roll weights, deck-building economy, permanent progression, or new reward content.
- Any change to combat projection, wave scaling formulas, or RunBuild channel read semantics.

## Files to Change

| File                                                                             | Change Size  | Purpose                                                                                                                                                                                             |
| -------------------------------------------------------------------------------- | ------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `data/rewards/definitions/artifact.gd`                                           | Small        | Add an exported icon texture field used by reward cards and later inspection rows.                                                                                                                  |
| `data/rewards/icons/artifact_placeholder.svg` or nearest domain-owned icon asset | New Small    | Provide the one placeholder artifact icon this plan allows.                                                                                                                                         |
| `data/rewards/artifacts/*.tres`                                                  | Medium       | Assign the placeholder icon to every existing artifact resource without changing effects, rarity, curse flags, magnitudes, or stack rules.                                                          |
| `game/tick_arena/reward/wave_reward_choice.gd`                                   | Medium       | Keep or simplify the choice value object so card UI can read one primary artifact, stack count, title, and stack-scaled description; update `Minor x2` title/body behavior away from bundled names. |
| `game/tick_arena/run/tick_run_controller.gd`                                     | Small        | Change `Minor x2` assembly from two distinct Minors to one eligible Minor returned as a two-stack choice, including Major fallback slots.                                                           |
| `game/tick_arena/reward/wave_reward_card.tscn`                                   | New Medium   | Define the reusable card component node tree, placeholder preview content, intrinsic card size, and fixed visual regions.                                                                           |
| `game/tick_arena/reward/wave_reward_card.gd`                                     | New Medium   | Apply a `WaveRewardChoice` to the card nodes, select visual state, and forward card presses without applying rewards.                                                                               |
| `game/tick_arena/reward/wave_reward_overlay.gd`                                  | Medium       | Replace button text formatting with card setup/visibility/selection for three-choice offers and one-card confirmations.                                                                             |
| `game/tick_arena/tick_arena.tscn`                                                | Medium       | Instance three card components in the reward overlay and wire unique names for the overlay script.                                                                                                  |
| `global/theme/main_theme.tres`                                                   | Small/Medium | Add card-relevant type variations or reusable styles only where needed for stable reward-card visuals.                                                                                              |
| `test/unit/test_wave_reward_choice.gd`                                           | Small        | Replace distinct-bundle expectations with same-artifact two-stack apply/display expectations.                                                                                                       |
| `test/unit/test_tick_run_controller_reward_sequence.gd`                          | Small        | Assert milestone `Minor x2` choices carry one Minor artifact at two stacks and fallback slots use the same shape.                                                                                   |

## Execution Outline

1. Add artifact icon support first: extend `Artifact`, add the domain-owned placeholder texture, and update every existing `.tres` so card rendering can rely on `artifact.icon` being present.
2. Update `WaveRewardChoice` tests and implementation so a one-entry two-stack choice formats as one artifact card with doubled magnitude, while existing single-stack Major/curse/Minor behavior still formats as one artifact.
3. Change `TickRunController` milestone assembly to roll one eligible Minor for each `Minor x2` slot and create `WaveRewardChoice.single(artifact, 2)`; update milestone tests before touching card visuals.
4. Create `WaveRewardCard` as a reusable component scene with previewable default content, fixed card dimensions, and a script using the standard `setup()` / `_apply()` pattern.
5. Replace the overlay's three `Button` nodes with three pre-placed card instances in `tick_arena.tscn`, then update `WaveRewardOverlay` to call card setup methods, show/hide cards per mode, and map pressed cards back to `_choices[index]`.
6. Add or adjust theme/style resources so common, legendary, and curse cards are visually distinct without creating one-off runtime StyleBoxes in GDScript.
7. Run standards lint on changed `.gd`, `.tscn`, `.tres`, and tests, then run the focused reward unit tests.

## Implementation Notes

- The card component should be a real scene, not a function that builds Control nodes in GDScript. Fixed elements include an outer clickable root, title label, icon texture region, description label, stack badge, and a rarity/curse indicator.
- `WaveRewardCard.setup(choice: WaveRewardChoice, disabled := false)` should store the choice and refresh when ready. It must support setup before or after being added to the scene tree.
- Use `TextureRect` for the artifact icon. If `artifact.icon` is null despite authored data, show the placeholder icon and log a dev-visible error rather than leaving the card blank.
- Description text should use the existing stack-scaled formatting path. For example, a `Fleet Step` two-stack card should show the same card title and icon as `Fleet Step`, a visible `x2` stack badge, and an effect line equivalent to `+2 Speed`.
- The card should not show a separate "Minor x2" title when it has a real artifact identity. If the UI needs to communicate the milestone bonus, use the stack badge or a small caption, not a second pseudo-artifact name.
- Curse cards should use the artifact's real display name and icon with a curse visual state. Do not create a separate curse wrapper card with unrelated copy.
- The overlay should keep array index semantics simple: card 0 maps to `_choices[0]`, card 1 to `_choices[1]`, card 2 to `_choices[2]`. Confirmation mode sets up card 0 and hides cards 1 and 2.
- If `WaveRewardChoice.bundle()` remains for compatibility, do not use it for milestone `Minor x2`. Tests should make this regression obvious.
- Keep card dimensions stable. Long descriptions should autowrap within the description region and must not resize the card or push the stack badge/title/icon out of place.
- Do not introduce card hover reveal, drag, slide, carousel, nested cards, or chained cards in this slice.

## Edge Cases

| Case                                             | Expected Handling                                                                                                                                                                                                    |
| ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Normal reward offer                              | Shows three single-stack Minor artifact cards with unique identities when enough eligible Minors exist.                                                                                                              |
| Milestone first slot                             | Shows one eligible Minor artifact card with `x2` stack state and doubled effect text.                                                                                                                                |
| Major fallback slot with no eligible Major       | Shows one eligible Minor artifact card with `x2` stack state, not a disabled card and not two chained Minor cards.                                                                                                   |
| A two-stack Minor is selected when already owned | `RunBuild` increments that artifact's owned stack count by 2 and applies two stacks of its effects.                                                                                                                  |
| Fewer eligible Minors than requested             | The offer degrades to fewer prepared choices only where existing generator behavior already allows it; it must not fabricate a second artifact or duplicate a visual card outside the selected choice's stack count. |
| Artifact icon missing from data                  | The card displays the shared placeholder and reports a developer-visible data error.                                                                                                                                 |
| Long artifact description                        | Text wraps inside the card body and the card keeps its fixed footprint.                                                                                                                                              |
| Curse confirmation                               | Shows one curse-styled artifact card; cards 2 and 3 are hidden and cannot be selected.                                                                                                                               |

## Acceptance Criteria

1. Reward choices are displayed as structured artifact cards with title, icon, description, rarity/curse visual state, and stack badge when stacks exceed one.
2. Normal reward offers still present up to three distinct single-stack Minor artifact choices.
3. Every milestone `Minor x2` slot presents one Minor artifact at two stacks, not two different Minor artifacts in one choice.
4. Selecting a `Minor x2` card increases the selected artifact's owned stack count by 2 and applies two stacks of its effects.
5. Major fallback slots use the same one-artifact two-stack `Minor x2` shape.
6. Card visuals are implemented through reusable scene components and theme/scene styling, not through multiline `Button.text` placeholders.
7. Existing Major and curse reward behavior still applies through the same reward choice controller flow.
8. Focused reward-choice and milestone-sequence tests cover same-Minor `x2` semantics.
