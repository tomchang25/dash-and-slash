# Template base + presets split

**Goal:** Stop trying to serve every game genre from one template. Keep one paradigm-neutral **base** (the four spines + cross-cutting standards), then layer thin **presets** that each encode one "where does logic live" convention. First two presets: `sim-management` (data-driven, turn/idle, UI-heavy — covers Lot & Haul and the naval idle) and `action-rpg` (real-time, spatial, many entities). Do not fork the base into N diverging copies, and do not bolt a third-party ECS onto Godot.

## Context / why now

Two concrete designs are now in hand and they are _the same paradigm_: Lot & Haul (auction/management) and the naval idle (Melvor-like). Both are data-driven, turn- or tick-based, UI-heavy, and persistence-centric. They share one architecture; the idle only adds a time-advance loop. A future action-RPG is genuinely different and would fight the same conventions. That is the signal to split — but by paradigm, not by copy.

The Lot & Haul `save-refactor` branch also resolved what the sim preset's model layer should actually look like (see "The Store/System evolution" below). That conclusion is baked into this plan.

## The axis that actually matters

The dividing line is **not "MVC vs ECS."** It is turn/idle vs real-time:

| Axis                                         | Where logic lives                                | Why                                                                       |
| -------------------------------------------- | ------------------------------------------------ | ------------------------------------------------------------------------- |
| Turn / idle / management / UI-heavy          | Centralised in Managers + Stores + pure Services | State is serialised, mutated in discrete steps, never per-frame           |
| Real-time / action / many entities / spatial | Distributed onto entities as Component nodes     | Per-frame updates, spatial queries, physics — logic must sit on the thing |

Cramming both into one template fails because the two halves answer "where does logic live" with opposite rules. Manager-centric logic and entity-distributed logic cannot share one standards set without one of them being wrong.

**On "ECS" specifically:** in Godot, a bolt-on ECS framework fights the engine — Node + Scene _is already_ a composition system. The action-rpg preset uses idiomatic **scene composition + Component nodes** (a `Health` node, a `Hitbox` node, a `StateMachine` node mounted on an entity scene), not a third-party ECS. Reserve a true ECS only for thousands-of-entities batch-per-frame cases (bullet hell, large-scale sim) — an RPG rarely reaches that, and node-composition is both sufficient and idiomatic.

## Three-layer structure

```
godot-template (base — paradigm-neutral)
  Four spines: data pipeline · boot orchestration · save · scene routing
  Cross-cutting standards: naming, project_structure (skeleton only),
    registries, standards_enforcement (lint), plan/spec standards, commits
  Shared infra: event_bus, audio, state_machine framework, theme
        │
        ├─ preset: sim-management   (= Lot & Haul / naval idle)
        │     Store/System model layer (the save-refactor shape)
        │     Runtime-type archetype taxonomy: Store / Snapshot / Service / Entry
        │     block-scene setup()/_apply() data-injection convention
        │     (idle variant) Tick / offline-resolution engine
        │
        └─ preset: action-rpg
              Entity = composed scene; logic on Component nodes
              Component library (Health / Hitbox / StateMachine / …)
              Real-time system loop (per-frame _physics_process driver)
              No Store mutation-gateway — entities own their own state
```

The base stays exactly as `godot-template` is today: four spines + standards, with **no "where logic lives" convention baked in**. That neutrality is the asset — each preset supplies its own convention on top.

## The Store/System evolution (supersedes the Owner pattern)

The base currently ships the **Owner** pattern: one autoload owns a domain's live state _and_ its serialization, validation, and migration in a single object (`example_owner.gd`, `dev/standards/owners.md`). Lot & Haul's `save-refactor` branch decomposed that monolith, and the result is what the **sim-management preset** should adopt:

- **Store** (`common/gameplay/store/`, extends `StoreBase`, a `RefCounted`) — owns the domain's fields, its save payload, validation, and per-store versioned migration (`section_id / to_dict / from_dict / validate`, migrations inside `from_dict`). State is read-public via getters; there is no external setter, so the only write path is through the owning Manager. This is the **Model layer**, now a first-class thing.
- **Manager** (autoload) — holds one or more Stores as plain public fields, is the **sole mutation gateway**, owns cross-domain transactions (e.g. "day end" touches economy + storage + slot then saves once), and registers itself with SaveManager as a provider that fans out `to_dict`/`from_dict`/`validate` across its Stores.
- **SaveManager** — a thin persistence coordinator that holds **zero gameplay state**; providers register themselves before load. The old per-section "save section that only serializes someone else's state" files are gone.

Why this beats the monolithic Owner for sim games: it cleanly separates the _model_ (Store — serialisable, testable, mutation-guarded) from _orchestration_ (Manager — transactions, cross-domain coordination). That separation is exactly the "Model layer pulled out" the project was after, and it is what makes idle offline-resolution tractable (pure Stores + pure Services, advanced by a tick driver).

**Decision for the base:** demote `owners.md` and `example_owner.gd` out of the neutral base and into the `sim-management` preset, rewritten as a **Store/System standard**. Reasons: (1) the Owner monolith is superseded by the Store/System split for the sim paradigm, and (2) the action-rpg preset wants entity-distributed state, not a domain-Owner-per-autoload model — so this convention was never neutral.

## File-level allocation

What stays in the neutral base vs what pushes down to a preset.

**Base (paradigm-neutral) — keep:**

- The four spines: `data/` pipeline + `dev/tools/` (yaml↔tres, validate, stats), `registry_coordinator.gd` + `resource_dir_loader.gd` + `registry/`, `save_manager.gd` (thin coordinator form), `game_manager/` routing.
- Cross-cutting infra: `event_bus.gd`, `common/audio/`, `common/framework/state_machine/`, `common/utils/`, `global/theme/`.
- Standards that don't dictate where logic lives: `naming_conventions.md`, `registries.md`, `standards_enforcement.md`, `implementation_spec_standard.md`, `plan_standard.md`, `conventional_commits`, and `project_structure.md` **skeleton only** (the top-level folder map, minus the `common/gameplay/{store,snapshot,service,entry}` taxonomy).
- `scene_node_source_standard.md` **node-source rule** (persistent nodes live in `.tscn`, not `add_child()`) and `gdscript_structure_standard.md` **signal connection rule** (no `[connection]` in `.tscn`) — these are genuinely neutral and lint-enforced for both paradigms.

**Push to `sim-management` preset:**

- `StoreBase` + the Store/System standard (rewrite of `owners.md`) + a reference System-holds-Stores example (the `meta_system.gd` shape).
- The runtime-type archetype taxonomy (Store / Snapshot / Service / Entry) — currently in `CLAUDE.md`; it is sim-specific, not neutral.
- The `common/gameplay/{store,snapshot,service,entry}` folder convention.
- The block-scene `setup()` / `_apply()` data-injection pattern (the data-flow half of the block-scene standard; the node-source half stays in base).
- **Idle sub-variant:** a Tick / offline-resolution engine (a System that advances time, drives Action progress, and re-runs the same pure Services over an elapsed interval). Decide whether this is its own preset or a documented variant of `sim-management` — see Open Questions.

**Push to `action-rpg` preset:**

- Entity-as-composed-scene convention + a Component node library (`Health`, `Hitbox`, `StateMachine`, etc.).
- A real-time system loop (per-frame `_physics_process` driver) and the convention that gameplay logic lives on Component nodes, not in a central Manager mutation-gateway.
- An entity/component naming + folder convention to replace the archetype taxonomy.

## High-level steps

1. Lock the base membership list (above) and physically demote `owners.md` + `example_owner.gd` out of the neutral base.
2. Decide the sharing mechanism (Open Questions) — branch / overlay folder / git submodule core.
3. Write the `sim-management` preset: Store/System standard, archetype taxonomy, `setup()/_apply()` convention, port the Lot & Haul vertical slice as the reference.
4. Write the `action-rpg` preset: component library + real-time loop + a small combat vertical slice.
5. Update each layer's `CLAUDE.md` / `project_structure.md` to point at the right convention.

## Acceptance criteria

- The base contains no "where logic lives" convention — a reader cannot tell from the base whether the eventual game is turn-based or real-time.
- Each preset adds its convention without copying any of the four spines.
- A bug fix in a spine is made in exactly one place and both presets inherit it.
- The `sim-management` preset's model layer is the Store/System split, not the monolithic Owner.
- The `action-rpg` preset uses node-composition components, with no third-party ECS dependency.

- **Is the idle Tick engine its own preset or a `sim-management` variant?** As a a `sim-management` variant for now
- **Does `project_structure.md` split cleanly, or does the base need a second neutral skeleton** for `action-rpg` (entities/components folders) that the base can't anticipate? May force the structure doc itself to become per-preset.
