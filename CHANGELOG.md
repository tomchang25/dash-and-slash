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

### Tick Arena HUD Refactor

- 2026-07-09 — [ui] The tick arena's debug text HUD is replaced with a production-style combat HUD: layered HP/Speed resource bars, cooldown chips, a compact owned-artifact strip, and top-right settings access, with Speed-spend/Mobility-refund notices moved to toasts

### Tick Artifact Rewards

- 2026-07-08 — [rewards] Rewards now ship as Resource-backed artifact cards with distinct flat rolls, milestone Minor x2/Major offers, automatic curse reveals, and an on-demand build inspection panel

### Tick Arena Combat Feedback And Aim

- 2026-07-08 — [combat] Result presentation (HUD outcome messages, Major-trigger VFX/SFX) moves out of TickActionController into a dedicated TickCombatFeedback, and aim/plan resolution is shared between the action and preview controllers through a TickAimContext instead of two duplicated wrapper sets

### Tick Arena Fixes

- 2026-07-08 — [combat] Mobility attacks now apply stagger-burst damage consistently for Dash and Smash, and player mobility cooldowns tick on consumed actions even when Speed grants a free action
- 2026-07-08 — [waves] Wave spawns now expose player-action countdown warnings and keep spawn danger telegraphs visible through arena danger refreshes
- 2026-07-08 — [enemy] ChargeEnemy uses a five-cell line charge range without changing ModeEnemy's full-line behavior

### Tick Arena Structure Consolidation

- 2026-07-07 — [combat] Tick arena combat contracts are consolidated around shared planning rules, one run-scoped build store that resets in place, and typed verb/hit-outcome values so preview and committed action paths share the same math without changing player-facing behavior

### Tick Enemy Ownership

- 2026-07-07 — [enemy] Enemy behavior ownership is fully settled onto the tick engine: hit resolution and path planning are shared stateless helpers, each enemy owns a per-enemy tick combat runtime for telegraph/recovery timing, the state machine is narrowed to a decide-only intent layer (plan, step, turn, commit, stagger, dead), and the leftover real-time chase/cooldown code path is deleted now that every production enemy is tick-bound

### Tick Run Loop

- 2026-07-07 — [combat] The tick arena now plays a full player-clocked run loop end to end — waves, reward choice, milestone elites, death, and restart — with automatic per-wave terrain mutation frozen out of the loop
- 2026-07-07 — [waves] Wave spawning is counted in player actions: spawn warnings count down in ticks, concurrent population stays in the low tick-world range, and overflow enemies queue and drain as kills free space
- 2026-07-07 — [combat] Tick arena code is promoted into its own feature-root layout (combat, player, wave, reward, view) instead of living as a tangled stage subfolder
- 2026-07-06 — [combat] Reward effects apply through the run-scoped build store as shared cross-system truth, so the tick player projects damage, range, health, speed, and cooldown from recorded channels instead of legacy real-time player APIs
- 2026-07-06 — [combat] Action resolution, previews, and run flow are split into scene-scoped controllers, reducing the arena root to composition and signal wiring

### Tick Speed Stats

- 2026-07-06 — [combat] Player speed is now data-driven: a shared Speed meter fills from moves and normal attacks to grant a free action, Mobility Cooldown reduces the active slot's cooldown, and a Mobility Free Action Major refunds mobility strikes that kill, guard-break, or hit from behind

### Tick Mobility, Majors, And Rewards

- 2026-07-06 — [combat] Dash lands on the grid with preview-is-truth targeting — a landing ghost and per-victim angle/result badges computed by the same hit math that resolves the commit — and the mobility slot becomes an ability-override seam
- 2026-07-06 — [combat] Smash ships as the first slot-replacing Major (a windup leap-and-slam) on that seam, driven by command-style input: hold Alt for mobility mode, click to confirm, arm the windup then release
- 2026-07-06 — [combat] Guard Shredder and Execution ship as mobility-slot-triggered Majors that fire for whichever payload occupies the slot, with previews showing the upgraded outcome honestly
- 2026-07-06 — [combat] A minimal tick reward loop (wave clear, three-choice reward, next wave) lets these Majors and the Minor effects be earned in the arena, with debug-panel toggles for every Major ahead of the reward wiring

### Tick Combat Conversion

- 2026-07-05 — [combat] Production enemies now run on the tick engine — telegraph countdowns count player actions, movement snaps one cell per action, and enemy-to-player damage resolves as a cell-membership check at detonation instead of physics overlap
- 2026-07-05 — [combat] A playable player-clocked tick arena productionizes the prototype's tick scheduler, one-tick player verbs, and input feel, reusing the production terrain and autotile grid presentation instead of grey-box drawing

### Tick Combat Prototype

- 2026-07-05 — [combat] Grey-box prototype validated the player-clocked tick combat direction with a go verdict: grid player with four one-tick verbs, three-stage tick resolution, telegraphed melee and charger enemies, a dash/smash mobility slot with windup grammar, and free mouse aiming that never advances time
- 2026-07-05 — [combat] Playtest tuning folded in before the verdict: previews extended from geometry-only to resolved outcomes (landing ghost plus per-victim angle/result badges sharing the commit's hit math), and melee pursuit slowed to speed 75 on the energy skeleton so chases leak distance instead of locking on

### Reward Effect Rework

- 2026-07-04 — [rewards] A reward option can no longer offer the same effect twice, closing a rare duplicate-effect gap in the fallback roll
- 2026-07-04 — [rewards] Terrain mutation (relocating or removing land) is now a fixed, automatic event once per normal wave clear instead of a pickable reward card, so terrain no longer swings unpredictably from stacked picks
- 2026-07-04 — [rewards] Reward effects are now self-contained objects with their own eligibility and apply logic, recording every numeric contribution into a run-scoped store that player stats and wave pressure project from, replacing the old shared enum-and-switch dispatch
- 2026-07-04 — [rewards] Three new enemy-toughness pressure rewards (health, damage, defense) join the existing enemy-count pressure option, filling the pool slot terrain mutation used to occupy
- 2026-07-04 — [rewards] Behavior-changing (Major) reward effects are now capped at four active per run and can be marked mutually exclusive, proven end-to-end via the existing placeholder Major effect ahead of any real one shipping

### Player Attack Range Scale

- 2026-07-03 — [player] Normal attack reach and dash travel distance are now data-driven, run-mutable stats instead of hardcoded constants, each offered as its own Minor wave reward (Longer Reach, Longer Dash)

### Player Death & Restart Panel

- 2026-07-03 — [player] Player death now shows a restart banner that reloads a fresh arena run, clears surviving enemies and elite HUD state on run end, and includes debug-only god-mode and instant-kill controls for testing the death flow

### Infinite Wave Mode

- 2026-07-03 — [waves] Wave progression no longer ends at a fixed boss wave; waves continue indefinitely, with a milestone elite enemy spawning every 5th wave in place of the old one-time final boss
- 2026-07-03 — [waves] Concurrent enemy population is capped and the cap rises with milestone tier; once a wave's spawn count exceeds the cap the remaining enemies queue and spawn as population drains from kills
- 2026-07-03 — [enemy] Spawned enemies scale hp, outgoing damage, and flat defense by milestone tier so later waves stay challenging without hand-authored per-wave stat data
- 2026-07-03 — [rewards] Milestone waves automatically grant a fixed Expand Land bonus alongside the normal reward choice, called out in the reward overlay
- 2026-07-03 — [waves] The run now ends on player death instead of on boss clear

### Enemy Kind Unification

- 2026-07-02 — [enemy] Tile and point attacks across every enemy kind now run through two shared executors — one owning cell footprint, per-cell telegraph, and per-cell hitboxes; the other owning single-hitbox damage/interval/guard configuration and enablement — replacing the per-kind ModeEnemyAttackController and hand-rolled hitbox setup
- 2026-07-02 — [enemy] Every enemy kind locates its attack-related child nodes (hitboxes, telegraph) through the same scene-wired unique-name references instead of mixed runtime lookups
- 2026-07-02 — [enemy] Enemy kinds no longer restate state-identity getters that only echo the shared lifecycle default; a remaining override now reliably signals a genuine per-kind behavioral difference
- 2026-07-02 — [enemy] ChargeEnemy and ModeEnemy's CHARGE mode now share one charge-traversal implementation, so arrival snapping, per-cell telegraph clearing, and mid-charge streak VFX look and feel identical regardless of which enemy kind performs the charge

### Remove Unused Entity YAML→Tres Pipeline

- 2026-07-02 — [data_pipeline] Removed the generated entity YAML→tres pipeline, its registry base class, and the unused example scaffolding (never adopted by shipped enemy/player data and broken on a missing module); the `/godot-test` snapshot setup no longer depends on it; the SFX YAML→wav/tres synthesis pipeline is unchanged

### Roguelite Wave Reward Loop

- 2026-06-30 — [waves] Run progresses through four normal waves and a wave 5 boss; enemy counts are data-driven with base counts of 5–8 plus accumulated future enemy pressure modifiers from rewards
- 2026-06-30 — [rewards] Clearing a normal wave presents three reward choices from Conservative, Balanced, and Aggressive profiles; selection applies immediately and advances the run
- 2026-06-30 — [rewards] Minor stat rewards modify normal attack damage/cooldown, dash attack damage/cooldown, and max/current health through run-local player stat data; Major placeholder resolves safely without class behavior changes
- 2026-06-30 — [rewards] Terrain cards claim one adjacent sea cell and remove one safe connected land cell without isolating the landmass; pressure cards increase future normal/support enemy counts
- 2026-06-30 — [player] Each wave start repositions the player to a safe land cell near the arena center before enemy spawn planning
- 2026-06-30 — [boss] Boss death force-clears remaining support enemies and pending spawn telegraphs before the run completes

### Combat Feedback VFX

- 2026-06-29 — [enemy] Charge enemies display directional windup pulses and dash streaks; guarded hits show blue shield spark, guard breaks show white flash with blue fragments, and staggers show red damage burst
- 2026-06-29 — [enemy] Puff enemy gains a charge windup state with radial telegraph pulses and a readable dodge window before expansion

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
