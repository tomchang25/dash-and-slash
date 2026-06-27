# Agent Startup

## Required Startup

Read this file before answering any repository-specific question or doing any work in this repo. If you entered through `AGENTS.md` or `CLAUDE.md`, continue here and treat this file as the shared source of truth.

## Project Snapshot

Dash & Slash is a Godot 4.6 project built on the data-driven template base layer. It uses the four spines (data pipeline, boot orchestration, save system, scene routing) and layers action-RPG conventions on top.

## Agent Rules

Agent-specific instructions live in `dev/agent_rules/`. Read them before starting relevant work. Key rules: `sandbox_environment.md` (shell vs. file tools), `lint_before_finish.md` (run linter on changed files), `git_operations.md` (git is read-only — never stage/commit, only suggest commit messages), `godot_test_check.md` (never run Godot against the mount — use the /tmp snapshot procedure, and `/tmp` must be container-native, not a Windows bind mount), `godot_tests.md` (how to run the GUT unit suite), `save_migrations.md` (never delete migration code without sign-off), `navigation_settings_debug.md` (SceneRouter, Main Menu, settings overlay, and Debug gate work).

## Dev File Placement

Before creating or moving files under `dev/`, classify by the primary thing the file governs, not by who reads it:

- `dev/agent_rules/`: agent behavior and execution constraints. Use for sandbox, git permissions, lint/test requirements, headless checks, approval rules, and required agent habits.
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

- `/closeout` -> `dev/workflows/commands/closeout.md`: closes out completed work — staged changes or a feature branch covering one or more plans (CHANGELOG + TODO + archive plans, optional commit-message suggestion only when explicitly asked).
- `/commit-msg` -> `dev/workflows/commands/commit-msg.md`: suggests a conventional commit message for currently staged changes without staging, committing, pushing, or opening a PR.
- `/godot-test` -> `dev/workflows/commands/godot-test.md`: runs the safe `/tmp` snapshot Godot test workflow without mutating git or trusting the sandbox mount.
- `/pr-review` -> `dev/workflows/commands/pr-review.md`: reviews the branch against the base branch, then generates a PR title/description without creating files or opening a PR.
- `/stage-review` -> `dev/workflows/commands/stage-review.md`: checks staged changes against the plan spec and standards lint.
- `/research-context` -> `dev/workflows/commands/research-context.md`: retrieves relevant codebase context for an idea, scratchboard entry, draft, or small plan without implementing changes.

## Planning And Docs

When asked to build a plan, implementation spec, or sketch, follow the matching workflow in `dev/workflows/` (`plan_standard.md`, `implementation_spec_standard.md`, `sketch_standard.md`), the plan lifecycle in `dev/docs/README.md`, and `dev/standards/` for any relevant domain standard. Plans and sketches go in `dev/docs/plans/` with a one-line pointer in `TODO.md`.

## Project Structure

```
assets/           Static assets (sprites, audio files)
common/           Reusable systems (not feature-specific)
  audio/          Event-driven audio (events, bus)
  framework/      State machine pattern
  gameplay/       Gameplay components and grid system
  utils/          Random utilities
data/             Designer resources
  definitions/    Resource class scripts (.gd)
  yaml/           Human-authored YAML source data
  tres/           Generated from yaml — do not hand-edit (gitignored)
dev/              Development tooling and documentation
  agent_rules/    Agent-specific instructions
  docs/           Architecture docs
  skills/         AI coding references
  standards/      Coding conventions
  tools/          YAML pipeline scripts
  workflows/      Development process formats
game/             Game feature scenes
  meta/           Main Menu and meta flow screens
  shared/         Shared UI, including settings overlay and settings button overlay
global/           Autoloads and project-wide resources
  autoloads/      All autoload scripts
  constants/      DataPaths
  theme/          Main theme resource
  utils/          RegistryAudit utility
localization/     Localization files
test/             Unit tests and test runner
```

## Data Pipeline

Entities are authored in `data/yaml/*.yaml`, converted to `.tres` via `dev/tools/yaml_to_tres.py`. Validate with `dev/tools/validate_yaml.py`. Reverse with `dev/tools/tres_to_yaml.py`. Never hand-edit `.tres` files under `data/tres/`.

## Conventions

- **Docstrings**: every `.gd` file starts with `# filename` + one-line purpose. All public functions and complex private functions get a `##` GDDoc comment. Never strip or reduce existing comments when editing code.
- **Commits**: conventional commits format — read `dev/skills/conventional_commits.md` when writing commit messages. Do not hard-wrap prose.
- **Registries**: extend `ResourceRegistry`; required API: `get_<singular>_by_id`, `get_all_<plural>`, `size`. See `dev/standards/registries.md`.
- **Save providers**: an object that serializes a slice of state must also own that state — no save adapter that only serializes another object's fields.
- **Scene routing**: `SceneRouter` owns production scene transitions; read `dev/standards/scene_routing_standard.md` and `dev/skills/scene_router_usage.md` before changing navigation.
- **Main Menu**: read `dev/standards/main_menu_standard.md` before editing `game/meta/main_menu/`.
- **Settings overlay**: `SettingsStore` owns `user://settings.json`; read `dev/standards/settings_overlay_standard.md` and `dev/skills/settings_overlay_usage.md` before adding settings.
- **Theme and UI styling**: read `dev/standards/theme_standard.md` and `dev/skills/godot4_theme_override.md` before changing fonts, StyleBoxes, theme type variations, or static UI colors.
- **Debug mode**: check `Debug.enabled`, not `OS.is_debug_build()` directly; read `dev/standards/debug_standard.md` and `dev/skills/debug_mode_usage.md` before adding debug behavior.
- **GDScript structure & scene architecture**: scripts follow `dev/standards/gdscript_structure_standard.md`; persistent scene nodes and runtime `add_child()` exceptions follow `dev/standards/scene_node_source_standard.md`; reusable component layout/preview rules follow `dev/standards/component_scene_standard.md`. Node-source and no-`[connection]` rules are lint-enforced.
- **Standards**: run `python dev/tools/lint_standards.py --files <changed>` before finishing if you are an agent without the in-loop lint hook.
