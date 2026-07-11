# Project Structure

This document defines the main folder structure and **where different types of content belong**.

---

# Top Level

**common/**
Shared reusable systems, framework utilities, and generic helpers not tied to any specific feature.

**data/**
Designer-authored Resource definitions and their `.tres` asset files.

**dev/**
Development-only assets: documentation and tooling scripts. Not shipped in builds.

**game/**
All game feature scenes, scripts, and UI components.

**global/**
Autoloads and project-wide shared resources.

**localization/**
Localization files and string tables.

---

# Folder Rules

## common/

Use for **reusable logic not tied to a specific game feature**.

```
common/audio      → audio bus wrappers and event types
common/framework  → engine-style infrastructure (StateMachine, State)
common/utils      → generic helper utilities
```

Key question: **could this be reused in a different project without modification?**

- Yes → `common/`
- No → `game/<feature>/`

---

## data/

Use for **designer-authored content**: Resource class definitions and the `.tres` files filled from them. The first directory level under `data/` is the content domain, not the artifact type or pipeline stage.

```
data/
  <domain>/
    definitions/   → Resource .gd class definitions (the schema) for this domain
    ...            → domain-owned authored .tres content, named to fit the domain
```

Key question: **who writes this data?**

- A designer fills in values → belongs in `data/<domain>/`
- Code generates the object at runtime → stays in `game/<feature>/`

Each domain owns its own definitions/content split; there is no project-wide `data/definitions/`, `data/yaml/`, or `data/tres/` shared by every domain. Current domains:

```
data/
  rewards/
    definitions/   → Artifact, ArtifactRegistry, and artifact effect Resource schemas
    artifacts/     → authored Artifact .tres content
    default_artifact_registry.tres → the authored reward catalog
  enemies/
    definitions/   → EnemyData, EnemyAttackData Resource schemas
  yaml/sfx/        → human-authored SFX synth patches, a generated-pipeline source folder scoped to the SFX domain
  tres/            → generated SFX playback resources (gitignored — run dev/tools/render_sfx.py); scoped to the SFX domain, not a project-wide generated-output rule
```

Gameplay tuning data (enemy stats, player stats) is deliberately hand-authored as `.tres` alongside its owning feature (e.g. `game/entities/enemies/data/`) rather than generated — see `dev/docs/archived/enemy_data_backed_structure.md`.

### Generated pipelines are opt-in per domain

A domain may add its own `yaml/`, `generated/`, or tool-specific source/output folders when it needs a build step (the SFX pipeline is the current example, under `data/yaml/sfx/` and `data/tres/`). That generated/manual split is documented and owned by the domain that needs it. Do not assume any `.tres` under `data/` is generated, or add a project-wide generated folder — a new domain that needs generation defines its own source/output folders and rebuild instructions without changing this rule.

---

## dev/

Development-only content; not part of the shipped build.

```
dev/
  docs/     → Architecture docs (README + 3-level rules; systems/ and plans/ as needed)
  skills/   → AI coding references (commit format, GDScript patterns)
  standards/→ Coding conventions and architecture rules
  tools/    → Build/lint/test scripts and the SFX synthesis pipeline
    prompts/→ AI prompt packs (SFX YAML generation guide)
    tres_lib/→ Shared .tres writer + uid helpers used by the SFX pipeline
```

---

## game/

All game feature content. Organise by feature; add subdirectories as features grow.

```
game/
  <feature>/    → Your game features go here
    assets/     → Source assets owned exclusively by this feature
```

Each feature folder contains scene roots, UI component sub-scenes, and logic scripts. Do not split logic and scene files into sub-folders unless the flat layout becomes hard to navigate.

Feature-owned source art, audio, and other imported assets live in the owning feature's `assets/` folder. When one feature contains several independently owned entities or components, group their source assets by consumer, such as `game/entities/enemies/assets/small_enemy/`. Root `assets/` is an ignored vendor/reference area, not a runtime dependency location. See `asset_ownership_standard.md` for dependency and sharing rules.

**Shared UI components** used by more than one feature live in `game/shared/`. Move to `shared/` only when a second feature actually needs it — do not pre-emptively place things there.

---

## global/

Project-wide global systems configured as autoloads.

```
global/
  autoload/
    (managers)  → Managers and sections (SaveManager, GameManager, etc.)
  constants/    → Project-wide constants
  theme/        → Shared theme resources
  utils/        → RegistryAudit and other static utilities
```

Only scripts that must be globally accessible at all times belong here.
For the current list of registered autoloads and their load order, see `project.godot` and `CLAUDE.md`.

---

# Placement Rules

| Content type                                         | Location                                                         |
| ---------------------------------------------------- | ---------------------------------------------------------------- |
| Reusable framework or engine utilities               | `common/`                                                        |
| Designer-authored Resource class definitions (`.gd`) | `data/<domain>/definitions/`                                     |
| Domain-owned authored `.tres` content                | `data/<domain>/`, e.g. `data/rewards/artifacts/`                 |
| Domain-owned generated resources (opt-in per domain) | `data/<domain>/` generated subfolder, e.g. `data/tres/` for SFX  |
| YAML source files for the SFX pipeline               | `data/yaml/sfx/`                                                 |
| Hand-authored gameplay tuning resources (`.tres`)    | alongside the owning feature, e.g. `game/entities/enemies/data/` |
| Code-generated runtime data structures               | `game/<feature>/` or `game/shared/`                              |
| Feature scene roots, UI components, logic            | `game/<feature>/`                                                |
| UI helpers shared across multiple features           | `game/shared/`                                                   |
| Global autoloads                                     | `global/autoloads/`                                              |
| Tooling scripts                                      | `dev/tools/`                                                     |
| Localization files                                   | `localization/`                                                  |
