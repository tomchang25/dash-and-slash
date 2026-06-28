# Data-Backed Enemy Structure

## Goal

Make enemies share one lightweight data model for common stats and attack profiles while preserving existing enemy classes for custom behavior. This reduces hardcoded enemy tuning and duplicated attack/state structure without forcing every enemy into one universal script.

## Requirements

1. Existing enemy classes remain the public behavior units, because some enemies and future bosses need custom overrides.
2. Enemy tuning uses manually-authored resources stored with the enemy feature, because the enemy count is small and generated data would add unnecessary pipeline overhead.
3. Shared attack behavior supports tile, charge, and puff-style profiles through a common data shape, while each enemy class still decides when and how to use an attack.
4. Cell-based attack planning is generalized so enemies do not duplicate the same origin-search behavior.
5. State consolidation follows the shared attack API, because state scene rewiring has higher breakage risk than data extraction.
6. Existing gameplay behavior remains equivalent unless a data value intentionally changes it.

## Design

The work ships as four ordered phases. Each phase has its own sketch so the implementation boundary stays small and the riskier changes wait for the lower-risk foundation.

| Phase | Focus                           | Dependency         |
| ----- | ------------------------------- | ------------------ |
| 1     | Enemy data resources            | None               |
| 2     | Cell attack controller          | Phase 1            |
| 3     | Special attack data integration | Phases 1 and 2     |
| 4     | State consolidation             | Phases 1 through 3 |

Enemy data is lightweight and local to the enemy feature. It covers shared configuration such as display name, movement speed, cooldowns, recovery timing, attack profiles, damage, telegraph timings, ranges, charge speed, and mode colors. It does not try to encode bespoke boss behavior, special VFX choreography, or unique AI rules.

Attack data describes what an attack is, not the entire behavior. A tile attack uses cell shapes and rectangular hitboxes. A charge attack uses a line footprint and contact hitbox while the enemy class handles movement. A puff attack uses range, duration, and damage data while the puff enemy keeps its expand and shrink VFX.

State consolidation is intentionally last. First, enemies expose a common attack-facing contract. Then shared states can replace wrapper states and generic telegraph or attack phases without turning the enemy entity into a state-dispatch anti-pattern.

## Non-Goals

1. Do not convert enemy data to generated resources for this work.
2. Do not force every enemy into a single universal enemy script.
3. Do not make boss-specific logic fully data-driven unless the boss actually shares behavior with existing enemies.
4. Do not data-drive wave definitions as part of this work.
5. Do not consolidate puff behavior into a generic attack state before there is a clear second user.

## Acceptance Criteria

1. Existing enemy classes remain available and continue to own their custom behavior.
2. Common enemy tuning can be changed through manually-authored enemy resources.
3. Tile-style attack profiles can be represented through shared attack data rather than hardcoded pattern enums.
4. The same attack controller lifecycle can drive tile attacks for multiple enemies.
5. Charge and puff enemies can read shared attack values without losing their custom movement or VFX behavior.
6. Duplicate cell-attack-origin planning is removed or reduced to one shared behavior.
7. Shared state consolidation removes boilerplate wrappers only after the common attack lifecycle API is in place.
