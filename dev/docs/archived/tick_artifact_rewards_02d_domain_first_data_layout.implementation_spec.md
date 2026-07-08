# Tick Artifact Rewards 02d: Domain-First Data Layout

Parent Plan: `tick_artifact_rewards.md`

## Goal

Move reward artifact definitions and authored resources into a domain-first `data/rewards/` layout, then update the shared project data rules so generated pipelines are domain-owned instead of globally imposed. This keeps 03 build inspection work from depending on temporary reward-local resource paths and gives the template a cleaner data convention.

## Summary

Child 02c makes artifacts Resource-backed and deletes the hardcoded generator pool, but it deliberately leaves broader data layout alone. This child finishes that structural work: reward schemas, authored artifact `.tres` files, and the default `ArtifactRegistry` move under `data/rewards/`, while runtime reward code continues to live under `game/tick_arena/reward/`.

The project rule changes are part of the deliverable. The current standards still describe `data/definitions`, `data/yaml`, and generated `data/tres` as the main shape, a leftover from a previous AI-generated YAML-to-`.tres` pipeline. This game no longer needs that as the default. The new rule should be domain-first: `data/<domain>/definitions/` for Resource schemas, domain-owned authored resources beside them, and generated outputs only where that domain explicitly documents a generated subfolder.

This child may move the existing enemy Resource definitions into `data/enemies/definitions/` if doing so is small and mechanical, but it should not chase every enemy scene/data reference if that turns the data-rule cleanup into unrelated gameplay migration. Reward data relocation is required; broader enemy cleanup can stay documented if it is not already trivial at implementation time.

## Relational Context

- `data/` owns designer-authored Resource schemas and content. After this child, the first directory level under `data/` is the content domain, not the artifact type or pipeline stage.
- `data/rewards/definitions/` owns reward artifact schema scripts; `data/rewards/artifacts/` and the reward registry Resource own authored reward content.
- `game/tick_arena/reward/` owns runtime reward flow, rolling, choices, and overlay behavior. It reads reward data by loading the registry; it does not own authored artifact content after this child.
- Generated pipelines are opt-in per domain. A domain may have `yaml/`, `generated/`, or tool-specific folders, but no global rule says all `.tres` under `data/` are generated or forbidden to hand-edit.
- `WaveRewardChoiceGenerator` and `TickRunController` should update preloads/resource paths only; their behavior must remain unchanged from 02c.
- Project documentation and standards must agree. If `dev/agent_rules/agent_startup.md` describes `data/tres` as generated-only while `dev/standards/project_structure.md` says domain-first, future agents will get contradictory instructions.
- Child 03 build inspection should read stable reward Resources from `data/rewards/`; do not leave it pointed at temporary 02c feature-local paths.

## Scope

### Included

- Move reward Resource scripts and authored reward registry/artifact `.tres` files into `data/rewards/`.
- Update reward runtime preload/resource references to the new registry path.
- Update project structure rules and startup data-pipeline wording to domain-first data layout.
- Clarify that generated resources are domain-specific and must be explicitly marked by that domain.
- Optionally move current enemy Resource definition scripts into `data/enemies/definitions/` if the live references are small enough to update safely.

### Excluded

- Changing reward behavior, artifact values, cadence, registry semantics, or build inspection UI.
- Rewriting the SFX synthesis pipeline; it can remain under its existing domain/pipeline paths until a dedicated audio cleanup.
- Broad enemy content migration if it becomes more than mechanical reference/path updates.
- Template or other-project edits outside this repository.

## Files to Change

| File                                                                                  | Change Size     | Purpose                                                                                                              |
| ------------------------------------------------------------------------------------- | --------------- | -------------------------------------------------------------------------------------------------------------------- |
| `data/rewards/definitions/*.gd`                                                       | Move/Medium     | Final home for `Artifact`, `ArtifactRegistry`, and artifact effect Resource schemas.                                 |
| `data/rewards/artifacts/*.tres`                                                       | Move/Large      | Final home for authored reward artifact Resources.                                                                   |
| `data/rewards/default_artifact_registry.tres`                                         | Move/Small      | Final reward catalog path loaded by runtime code.                                                                    |
| `game/tick_arena/reward/*.gd`, `game/tick_arena/run/tick_run_controller.gd` as needed | Small           | Update preloads, type paths, or imports after moving reward schema/content.                                          |
| `test/unit/*.gd` reward-related tests                                                 | Small/Medium    | Update resource paths and fixtures after reward data relocation.                                                     |
| `dev/standards/project_structure.md`                                                  | Medium          | Replace global definitions/yaml/tres layout with domain-first data rules.                                            |
| `dev/agent_rules/agent_startup.md`                                                    | Small           | Update project snapshot/data-pipeline wording so startup instructions no longer imply `data/tres` is generated-only. |
| `data/enemies/definitions/*.gd` and references                                        | Optional Medium | Move current enemy Resource definitions into the new domain-first shape if mechanical.                               |

## Execution Outline

1. Move reward schema scripts and reward `.tres` content from the temporary 02c location into `data/rewards/definitions/`, `data/rewards/artifacts/`, and `data/rewards/default_artifact_registry.tres`.
2. Update runtime reward code and reward tests to load the registry and schema paths from `data/rewards/`.
3. Run the narrow reward tests or import checks needed to catch broken resource paths before editing standards.
4. Rewrite `dev/standards/project_structure.md` data rules around `data/<domain>/definitions/`, authored resources, and domain-owned generated folders.
5. Update `dev/agent_rules/agent_startup.md` so its project structure and data-pipeline sections match the new rule and stop presenting generated `data/tres` as the default.
6. If enemy Resource definitions are easy to move mechanically, move them into `data/enemies/definitions/` and update references; otherwise leave enemy cleanup out and keep the standard broad enough to cover it later.
7. Run standards lint on changed docs/scripts/resources and the relevant reward tests/import checks.

## Implementation Notes

- Prefer `data/rewards/` over `data/artifacts/` because artifacts are currently reward-system content. Rename later only if artifacts become a cross-system item concept.
- Do not create a new global `data/tres/` replacement. Each domain owns its own folders and generated/manual distinction.
- If a domain has generated outputs, name or document that generated folder inside the domain. Do not rely on path folklore like "all `.tres` is generated."
- Use Godot-aware moves if available; otherwise preserve `.uid` files and update `res://` paths carefully.
- Keep 02c's `ArtifactRegistry` as catalog-only. 02d changes where it lives, not what it does.

## Edge Cases

| Case                                                      | Expected Handling                                                                                                    |
| --------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Moved Resource scripts break class references             | Update `res://` paths and keep `class_name` stable so runtime types keep compiling.                                  |
| Existing SFX generated pipeline still uses old path shape | Leave it functional and document it as an audio-domain/generated exception until an audio pipeline cleanup moves it. |
| Enemy definitions are not trivial to move                 | Do not broaden the change; reward data and rules still ship, and enemy domain cleanup can follow separately.         |
| A future domain needs YAML-to-`.tres` generation          | That domain defines its own source/generated folders and rebuild instructions without changing global `data/` rules. |

## Acceptance Criteria

1. Reward artifact schema scripts and authored artifact registry/resources live under `data/rewards/`.
2. Runtime reward code and tests load the reward registry from the final `data/rewards/` path.
3. Reward behavior remains unchanged from 02c after the resource move.
4. Project structure standards describe domain-first `data/<domain>/` layout and no longer require global `definitions/`, `yaml/`, or generated `tres/` folders.
5. Startup instructions no longer claim that all `data/tres` resources are generated or should not be hand-edited.
6. Generated data pipelines are documented as domain-owned opt-in folders rather than project-wide defaults.
