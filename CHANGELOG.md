# Changelog

Append-only record of shipped work.

Rules:

- Add shipped work only; do not keep forward-looking items or Done lists here.
- Each entry uses `- YYYY-MM-DD — [scope] one-line summary`.
- `##` headings are version headings only. Entries must live under `###` section headings; only version notes may sit directly under a `##` heading.
- `###` headings group related entries. Section titles are plain names, not "Phase"/"Stage" labels.
- Keep entries concise and outcome-focused per `dev/standards/change_summary_standard.md`.
- When a phase ships, append the entry here and cut the shipped work from its plan/TODO source.
- Do not add entries for dev-process-only maintenance, including closeout workflow changes, CHANGELOG/TODO edits, plan archival, or tracking cleanup.

---

## [unreleased]

### Player Dash Mouse Aim And Invulnerability

- 2026-06-29 — [player] Dash direction follows mouse aim, with base invulnerability during the dash active window and a 0.25 s hit-reward extension on landed dash hits; player prototype body updated to a rounder shape

### Enemy Grid Move Priority

- 2026-06-29 — [enemy] Contested grid movement resolves with deterministic priority: attack-position moves beat ordinary repositioning, closer enemies win distance ties, and registration order breaks remaining ties consistently

### Enemy Pathfinding

- 2026-06-25 — Enemy Add BFS pathfinding to small enemy AI with grid reservations, step-by-step path consumption, and grid-based arena spawning

### placeholder SFX pipeline

- 2026-06-25 — SFX Added deterministic synthesis pipeline (YAML patch → WAV + UiAudioEvent .tres, 44.1 kHz 16-bit mono, -3 dBFS, 5 ms fade-out) with generation standard, AI prompt pack, and 8 placeholder patches (ui_click, ui_hover, ui_confirm, ui_cancel, hit_light, dash, pickup, error)

### split into base + preset overlays

- 2026-06-25 — Architecture Restructured repo into paradigm-neutral base/ + overlay presets (sim-management, action-rpg) assembled by compose.py; refactored SaveManager as thin provider coordinator with register_provider + to_dict/from_dict/validate; demoted Owner pattern from base
- 2026-06-25 — sim-management Added Store/System model with reference EconomyStore/InventoryStore, ExampleSystem transaction owner, store_manager.md standard, and example_sim reference scene
- 2026-06-25 — action-rpg Added component-based entity system with Health/Hurtbox/Hitbox nodes, NodePool, WorldState snapshot save provider, component_architecture.md standard, and example_arpg combat slice

### template extracted from lot-and-haul

- 2026-06-25 — Template Removed Storage Wars game content; retained data pipeline, boot orchestration, section-based save, and go_to() scene routing
- 2026-06-25 — Core Added ResourceRegistry base class, rewrote SaveManager as section-registration dispatch, rewrote GameManager with \_SCENES const dict + go_to(key, payload)
- 2026-06-25 — Example Added vertical slice (ExampleEntityData → YAML → tres → ExampleRegistry → ExampleOwner → example_scene); rewrote prompts as entity-creation guide

### owner pattern formalized

- 2026-06-25 — Save Formalized domain Owner pattern as canonical persistence unit with state ownership, serialization, validation, and migration; reshaped ExampleOwner as reference implementation with sanitize-on-load and per-owner migration seam
- 2026-06-25 — Standards Added owners.md defining pattern boundaries and schema_version migration seam in SaveManager
