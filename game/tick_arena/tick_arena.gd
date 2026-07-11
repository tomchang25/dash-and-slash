# tick_arena.gd
# Tick arena scene root (the production arena route). Composition layer: wires
# the action, preview, and transitional run controllers to their scene collaborators and each other,
# owns the shared run-scoped RunBuild, and keeps the small HUD/debug-panel glue that has not yet
# earned its own controller.
extends Node2D

# -- Constants --

const BACKGROUND_COLOR := Color(0.09, 0.1, 0.12)

# -- Exports --

@export var ninja_class: CharacterClassData
@export var viking_class: CharacterClassData

# -- State --

var _run_build := RunBuild.new()
var _active_class: CharacterClassData
var _danger_telegraph_cells_by_source: Dictionary = { }
var _ninja_class_button: Button
var _viking_class_button: Button
var _guard_shredder_button: Button
var _execution_button: Button
var _chain_dash_button: Button
var _kill_all_enemies_button: Button
var _god_mode_disable_button: Button
var _god_mode_no_damage_button: Button
var _god_mode_undead_button: Button

# -- Node references --

@onready var _grid: GridArena = %GridArena
@onready var _view: TickGridView = %GridView
@onready var _engine: TickEngine = %TickEngine
@onready var _input: TickInput = %TickInput
@onready var _player: TickPlayer = %Player
@onready var _debug_panel: DebugPanel = %DebugPanel
@onready var _action_controller: TickActionController = %TickActionController
@onready var _preview_controller: TickPreviewController = %TickPreviewController
@onready var _run_controller: TickRunController = %TickRunController
@onready var _hud: TickArenaHud = %TickArenaHud
@onready var _build_inspection_panel: BuildInspectionPanel = %BuildInspectionPanel

# == Lifecycle ==


func _ready() -> void:
    _input.verb_requested.connect(_action_controller.handle_verb)
    _engine.world_advanced.connect(_on_world_advanced)
    _engine.attack_detonated.connect(_view.flash_detonation)
    _engine.player_died.connect(_run_controller.handle_player_died)
    _action_controller.state_changed.connect(_refresh_hud)
    _action_controller.state_changed.connect(_refresh_danger)
    _run_controller.reward_applied.connect(_on_reward_applied)
    _run_controller.run_reset_finished.connect(_on_run_reset_finished)
    _run_controller.spawn_warning_changed.connect(_on_spawn_warning_changed)
    _hud.build_pressed.connect(_on_build_button_pressed)
    _hud.settings_pressed.connect(_on_settings_button_pressed)

    RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
    _validate_class_resources()
    _active_class = ninja_class
    _player.setup(_grid, _grid.grid_size / 2, _active_class)
    _action_controller.setup(_run_build, _active_class)
    _preview_controller.setup(_run_build, _active_class)
    _run_controller.setup(_run_build, _active_class)
    _build_inspection_panel.setup(_run_build, _active_class)
    _run_controller.start_first_wave()
    _wire_debug_panel()
    _refresh_danger()
    _refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
    # Player-facing run-reset shortcut; stays ungated regardless of HUD state.
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_R:
            _restart_run()

# == Signal handlers ==


func _on_world_advanced(_tick_count: int) -> void:
    _refresh_danger()
    _refresh_hud()


## A reward may have changed triggers or artifact stacks, so debug/HUD views refresh immediately.
func _on_reward_applied() -> void:
    _refresh_debug_trigger_buttons()
    _refresh_danger()
    _refresh_hud()
    if _build_inspection_panel.visible:
        _build_inspection_panel.refresh()


## A fresh run keeps the selected class but clears triggers, god mode, danger, HUD, and build rows.
func _on_run_reset_finished() -> void:
    _refresh_debug_class_buttons()
    _refresh_debug_trigger_buttons()
    _refresh_debug_god_mode_buttons()
    _refresh_danger()
    _refresh_hud()
    if _build_inspection_panel.visible:
        _build_inspection_panel.refresh()


func _on_spawn_warning_changed(_cells: Array[Vector2i], _ticks: int) -> void:
    _refresh_danger()


func _on_build_button_pressed() -> void:
    _build_inspection_panel.toggle()


## Routes the HUD's settings button through the existing settings overlay toggle path; the HUD
## itself never touches SettingsStore, since it is read-only display state.
func _on_settings_button_pressed() -> void:
    SettingsStore.toggle_overlay()

# == Restart ==


## Delegates to the run controller's in-place reset; the arena root constructs RunBuild once per
## scene and never rebuilds or re-wires it, so every collaborator keeps its original reference.
func _restart_run() -> void:
    _run_controller.reset_run()

# == Debug (see dev/standards/debug_standard.md §4a/§5) ==


## Registers Combat, Player/class, and Dash-Major debug actions.
func _wire_debug_panel() -> void:
    _kill_all_enemies_button = _debug_panel.add_action("Instant Kill All Enemies", _on_debug_kill_all_enemies, "Combat")

    _god_mode_disable_button = _debug_panel.add_action("God Mode - Disable", _on_debug_set_god_mode_disable, "Player")
    _god_mode_no_damage_button = _debug_panel.add_action("God Mode - No Damage", _on_debug_set_god_mode_no_damage, "Player")
    _god_mode_undead_button = _debug_panel.add_action("God Mode - Undead", _on_debug_set_god_mode_undead, "Player")
    _refresh_debug_god_mode_buttons()

    _ninja_class_button = _debug_panel.add_action("Class - Ninja", _on_debug_set_ninja_class, "Player")
    _viking_class_button = _debug_panel.add_action("Class - Viking", _on_debug_set_viking_class, "Player")
    _refresh_debug_class_buttons()
    _guard_shredder_button = _debug_panel.add_action("Guard Shredder", _on_debug_toggle_guard_shredder, "Build")
    _execution_button = _debug_panel.add_action("Execution", _on_debug_toggle_execution, "Build")
    _chain_dash_button = _debug_panel.add_action("Chain Dash", _on_debug_toggle_chain_dash, "Build")
    _refresh_debug_trigger_buttons()


func _on_debug_kill_all_enemies() -> void:
    if not Debug.enabled:
        return
    _run_controller.debug_kill_all_enemies()


func _on_debug_set_god_mode_disable() -> void:
    if not Debug.enabled:
        return
    _set_debug_god_mode(TickPlayer.GodMode.OFF)


func _on_debug_set_god_mode_no_damage() -> void:
    if not Debug.enabled:
        return
    _set_debug_god_mode(TickPlayer.GodMode.NO_DAMAGE)


func _on_debug_set_god_mode_undead() -> void:
    if not Debug.enabled:
        return
    _set_debug_god_mode(TickPlayer.GodMode.UNDEAD)


func _on_debug_set_ninja_class() -> void:
    if not Debug.enabled:
        return
    _set_debug_character_class(ninja_class)


func _on_debug_set_viking_class() -> void:
    if not Debug.enabled:
        return
    _set_debug_character_class(viking_class)


func _on_debug_toggle_guard_shredder() -> void:
    if not Debug.enabled:
        return
    _toggle_debug_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER)


func _on_debug_toggle_execution() -> void:
    if not Debug.enabled:
        return
    _toggle_debug_mobility_trigger(RunBuild.TRIGGER_EXECUTION)


func _on_debug_toggle_chain_dash() -> void:
    if not Debug.enabled:
        return
    _toggle_debug_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH)


## Applies the picked god mode to the player and refreshes the mutually-exclusive button styling.
func _set_debug_god_mode(mode: TickPlayer.GodMode) -> void:
    _player.set_god_mode(mode)
    _refresh_debug_god_mode_buttons()


## Applies a debug class only through a full run reset so no prior class state survives.
func _set_debug_character_class(character_class: CharacterClassData) -> void:
    if character_class == null or character_class == _active_class:
        return
    _action_controller.cancel_smash_windup()
    _active_class = character_class
    _player.set_character_class(character_class)
    _action_controller.set_character_class(character_class)
    _preview_controller.set_character_class(character_class)
    _run_controller.set_character_class(character_class)
    _build_inspection_panel.set_character_class(character_class)
    _restart_run()


## Flips one mobility-slot-triggered Major through the same RunBuild store real Major effects write to.
## Dash triggers toggle independently but are disabled while Viking/Smash is active.
func _toggle_debug_mobility_trigger(trigger_id: StringName) -> void:
    if _active_class == null or _active_class.mobility_id != CharacterClassData.MOBILITY_DASH:
        return
    var next_active := not _run_build.has_mobility_trigger(trigger_id)
    _run_build.set_mobility_trigger(trigger_id, next_active)
    _refresh_debug_trigger_buttons()


## Highlights the active class selected for the current run.
func _refresh_debug_class_buttons() -> void:
    _debug_panel.set_action_active(_ninja_class_button, _active_class == ninja_class)
    _debug_panel.set_action_active(_viking_class_button, _active_class == viking_class)


## Marks the Dash-Major buttons active per the run build's mobility-trigger state and disables them
## while the fixed Viking Smash class is active.
func _refresh_debug_trigger_buttons() -> void:
    var guard_shredder_active := _run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER)
    var execution_active := _run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION)
    var chain_dash_active := _run_build.has_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH)
    var dash_active := _active_class != null and _active_class.mobility_id == CharacterClassData.MOBILITY_DASH
    _guard_shredder_button.text = "Guard Shredder%s" % (" (Active)" if guard_shredder_active else "")
    _execution_button.text = "Execution%s" % (" (Active)" if execution_active else "")
    _chain_dash_button.text = "Chain Dash%s" % (" (Active)" if chain_dash_active else "")
    _guard_shredder_button.disabled = not dash_active
    _execution_button.disabled = not dash_active
    _chain_dash_button.disabled = not dash_active


## Highlights whichever god-mode button matches the player's current god mode through the panel's
## generic active-state styling helper instead of appended button text.
func _refresh_debug_god_mode_buttons() -> void:
    var mode := _player.god_mode
    _debug_panel.set_action_active(_god_mode_disable_button, mode == TickPlayer.GodMode.OFF)
    _debug_panel.set_action_active(_god_mode_no_damage_button, mode == TickPlayer.GodMode.NO_DAMAGE)
    _debug_panel.set_action_active(_god_mode_undead_button, mode == TickPlayer.GodMode.UNDEAD)

# == View and HUD ==


## Pushes the actors' pending attacks to the production telegraph layer, which GridTerrainView paints
## in the enemy-danger palette, and to the debug overlay for the tick countdowns; runs after every
## world advance (hits resolve in stage 1 and are covered by the advance that follows every consumed verb).
func _refresh_danger() -> void:
    _clear_danger_telegraphs()
    var danger: Array[Dictionary] = []
    var spawn_warning := _run_controller.get_spawn_warning_danger()
    if not spawn_warning.is_empty():
        danger.append(spawn_warning)
    for enemy in _engine.actors():
        var enemy_danger := enemy.get_danger()
        if enemy_danger.is_empty():
            continue
        danger.append(enemy_danger)
        var cells: Array[Vector2i] = enemy_danger["cells"]
        var phase := GridArena.TelegraphPhase.CHARGE if int(enemy_danger["ticks"]) <= 1 else GridArena.TelegraphPhase.WARNING
        _grid.set_telegraph(enemy, cells, phase)
        _danger_telegraph_cells_by_source[enemy] = cells.duplicate()
    _view.set_danger(danger)


func _clear_danger_telegraphs() -> void:
    for source in _danger_telegraph_cells_by_source.keys():
        var cells: Array[Vector2i] = _danger_telegraph_cells_by_source[source]
        _grid.clear_telegraph(source, cells)
    _danger_telegraph_cells_by_source.clear()


## Builds a plain-data snapshot from the existing owners and hands it to the HUD presenter to render
## the presenter never reaches into player/run-build/run-controller state itself.
func _refresh_hud() -> void:
    if _active_class == null:
        return
    _hud.render(
        {
            "hp": _player.hp,
            "max_hp": _player.max_hp(_run_build.total(RunBuild.CH_MAX_HEALTH)),
            "class_name": _active_class.display_name,
            "mobility_id": _active_class.mobility_id,
            "dash_cooldown": _player.dash_cooldown,
            "smash_cooldown": _player.smash_cooldown,
            "speed_meter": _player.speed_meter,
            "speed_meter_max": TickPlayer.SPEED_METER_MAX,
            "speed_meter_ready": _player.is_speed_meter_full(),
            "tick_count": _engine.tick_count(),
            "wave_display_text": _run_controller.get_wave_display_text(),
            "artifact_rows": BuildInspectionFormatter.build_artifact_rows(_run_build),
        },
    )

# == Character classes ==


## Reports invalid authored class resources before any run collaborator consumes them.
func _validate_class_resources() -> void:
    if ninja_class == null:
        ToastManager.show_dev_error("TickArena: Ninja CharacterClassData is not assigned")
    else:
        ninja_class.validate()
    if viking_class == null:
        ToastManager.show_dev_error("TickArena: Viking CharacterClassData is not assigned")
    else:
        viking_class.validate()
