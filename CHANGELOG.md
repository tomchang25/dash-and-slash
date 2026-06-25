# Changelog

Append-only record of shipped work. This is the project's permanent "done" history.

**Why this file exists:** it is the single home for "what got built." Because it is append-only — you only ever add entries, never reconcile them against current code — it cannot go stale. This is what lets every other tracking surface stay forward-only: `systems/` describes the system as it *is* (present tense, no Done lists) and `TODO.md` holds only open work (`## Active` in-flight flows, `Plan`/`Chore`/`Bug`, and `## Draft` concepts), with multi-step flows detailed in `dev/docs/plans/` files. When a phase ships, append one entry here, then cut that phase from its plan file; when a whole flow ships, also delete its `TODO.md` line.

---

## [unreleased]

### split into base + preset overlays
- Restructured the repo into three layers: paradigm-neutral `base/`, plus `presets/sim-management/` and `presets/action-rpg/` overlays (`tools/compose.py` assembles base + one preset into `build/<preset>/`)
- Made the base paradigm-neutral: rewrote `SaveManager` as a thin **provider** coordinator holding zero gameplay state (`register_provider` + `to_dict`/`from_dict`/`validate`); replaced the `ExampleOwner` reference with a neutral `ExampleState` provider; fixed autoload order so `SaveManager` precedes every provider
- Demoted the Owner pattern (`owners.md`, `example_owner.gd`) out of the base; it is superseded by the Store/System model in the sim-management preset
- `sim-management` preset: `StoreBase` + reference `EconomyStore`/`InventoryStore`, an `ExampleSystem` that holds the Stores and owns transactions, the `store_manager.md` standard, the Store/Snapshot/Service/Entry archetype taxonomy, the `setup()`/`_apply()` data-flow convention, and an `example_sim` reference scene
- `action-rpg` preset: `Health`/`Hurtbox`/`Hitbox` component nodes, an `Entity` base, a `NodePool`, a `WorldState` snapshot save provider, the `component_architecture.md` standard, and an `example_arpg` combat slice (player + pooled enemies + a real-time arena driver)

### template extracted from lot-and-haul
- Removed Storage Wars game content (scenes, runtime types, clue/item/car/auction systems)
- Retained four spines: data pipeline, boot orchestration, section-based save, go_to() scene routing
- Added `ResourceRegistry` base class; all per-type registries now extend it
- Rewrote `SaveManager` as section-registration dispatch (removes hard-coded game fields)
- Rewrote `GameManager` with `_SCENES` const dict + `go_to(key, payload)`
- Added example vertical slice: `ExampleEntityData` → YAML → tres → `ExampleRegistry` → `ExampleOwner` → `example_scene`
- Updated `dev/tools` pipeline: only `example_entity` spec remains; prompts rewritten as "how to add an entity" guide
- Reset `TODO.md` / `CHANGELOG.md` to template initial state

### owner pattern formalized
- Established the **domain Owner** as the canonical persistence unit: one Owner per domain owns state + serialization + validation + migration in one object (replaces thin "save section" adapters that only serialize another object's state)
- Reshaped `ExampleSaveSection` → `ExampleOwner` as the reference implementation: sanitize-on-load (drop unresolved `collected_ids` against `ExampleRegistry` with `push_warning`) and a per-owner migration seam
- Added `dev/standards/owners.md` defining the pattern and its boundaries (cross-section/`schema_version` migration belongs to `SaveManager`; authored-content validation belongs to `Registry.validate()`, which must not read live state)
- Added a `schema_version` migration seam in `SaveManager.load()`; noted the live-state boundary in `dev/standards/registries.md`
