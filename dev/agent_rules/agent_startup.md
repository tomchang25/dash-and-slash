# Agent Startup

## Required Startup

Read this file before answering any repository-specific question or doing any work in this repo. If you entered through `AGENTS.md` or `CLAUDE.md`, continue here and treat this file as the shared source of truth.

Shared governance is loaded first from `dev/foundation/core/agent_rules/foundation_startup.md` and the `action-rpg` profile selected by `dev/foundation.profile`. This file is the project-local layer: it owns Tickstrike's snapshot, environment, tooling, data pipeline, and explicit overrides without copying foundation rules.

## Project Snapshot

Tickstrike is a Godot 4.6 project built on the data-driven template base layer. It uses the four spines (data pipeline, boot orchestration, save system, scene routing) and layers action-RPG conventions on top.

## Agent Rules

Agent-specific instructions live in `dev/agent_rules/`. Read them before starting relevant work. Key rules: `sandbox_environment.md` (shell vs. file tools), `lint_before_finish.md` (run linter on changed files), `git_operations.md` (git is read-only — never stage/commit, only suggest commit messages), `save_migrations.md` (never delete migration code without sign-off), `navigation_settings_debug.md` (SceneRouter, Main Menu, settings overlay, and Debug gate work). Dedicated engine validation workflows are opt-in only; do not recommend them as normal implementation verification.

## Dev File Placement

Before creating or moving files under `dev/`, classify by the primary thing the file governs, not by who reads it:

- `dev/agent_rules/`: agent behavior and execution constraints. Use for sandbox, git permissions, lint/test requirements, approval rules, and required agent habits.
- `dev/workflows/`: development process artifacts. Use for plan/spec/sketch/closeout/stage-review formats, lifecycle steps, and how work moves from idea to implementation. Slash-command workflow files live in `dev/workflows/commands/`.
- `dev/standards/`: project output standards. Use for code architecture, naming, scene structure, registries, themes, error guards, data conventions, change-summary tone, and other rules that define what correct repo artifacts look like.
- `dev/skills/`: concrete AI/Godot/GDScript recipes and hazard cards. Use for specific pitfalls, compiler/import failures, API traps, repeatable fixes, and commit/PR formatting references.
- `dev/docs/`: actual design, architecture, planning, and tracking documents. Use for feature plans, system docs, vision docs, archived plans, and product/design content.
- `dev/tools/`: executable tooling and tool-owned prompts. Use for scripts, validators, generators, hooks, and prompt packs used by those tools.

## Operating Rules

**No hard-wrapped prose**: Do not hard-wrap prose lines — let the client handle line wrapping. This is a global rule that applies to all writing, not just commits.

Resolve unknowns by asking me directly during the planning conversation — never emit an `## Open Questions` section or leave unresolved decisions parked in a plan or spec. Stop and ask the moment a decision is unclear; hand over a plan or spec only once every such question has been answered and folded into the relevant Requirement, Design, or Relational Context line.

**Batch questions, never spam**: Ask clarifying questions before you start the work, and batch every question you have into a single AskUserQuestion call (multiple questions in one call is fine). Do not ask another round of questions before I've had a chance to answer the previous one.

**Answer my questions before implementing**: when my message contains a question — even alongside a work request — answer the question in conversation first, before doing the work. If the answer could change what gets built, wait for my confirmation instead of proceeding on assumptions. Never bury the answer in a wrap-up after the implementation is already done.

## Workflow Commands

Command workflows live in `dev/workflows/commands/`. When asked to do a command task, read the matching file before acting and follow it exactly. Slash form, dash form, `cmd <name>`, and natural-language requests are all valid: `/closeout`, `-closeout`, `cmd closeout`, and "close out this work" all mean the `closeout` command and must read `dev/workflows/commands/closeout.md`.

The opencode slash-command files under `.opencode/commands/` are thin entry wrappers only. They must not duplicate the workflow. The final source of truth remains `dev/workflows/commands/`.

Reviews use `dev/workflows/review_standard.md`; command files define the review scope, and the shared review standard defines depth, related-code search, reporting, and verdict language.

- `/closeout` -> `dev/workflows/commands/closeout.md`: closes out completed work — staged changes or a feature branch covering one or more plans (CHANGELOG + TODO + archive plans, optional commit-message suggestion only when explicitly asked).
- `/commit-msg` -> `dev/workflows/commands/commit-msg.md`: suggests a conventional commit message for currently staged changes without staging, committing, pushing, or opening a PR.
- `/deepseek-start` -> `dev/workflows/commands/deepseek-start.md`: loads `AGENTS.md`, startup instructions, and every request-relevant rule, standard, workflow, skill, or doc before acting.
- `/godot-test` -> `dev/workflows/commands/godot-test.md`: runs the safe `/tmp` snapshot Godot test workflow without mutating git or trusting the sandbox mount.
- `/pr-review` -> `dev/workflows/commands/pr-review.md`: reviews the branch against the base branch, then generates a PR title/description without creating files or opening a PR.
- `/stage-review` -> `dev/workflows/commands/stage-review.md`: checks staged changes against the plan spec and standards lint.
- `/research-context` -> `dev/workflows/commands/research-context.md`: retrieves relevant codebase context for an idea, scratchboard entry, draft, or small plan without implementing changes.
- `/spec-discuss` -> `dev/workflows/commands/spec-discuss.md`: inspects a focused target against live code, recommends resolutions for user-authority decisions, and locks the input for a later spec build without editing files.
- `/spec-build` -> `dev/workflows/commands/spec-build.md`: re-verifies live code, writes the final implementation spec, updates its parent or TODO lifecycle pointers, and lints the documentation without implementing code.

## Planning And Docs

When asked to build a plan, implementation spec, or sketch, follow the matching workflow in `dev/workflows/`: `plan_standard.md` for durable feature plans, `sketch_standard.md` for plan-child exploration, and `implementation_spec_standard.md` for the final codebase-verified handoff. "Spec" on its own always means an implementation spec. The normal larger-work flow is probe -> plan -> sketch -> implementation spec; skip the sketch only for small, obvious child boundaries. Narrow actionable work may go from a feature request or probe directly to a standalone implementation spec. Follow the plan lifecycle in `dev/docs/README.md` and `dev/standards/` for any relevant domain standard. Plans and standalone implementation documents go in `dev/docs/plans/` with a one-line pointer in `TODO.md`; a plan's child sketches/specs are pointed to from the parent plan's child overview table instead. When asked to capture an early problem observation, design tension, codebase discussion handoff, or unresolved architectural thought without a chosen implementation direction, use `dev/standards/probe_standard.md`.

## Project Structure

```
assets/           Static assets (sprites, audio files)
common/           Reusable systems (not feature-specific)
  audio/          Event-driven audio (events, bus)
  framework/      State machine pattern
  gameplay/       Gameplay components and grid system
  utils/          Random utilities
data/             Designer resources, domain-first: data/<domain>/definitions/ + domain-owned content
  rewards/        Artifact/ArtifactRegistry schemas and authored reward content
  enemies/        Enemy Resource schemas (EnemyData, EnemyAttackData)
  yaml/sfx/       Human-authored SFX synth patches, rendered via dev/tools/render_sfx.py (SFX domain only)
  tres/           Generated SFX playback resources — do not hand-edit (gitignored, SFX domain only)
dev/              Development tooling and documentation
  agent_rules/    Agent-specific instructions
  docs/           Architecture docs
  skills/         AI coding references
  standards/      Coding conventions
  tools/          Build/lint/test scripts and the SFX synthesis pipeline
  workflows/      Development process formats
game/             Game feature scenes
  meta/           Main Menu and meta flow screens
  shared/         Shared UI, including settings overlay and settings button overlay
global/           Autoloads and project-wide resources
  autoloads/      All autoload scripts
  constants/      Project-wide constants
  theme/          Main theme resource
  utils/          RegistryAudit utility
localization/     Localization files
test/             Unit tests and test runner
```

## Data Pipeline

`data/` is domain-first: the first directory level under `data/` is the content domain (e.g. `data/rewards/`, `data/enemies/`), each owning its own `definitions/` Resource schemas and authored content. There is no project-wide generated-`.tres` rule — a domain only has a generated pipeline if it documents one. SFX is the current example: it is authored as YAML patches under `data/yaml/sfx/*.yaml` and rendered via `dev/tools/render_sfx.py` into WAV + `UiAudioEvent .tres` output under `data/tres/`; never hand-edit those generated WAV or `.tres` files. Other domains' `.tres` content is hand-authored and safe to edit directly. Gameplay data (enemies, player stats) is hand-authored directly as `.tres` resources alongside its feature code — see `dev/docs/archived/enemy_data_backed_structure.md` and `data_driven_player_stats.sketch.md` for why generated data was rejected for that content.

## Conventions

- **Docstrings**: every `.gd` file starts with `# filename` + one-line purpose. All public functions and complex private functions get a `##` GDDoc comment. Never strip or reduce existing comments when editing code.
- **Project structure**: read `dev/standards/project_structure.md` before adding, moving, or reorganizing files.
- **Runtime ownership**: read `dev/standards/runtime_ownership.md` before introducing or renaming Controllers, Systems, Stores, Services, save providers, or other runtime state owners.
- **Commits**: conventional commits format — read `dev/skills/conventional_commits.md` when writing commit messages. Do not hard-wrap prose.
- **Change summaries**: read `dev/standards/change_summary_standard.md` before writing commit messages, PR descriptions, CHANGELOG entries, closeout output, review summaries, or other completed-work summaries.
- **Probes**: read `dev/standards/probe_standard.md` before creating early problem notes, design tension notes, architecture discussion handoffs, or codebase review conclusions that are not implementation plans.
- **Audio events**: use `AudioManager.play_event()` for gameplay, UI, and music playback; read `dev/skills/audio_event_usage.md` before changing audio playback, SFX resources, music, or `AudioManager` call sites.
- **Save providers**: an object that serializes a slice of state must also own that state — no save adapter that only serializes another object's fields.
- **State machines**: the `StateMachine` + `State` framework is behavior-delegation, not a state-label holder; read `dev/skills/state_machine_pattern.md` before changing entity states, FSM scene wiring, or transition logic. For grid enemies, tick runtime, attack/recovery timing, or capped facing, also read `dev/skills/state_machine_tick_grid_addendum.md`.
- **Scene routing**: `SceneRouter` owns production scene transitions; read `dev/standards/scene_routing_standard.md` and `dev/skills/scene_router_usage.md` before changing navigation.
- **Main Menu**: read `dev/standards/main_menu_standard.md` before editing `game/meta/main_menu/`.
- **Settings overlay**: `SettingsStore` owns `user://settings.json`; read `dev/standards/settings_overlay_standard.md` and `dev/skills/settings_overlay_usage.md` before adding settings.
- **Theme and UI styling**: read `dev/standards/theme_standard.md` and `dev/skills/godot4_theme_override.md` before changing fonts, StyleBoxes, theme type variations, or static UI colors.
- **Debug mode**: check `Debug.enabled`, not `OS.is_debug_build()` directly; read `dev/standards/debug_standard.md` and `dev/skills/debug_mode_usage.md` before adding debug behavior.
- **Notifications**: use the `ToastManager` autoload for passive, ephemeral, scene-independent messages. `show_warning(msg)` is always visible, `show_error(msg)` is always visible and logs internally, `show_info(msg)` is debug-only, and `show_dev_error(msg)` is debug-gated on screen but always logged.
- **Error guards**: never use `assert()` for runtime guards. Use explicit `if` guards and read `dev/standards/error_guard_standard.md` before adding or changing precondition checks, ToastManager channel selection, or bare `push_error` / `push_warning` call sites.
- **GDScript abstract APIs**: read `dev/skills/gdscript_abstract.md` before introducing or changing `@abstract` classes or methods.
- **GDScript structure & naming (mandatory gate)**: before the first `Edit`/`Write` touching any `.gd` file in a session, read `dev/standards/gdscript_structure_standard.md` and `dev/standards/naming_conventions.md` in full. Do not gate this on judging whether the change "counts" as adding, renaming, or restructuring — any script touch qualifies, including pure logic edits that add or rename a single function. Persistent scene nodes and runtime `add_child()` exceptions follow `dev/standards/scene_node_source_standard.md`; reusable component layout/preview rules follow `dev/standards/component_scene_standard.md`. Node-source and no-`[connection]` rules are lint-enforced.
- **Versioning**: read `dev/skills/semantic_versioning.md` before release/version bump work or when a change needs public API version impact assessment.
- **Standards**: run `python dev/tools/lint_standards.py --files <changed>` before finishing if you are an agent without the in-loop lint hook. See `dev/standards/standards_enforcement.md` for active checks and how new machine-checkable rules are added.
