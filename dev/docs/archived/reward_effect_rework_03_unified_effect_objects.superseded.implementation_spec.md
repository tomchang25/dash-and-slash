# Reward Effect Rework — Unified Effect Objects (SUPERSEDED)

> **Superseded.** This original Phase 3 approach scoped the applied-effect store under `Player` and left enemy-pressure routing on a separate wave callback. It was replaced before implementation by a unified run-scoped modifier store (`RunBuild`) that both `Player` and `WaveController` project from via a channel-keyed pull model — which also absorbs the future-enemy-count effect's routing. The current Phase 3 spec lives at `dev/docs/plans/reward_effect_rework_03_unified_effect_objects.implementation_spec.md`. Kept here for the reasoning on the projection/clamp equivalence and the abstract-effect hierarchy, both of which carried forward unchanged.

## Goal

Migrate the reward pipeline from a single effect-type enum branched on by three separate switch statements to one self-contained object per effect that owns its own offer-eligibility and application, applying into a run-scoped store the player's stats are projected from. Behavior-preserving: every effect that exists today is offered under the same risk tiers and applies identically after the migration.

## Relational Context

- `WaveRewardEffectDefinition` (`game/scenes/stages/rewards/wave_reward_effect_definition.gd`) is today a single concrete data class with a `Kind` enum. Three sites branch on that enum: `WaveRewardChoiceGenerator._is_definition_applicable()` (`wave_reward_choice_generator.gd`, decides offer-eligibility from run context), `WaveRewardApplier._apply_effect()` (`wave_reward_applier.gd`, decides what applying does), and the pool builder `_make_default_effect_definitions()` (constructs every definition). After this change the definition class is an abstract base with one subclass per effect; each subclass owns an `is_applicable(context)` and an `apply(context, stacks)`, and the `Kind` enum and all three switch statements are dissolved. Phase 2 already removed the two terrain enum members; this phase removes the rest.
- The prototype/instance split stays: the pool holds definition prototypes (metadata + behavior), and `WaveRewardEffect` (`wave_reward_effect.gd`) stays the thin instance wrapping a prototype plus a chosen `stacks`. The roll's point-budget math in the generator operates on the wrapper's `total_points()`/`total_magnitude()` and must keep working unchanged — this migration changes dispatch, not the rolling algorithm or its balance metadata.
- Balance numbers (point value, per-stack magnitude, allowed profiles, min wave, stack cap, display strings) stay authored in one place: the pool builder constructs each subclass with its numbers as constructor arguments. Do not move these numbers into the subclasses as hardcoded constants — centralized tuning is a requirement, and scattering the numbers defeats it.
- `WaveRewardApplier` today owns the mutation-authority gateway: it holds references to the terrain authority (`GridArena`), the player-stat owner (`Player`), and a wave/run mutation callback, and routes each effect to the right one. After this change the applier becomes a thin loop that asks each effect to apply itself against a context bundle carrying those same owners. The context is where ownership discipline now concentrates — an effect must reach only the owner it legitimately mutates. GDScript will not enforce this narrowing structurally, so the context should expose each owner through as narrow a surface as practical and the convention must be stated in the effect base class's contract, per `dev/standards/runtime_ownership.md`.
- `Player` (`game/entities/player/player.gd`) is the sole owner of run-local player stats via the seven narrow mutator methods and their getters; `_run_stats` is never touched from outside `player.gd`. This phase introduces a run-scoped applied-effect store owned by `Player` (a new run-build owner object). Minor stat effects apply by recording themselves in the store; the seven getters project the authored base plus the store's recomputed contribution. Every existing clamp/floor applies at the projection's final combined value, not per stored entry — a floor is a property of the resolved stat, not of one contribution, so clamping per entry would silently drop part of a later contribution once an earlier one reached the floor.
- Two of the seven mutations carry a side effect that must survive the projection change: reducing dash cooldown also re-clamps any in-flight cooldown to the newly projected maximum, and adding max health also pushes the same delta into the `Health` component so current and max stay in sync. The max-health delta is exactly the amount added in that call, independent of the store's running total.
- `WaveRewardChoiceController` (`wave_reward_choice_controller.gd`) builds the roll context dictionary (`grid`, `player`) and hands it to the generator; the applier receives its owners at construction from `DashAndSlashArena` (`dash_and_slash_arena.gd`). Both context assembly points must carry whatever the effect objects' `is_applicable`/`apply` now read — for existing effects that is the grid and the player.

## Scope

### Included

- Convert the effect definition class into an abstract base plus one subclass per existing effect, each owning `is_applicable(context)` and `apply(context, stacks)`.
- Dissolve the `Kind` enum and the three switch statements that branched on it.
- Reduce `WaveRewardApplier` to a uniform per-effect apply loop over a context bundle.
- Introduce the run-scoped applied-effect store owned by `Player`, and reproject the seven stat getters from it, preserving every clamp and both documented side effects.

### Excluded

- Any new effect (enemy pressure, real behavior-changing effects) — Phases 4 and 5.
- The Major cap/exclusivity specialization — Phase 5.
- Any change to the roll algorithm, point-budget constraints, or per-effect balance numbers.
- Any player-facing effect-summary display.

## Files to Change

| File                                                                  | Change Size | Purpose                                                                                                                              |
| --------------------------------------------------------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `game/scenes/stages/rewards/wave_reward_effect_definition.gd`         | Large       | Become the abstract effect base: metadata fields, virtual `is_applicable`, abstract `apply`; drop the `Kind` enum.                   |
| New effect subclass files under `game/scenes/stages/rewards/effects/` | Medium      | One self-contained class per existing effect (terrain-count-independent player stat effects, future-enemy-count, major placeholder). |
| `game/scenes/stages/rewards/wave_reward_choice_generator.gd`          | Medium      | Pool builder constructs subclasses; `_is_definition_applicable` becomes `definition.is_applicable(context)`; roll math untouched.    |
| `game/scenes/stages/rewards/wave_reward_applier.gd`                   | Medium      | Collapse `_apply_effect` switch into a uniform `effect.apply(context)` loop over a context bundle.                                   |
| `game/scenes/stages/rewards/wave_reward_effect.gd`                    | Small       | Delegate application to its prototype; keep points/magnitude/description.                                                            |
| `game/entities/player/player.gd`                                      | Medium      | Own the applied-effect store; reproject the seven getters; preserve clamps and both side effects.                                    |
| New run-build/store files under `game/entities/player/run_build/`     | Medium      | Hold the applied-effect store and the projected-stat cache; pure data, no engine dependency.                                         |
| `test/unit/test_player_stats.gd`                                      | Small       | Update applier/effect construction to the new shapes; add projection-and-clamp coverage. No existing assertion should change result. |

## Implementation Notes

- Read `dev/skills/gdscript_abstract.md` before introducing the abstract base and `@abstract apply`.
- Recompute the projected-stat cache from scratch on every store write rather than adjusting incrementally — this is what makes storage safe for a future effect that replaces rather than adds, and it is cheap given a handful of entries per run.
- Keep the abstract base's `is_applicable` defaulting to true so effects with no context dependency (e.g. future-enemy-count, the placeholder) need not override it, matching the current always-true switch arms.
- The context bundle replaces the applier's constructor-held owner references and the generator's context dictionary with one shape both can build; align them so an effect reads the same context whether it is being tested for eligibility or applied.

## Edge Cases

| Case                                                       | Expected Handling                                                                                              |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| The same stat mutation is applied more than once in a run. | The store accumulates all entries; the getter projects their full sum, identical to today's repeated addition. |
| Two cooldown reductions only breach a floor when combined. | The floor applies to the projected combined value, not to either entry.                                        |
| Reducing dash cooldown while one is counting down.         | In-flight remaining cooldown re-clamps to the newly projected maximum, identical to today.                     |

## Acceptance Criteria

1. The effect-type enum and all three switch statements branching on it no longer exist; each effect's eligibility and application live on its own object.
2. Every effect that exists today is offered under the same risk tiers and applies identically to before the migration.
3. Every one of the seven stat getters returns the same value for any call sequence as today's direct-mutation approach, with effects recorded in the store and every clamp and both side effects preserved.
