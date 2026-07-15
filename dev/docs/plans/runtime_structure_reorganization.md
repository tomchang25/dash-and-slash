# Runtime Structure Reorganization

## Goal

Consolidate Tickstrike's arena gameplay under one feature-owned structure so enemy, grid, combat, view, and run code can be understood and changed together. Keep only genuinely portable infrastructure and capability components in the reusable layer while preserving the action-RPG component ownership model.

## Requirements

1. Restrict the reusable layer to engine-style infrastructure, pure utilities, and capability components that have no Tickstrike arena, enemy, combat-feedback, or authored-content assumptions.
2. Co-locate all arena-specific entities, components, grid behavior, combat resolution, presentation, rewards, waves, and run coordination under the arena feature because they evolve as one gameplay unit.
3. Preserve distributed entity/component ownership: entity state remains on the entity and its mounted capabilities, while cross-entity timing and orchestration remain owned by arena drivers rather than a new central Store/System layer.
4. Keep feature-owned source assets and tuning content beside their sole consumer, promote assets or presentation to shared game ownership only when a second feature uses them, and retain catalog-style authored content in its existing data domain.
5. Keep global lifetime separate from reuse: boot, save, routing, audio playback, pooling, settings, and notifications remain globally available only where their lifecycle requires it.
6. Align project-local architecture guidance with the updated action-RPG profile while retaining stricter arena feature locality where dependencies demand it; until the project upgrades to that profile contract, document the placement difference as an explicit temporary override without weakening component composition and lifecycle contracts.

## Design

### Ownership model

| Layer                    | Responsibility                                                                                                        |
| ------------------------ | --------------------------------------------------------------------------------------------------------------------- |
| Reusable infrastructure  | Portable engine capabilities, framework code, and pure helpers without Tickstrike concepts                            |
| Arena feature            | Arena rules, grid authority, combat execution, player and enemy entities, waves, rewards, HUD, feedback, and run flow |
| Meta features            | Main-menu and future between-run presentation owned independently from the arena                                      |
| Shared game presentation | UI or assets with at least two real game-feature consumers                                                            |
| Global orchestration     | Always-available boot, persistence, routing, settings, audio playback, pooling, and notification services             |
| Authored data            | Catalog-style designer resources shared across runtime consumers and any explicitly documented generated pipeline     |

Arena locality is the default when reuse is uncertain. A capability is promoted to reusable infrastructure only when its contract is independent of arena timing, grid semantics, enemy presentation, and project-specific authored resources. This avoids preserving abstractions solely because they might be reusable later.

The reorganization does not change the distinction between local entity behavior and cross-entity drivers. It changes discoverability and dependency direction, not gameplay authority.

### Child overview

| Child | Focus                                                                                    | Current document form       |
| ----- | ---------------------------------------------------------------------------------------- | --------------------------- |
| 01    | Lock project-local placement rules and classify current reusable versus arena-owned code | Pending sketch              |
| 02    | Consolidate arena entities, components, grid behavior, and feature-owned assets          | Pending sketch              |
| 03    | Consolidate arena presentation and clean reusable authored-content residue               | Pending sketch              |
| 04    | Reconcile references, verification surfaces, and architecture documentation              | Pending implementation spec |

Recommended landing order: 01, 02, 03, 04. Each child must keep the project loadable and avoid overlapping with active combat-rule plans beyond path and ownership updates.

## Non-Goals

1. Do not change combat timing, action points, enemy behavior, mobility rules, reward behavior, or balance.
2. Do not replace the action-RPG entity/component model with Stores, Systems, or a new ECS.
3. Do not redesign save payloads, authored wave catalogs, reward schemas, or the SFX generation pipeline.
4. Do not extract abstractions for hypothetical future game modes or entities.
5. Do not combine this migration with the implementation of any queued gameplay plan.

## Acceptance Criteria

1. A developer can locate the complete arena runtime from one feature boundary without searching separate generic entity or gameplay trees.
2. The reusable layer contains no arena-specific grid, enemy, combat-feedback, presentation, or authored preset assumptions.
3. Entity composition, capability lifecycle, pooling behavior, and arena-driver authority remain behaviorally unchanged.
4. Feature-owned scenes and resources depend only on assets owned by their feature or by a demonstrated shared consumer.
5. All scenes, resources, autoloads, tooling, and tests resolve their dependencies after each migration child lands.
6. Project-local standards and startup guidance describe one consistent placement model that either consumes the updated profile contract or explicitly documents the temporary override until the foundation upgrade lands.
7. Standards lint and the repository's required verification pass without gameplay or content regressions.
