# Godot Data-Driven Template — Base Layer

A Godot 4.6 project skeleton for data-driven games. Provides four reusable "spines" — data pipeline, boot orchestration, save system, and scene routing — with a working vertical slice to validate the full chain.

This is the **paradigm-neutral base** of a three-layer template (see the repo root
`README.md`). It deliberately encodes no "where does game logic live" convention — a
reader cannot tell from the base whether the eventual game is turn-based or real-time.
That neutrality is the asset: each **preset** (`presets/sim-management/`,
`presets/action-rpg/`) layers exactly one such convention on top of these spines, and
a project is assembled as base + one preset overlay (`tools/compose.py`).

## Agent environment note (sandboxed shell vs. real files)

The sandboxed Linux shell can return **phantom file corruption** for files in this repo — blocks of NUL bytes, mid-token truncation, "binary file matches", or wrong byte counts — especially right after a write. This is a mount artifact, NOT real disk damage.

- The Read/Edit file tools are authoritative. After modifying a file, verify it with **Read**, never by `cat`/`hexdump`/`wc`/`grep` through the shell. If Read shows clean content, the file is fine — stop.
- Never diagnose "corrupted files" from a shell read alone, and never `git restore`/overwrite working-tree files to "recover" from shell-reported corruption — that risks discarding genuine uncommitted work over a false reading.
- `git` against the object DB (`git show HEAD:<file>`, `git log`, `git diff`) is reliable; working-tree file-content reads through the shell mount are not.

## The Four Spines

1. **Data pipeline** — YAML (human-authored) → `.tres` (generated) → `ResourceDirLoader` → Registry → game reads.
2. **Boot orchestration** — registries autoload before save providers, load their resources in `_ready()`, and are validated during boot.
3. **Save system** — Section-based JSON: state-owning objects register themselves as **providers** with `SaveManager`, which fans `to_dict`/`from_dict`/`validate` out to them. `SaveManager` holds no gameplay state. The base takes no position on how a project groups the things that own state — that is a preset decision.
4. **Scene routing** — `GameManager._SCENES` dict + `go_to(key, payload)` + `consume_payload()`.

## Project Structure

```
assets/           Static assets (sprites, audio files)
common/           Reusable systems (not feature-specific)
  audio/          Event-driven audio (events, bus)
  framework/      State machine pattern
  utils/          Random utilities
data/             Designer resources
  definitions/    Resource class scripts (.gd)
  yaml/           Human-authored YAML source data
  tres/           Generated from yaml — do not hand-edit (gitignored)
    examples/
    audio_events/
dev/              Development tooling and documentation
  docs/           Architecture docs (README + 3-level rules)
  skills/         AI coding references (commit format, GDScript patterns)
  standards/      Coding conventions, naming, scene architecture, enforcement
  tools/          YAML→TRES, placeholder SFX, localization, lint scripts
    prompts/      Authoring guides (how to add a new entity type)
      ai_prompt_packs/  AI prompt packs (SFX placeholder generation)
    tres_lib/     Pipeline library (spec protocol, uid, writer, registry)
game/             Game feature scenes
  example/        Template demo scene (full chain: registry → save → routing)
global/           Autoloads and project-wide resources
  autoloads/      All autoload scripts
    registries/   ResourceRegistry base + per-type registries
  constants/      DataPaths
  theme/          Main theme resource
  utils/          RegistryAudit utility
localization/     Localization files (empty, planned)
```

## Autoloads (load order)

`EventBus → SettingsStore → ToastManager → AudioManager → ExampleRegistry → SaveManager → ExampleState → SceneRouter → GameManager`

`SaveManager` is listed **before** any save provider, because each provider's
`_ready()` calls `SaveManager.register_provider(self)` — an autoload can only reach
autoloads defined above it during `_ready()`. `GameManager` is last and drives boot:
`SaveManager.load()` → `SaveManager.run_validation()`.

When adding a new registry, insert it after `AudioManager` and before `SaveManager`.

## Data Pipeline

Entities are authored in `data/yaml/*.yaml`, converted to `.tres` via `dev/tools/yaml_to_tres.py`. Validate with `dev/tools/validate_yaml.py`. Reverse with `dev/tools/tres_to_yaml.py`.

Placeholder SFX are authored in `data/yaml/sfx/*.yaml` and rendered via `dev/tools/render_sfx.py` into deterministic WAV files plus `UiAudioEvent` `.tres` resources. Use `dev/tools/prompts/yaml_generation/sfx.md` for AI-authored placeholder patches.

The `.tres` output directories are gitignored — run the pipeline on every fresh checkout before opening the project.

**To add a new entity type**, follow `dev/tools/prompts/yaml_generation/base.md` (six steps: define resource class → author YAML → write spec → register spec → write registry → wire up).

## Save System

Persistence runs through **providers**. A provider is any object that owns some
live state and implements the save contract; it registers itself with `SaveManager`
in `_ready()`. `SaveManager` is a thin coordinator that holds no gameplay state — it
merges every provider's payload into one sections dict on save, and hands the full
sections dict back to every provider on load.

```gdscript
func _ready() -> void:
    SaveManager.register_provider(self)

func to_dict() -> Dictionary: return { "my_domain": { ... } }
func from_dict(data: Dictionary) -> void: ...   # read data["my_domain"]: migrate → load
func validate() -> bool: return true            # sanity-check restored state
```

`SaveManager.load()` then `run_validation()` are called once from `GameManager._ready()`
after all providers have registered. New autoload providers go before `SaveManager`
in `project.godot`. Boundaries: whole-file / `schema_version` migration lives in
`SaveManager._migrate_schema()` (it has the whole-file view); per-section field
migration lives in the provider's `from_dict()`; authored-content validation lives
in the Registry's `validate()`, which must not read live/save state.

The base ships exactly one provider, `global/autoloads/example_state.gd`, as the
neutral reference. **How a real project organises the many objects that own state is
a preset decision** — the `sim-management` preset layers a Store/System model on top
of this contract; the `action-rpg` preset distributes state onto entity components.

## Scene Routing

Add scenes to the `_SCENES` const in `game_manager.gd`, then navigate with:

```gdscript
GameManager.go_to("my_scene")
# or with payload:
GameManager.go_to("my_scene", { "data": value })
var payload = GameManager.consume_payload()
```

## Conventions (quick reference)

- **Naming**: snake_case files, PascalCase classes, UPPER_SNAKE constants. See `dev/standards/naming_conventions.md`.
- **Registries**: extend `ResourceRegistry`; required API: `get_<singular>_by_id`, `get_all_<plural>`, `size`. See `dev/standards/registries.md`.
- **Save providers**: an object that serializes a slice of state must also own that state — no save adapter that only serializes another object's fields. The base stays neutral on how providers are grouped across domains; presets supply that convention.
- **GDScript structure & scene architecture**: scripts follow `dev/standards/gdscript_structure_standard.md`; persistent scene nodes and runtime `add_child()` exceptions follow `dev/standards/scene_node_source_standard.md`; reusable component layout/preview rules follow `dev/standards/component_scene_standard.md`. Node-source and no-`[connection]` rules are **lint-enforced** — see `dev/standards/standards_enforcement.md`. Run `python dev/tools/lint_standards.py --files <changed>` before finishing if you are an agent without the in-loop lint hook.
- **Commits**: conventional commits format. See `dev/skills/conventional_commits.md`.
- **StateMachine**: behaviour-delegation pattern — states own logic, entity provides a public query API. See `dev/skills/state_machine_pattern.md`.
- **Audio events**: always use `AudioManager.play_event()` with an `AudioEvent` resource. Never call `play_sfx_2d()`/`play_ui()`/`play_music()` directly. See `dev/skills/audio_event_usage.md`.
- **Iterate resources, not ids**: pass Resource refs outside serialization boundaries. String ids are for save/load only.
- **Docstrings**: every `.gd` starts with `# filename` + one-line purpose. All public functions and complex private functions get a `##` GDDoc comment. Never strip existing comments when editing.
- **Docs layering**: 3 levels, each fact lives in exactly one. L1 vision (≤5 files, rarely changes), L2 systems/plans (design intent + flow, present tense), L3 detail (code docstrings). Full rules in `dev/docs/README.md`.
- **Tracking**: `CHANGELOG.md` (append-only shipped history) and `TODO.md` (single forward surface: `## Active` in-flight flows, `Plan`/`Chore`/`Bug` one-liners, `## Draft` for concepts). Multi-step work lives in `dev/docs/plans/<x>.md` with a one-line pointer in `TODO.md`.

## Don'ts

- Don't hand-edit `.tres` files under `data/tres/` — use the YAML pipeline.
- Don't hand-edit generated files under `assets/audio/placeholder/` or `data/tres/audio_events/` — use the source YAML pipelines.
- Don't add display-name wrappers or fallback-to-id accessors on registries.
- Don't put code-level detail (function names, field lists) in `dev/docs/systems/` — that belongs in code comments.
- Don't keep a living "Done" list anywhere except `CHANGELOG.md`.
- Don't put forward-looking sections in `systems/` docs — route forward items to `## Open Questions` or `TODO.md`.
- Don't create a separate `draft/` folder — the draft tier is the `## Draft` section of `TODO.md`.
