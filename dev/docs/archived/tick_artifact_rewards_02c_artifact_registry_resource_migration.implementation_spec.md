# Tick Artifact Rewards 02c: Artifact Registry Resource Migration

Parent Plan: `tick_artifact_rewards.md`

## Goal

Move reward artifact content out of the generator and into Resource-backed artifact definitions plus an `ArtifactRegistry`, without changing the 02b reward cadence. This makes artifact identity/display data stable enough for the build inspection panel while keeping broader `data/` layout cleanup for child 02d.

## Summary

The current 02b implementation has the right runtime behavior, but the content source is still prototype-shaped: `Artifact`, every `ArtifactEffect`, and `WaveRewardChoiceGenerator`'s default pool are `RefCounted` objects built by `_make_default_artifacts()`. That leaves the generator as both roll/filter logic and content author, and it gives the upcoming HUD no stable catalog to inspect.

This child converts the reward artifact model to Resource-backed definitions and introduces `ArtifactRegistry` as the content catalog. `_make_default_artifacts()` is deleted outright. The arena scene exports the production registry Resource and `TickRunController` injects it into the generator; tests can inject small synthetic registries. The generator remains a pure picker: read registry artifacts, filter by derived kind/min wave/eligibility, shuffle, return choices.

This child intentionally does not redesign the project-wide `data/` layout. To keep the migration independently shippable, the default registry and artifact `.tres` files may live under the current reward feature area for this child. Child 02d moves reward definitions/resources into domain-first `data/rewards/` and updates the shared data placement rules.

## Relational Context

- `ArtifactRegistry` is a read-only content catalog. It may return all artifacts, look up by id, and validate authored data; it must not own run state, RNG, cadence, or picked artifacts.
- `WaveRewardChoiceGenerator` owns roll/filter/shuffle only. Before this child it builds the default artifact list itself; after this child it receives an `ArtifactRegistry` and never authors artifacts in code.
- `TickRunController` remains the production owner that constructs the generator. The arena scene wires its required `ArtifactRegistry` dependency explicitly, alongside grid, engine, player, and overlays; `TickRunController` does not load a registry path from the generator. Its 02b cadence, `Minor x2` assembly, and forced curse confirmation must stay behaviorally unchanged.
- `Artifact`, `ArtifactEffect`, and concrete effect contributions become Resources so authored `.tres` content can store identity, display text, rarity, curse flag, min wave, magnitude, and effect lists.
- `WaveRewardChoice` and `RunBuild` keep their runtime contracts: choices hold artifact references and call acquire-then-apply; `RunBuild` remains the only owner of owned artifact state, legendary capacity, exclusivity, and channel totals.
- Tests that need synthetic artifacts should build Resource instances through helpers or small test registries; they should not depend on production registry ordering except when explicitly testing production catalog content.
- Child 02d owns moving the resource definitions and authored `.tres` files into final domain-first `data/rewards/` paths. Do not mix that project-layout cleanup into this child.

## Scope

### Included

- Convert reward `Artifact` and `ArtifactEffect` classes from `RefCounted` to serializable Resources.
- Add `ArtifactRegistry` Resource as the artifact catalog.
- Remove `_make_default_artifacts()` and all hardcoded artifact content from `WaveRewardChoiceGenerator`.
- Create a default registry Resource containing the current Minor, Major, and curse artifacts with unchanged values.
- Update generator construction and tests to use explicit registry injection; production wiring comes from the arena scene's exported registry Resource.
- Preserve all 02b behavior: normal Minor offers, milestone `Minor x2`/Major fallback, and forced curse confirmation.

### Excluded

- Domain-first `data/` folder cleanup, reward resource relocation into `data/rewards/`, and project rule updates; child 02d owns those.
- HUD/build inspection panel UI.
- Rarity weighting, balance changes, new artifacts, icon art, or card color polish.
- Any change to `RunBuild`, wave scaling formulas, combat projection, or milestone cadence.

## Files to Change

| File                                                                                                                                         | Change Size | Purpose                                                                                                        |
| -------------------------------------------------------------------------------------------------------------------------------------------- | ----------- | -------------------------------------------------------------------------------------------------------------- |
| `game/tick_arena/reward/artifact.gd`                                                                                                         | Medium      | Convert to Resource/exported data while preserving eligibility and apply behavior.                             |
| `game/tick_arena/reward/effects/artifact_effect.gd`                                                                                          | Small       | Convert abstract effect contribution to Resource.                                                              |
| `game/tick_arena/reward/effects/channel_artifact_effect.gd`                                                                                  | Small       | Export channel, amount, and unit scale for authored resources.                                                 |
| `game/tick_arena/reward/effects/payload_artifact_effect.gd`                                                                                  | Small       | Export payload id for authored resources.                                                                      |
| `game/tick_arena/reward/effects/trigger_artifact_effect.gd`                                                                                  | Small       | Export trigger id for authored resources.                                                                      |
| `game/tick_arena/reward/artifact_registry.gd`                                                                                                | New Small   | Resource catalog exposing artifact list, id lookup, and validation helpers.                                    |
| `game/tick_arena/reward/wave_reward_choice_generator.gd`                                                                                     | Medium      | Accept/use an `ArtifactRegistry`, delete `_make_default_artifacts()`, and keep roll/filter behavior unchanged. |
| `game/tick_arena/run/tick_run_controller.gd`, `game/tick_arena/tick_arena.tscn`                                                               | Small       | Export and wire the default registry Resource as an explicit scene dependency while preserving 02b flow.       |
| `game/tick_arena/reward/artifacts/*.tres`, `game/tick_arena/reward/default_artifact_registry.tres` or equivalent temporary reward-local path | Large       | Authored Resource replacement for the current hardcoded default pool until 02d moves it into `data/rewards/`.  |
| Existing reward and artifact unit tests                                                                                                      | Medium      | Replace constructor assumptions with Resource helpers/registries and keep existing behavior assertions.        |
| `test/unit/test_artifact_registry.gd`                                                                                                        | New Small   | Validate registry lookup, duplicate-id reporting, null/empty-id guards, and production catalog presence.       |

## Execution Outline

1. Convert `ArtifactEffect` and concrete effect classes to Resources with exported fields, keeping `apply()` behavior identical.
2. Convert `Artifact` to Resource with exported fields, retaining `is_eligible()` and `apply()` so runtime consumers do not change their call shape.
3. Add `ArtifactRegistry` with exported artifact list, read-only accessors, lookup by id, and validation errors for null entries, empty ids, and duplicate ids.
4. Create authored `.tres` artifacts and a default registry matching the current `_make_default_artifacts()` content exactly, including curse flags, min waves, magnitudes, stack rules, and percent unit scales.
5. Change `WaveRewardChoiceGenerator` to take a registry/default registry and delete `_make_default_artifacts()` completely.
6. Update `TickRunController`, `tick_arena.tscn`, and tests so production wiring injects the registry as a scene dependency and tests inject registries explicitly.
7. Add registry/catalog tests, then rerun existing reward generator, choice bundle, major-effect, run-build channel, and milestone sequence tests.

## Implementation Notes

- Keep `_init()` constructors only if they remain compatible with Godot Resource serialization and test helpers. Exported defaults must be sufficient for `.tres` authoring.
- The default registry path in this child is intentionally temporary if it lives under `game/tick_arena/reward/`; 02d owns moving it into the final domain-first data layout. Keep that path in the scene or tests that load the production registry, not as a generator-owned constant.
- Do not make `ArtifactRegistry` randomize, filter by wave, or apply eligibility. Those stay in `WaveRewardChoiceGenerator` because they are roll behavior, not catalog behavior.
- Existing tests that assert behavior through synthetic artifacts may instantiate Resources directly; production catalog tests should load the default registry to prove the hardcoded pool was fully migrated.
- Preserve `class_name` names unless a compiler/import issue forces renames. Moving files is a 02d concern.

## Edge Cases

| Case                                           | Expected Handling                                                                                                                                     |
| ---------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| Registry contains null artifact                | Validation reports it; generator skips it or refuses with a developer-visible error rather than crashing.                                             |
| Registry contains duplicate artifact ids       | Validation reports the duplicate; lookup returns a deterministic first match only if the implementation explicitly documents that behavior.           |
| Registry is missing in production construction | Developer-visible error; do not fall back to hardcoded artifacts.                                                                                     |
| `.tres` artifact has no effects                | Valid for synthetic/placeholder tests, but production catalog validation should flag content artifacts with no effects unless intentionally exempted. |
| Existing 02b reward sequence                   | Behavior remains unchanged after the content source migration.                                                                                        |

## Acceptance Criteria

1. Reward artifacts and effect contributions are authored as Resources rather than hardcoded `RefCounted` objects.
2. The default artifact catalog is loaded through an `ArtifactRegistry`, and no default artifact content remains in the generator.
3. Normal, milestone, `Minor x2`, Major fallback, and forced curse behavior are unchanged from 02b.
4. The production catalog contains every artifact that existed in the hardcoded pool with the same ids, flags, effects, magnitudes, min waves, and stack rules.
5. Registry validation catches missing, empty-id, and duplicate-id catalog problems.
6. Relevant reward, run-build, and milestone sequence unit tests pass.
