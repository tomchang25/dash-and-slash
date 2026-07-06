# tick_arena.gd
# Tick arena scene root (debug-only until cutover; run the scene directly). Composition layer: wires
# the action, preview, and transitional run controllers to their scene collaborators and each other,
# owns the shared run-scoped RunBuild, and keeps the small HUD/debug-panel glue that has not yet
# earned its own controller.
extends Node2D

# -- Constants --

const BACKGROUND_COLOR := Color(0.09, 0.1, 0.12)

# -- State --

var _run_build := RunBuild.new()
var _dash_payload_button: Button
var _smash_payload_button: Button
var _guard_shredder_button: Button
var _execution_button: Button

# -- Node references --

@onready var _grid: GridArena = %GridArena
@onready var _view: TickGridView = %GridView
@onready var _engine: TickEngine = %TickEngine
@onready var _input: TickInput = %TickInput
@onready var _player: TickPlayer = %Player
@onready var _stats_label: Label = %StatsLabel
@onready var _controls_label: Label = %ControlsLabel
@onready var _debug_panel: DebugPanel = %DebugPanel
@onready var _action_controller: TickActionController = %TickActionController
@onready var _preview_controller: TickPreviewController = %TickPreviewController
@onready var _run_controller: TickRunController = %TickRunController

# == Lifecycle ==


func _ready() -> void:
    _input.verb_requested.connect(_action_controller.handle_verb)
    _engine.world_advanced.connect(_on_world_advanced)
    _engine.attack_detonated.connect(_view.flash_detonation)
    _engine.player_died.connect(_run_controller.handle_player_died)
    _action_controller.state_changed.connect(_refresh_hud)
    _action_controller.wave_cleared.connect(_run_controller.handle_wave_cleared)
    _run_controller.reward_applied.connect(_on_reward_applied)
    _run_controller.run_reset_finished.connect(_on_run_reset_finished)

    RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
    _player.setup(_grid, _grid.grid_size / 2)
    _action_controller.setup(_run_build)
    _preview_controller.setup(_run_build)
    _run_controller.setup(_run_build)
    _run_controller.start_first_wave()
    _controls_label.text = "WASD step · Hold Alt for Mobility Mode · LMB confirm · RMB cancel · Space wait · R reset"
    _wire_debug_panel()
    _refresh_danger()
    _refresh_hud()


func _unhandled_input(event: InputEvent) -> void:
    # Debug-only arena shortcut; production never routes here until cutover replaces it.
    if event is InputEventKey and event.pressed and not event.echo:
        if event.physical_keycode == KEY_R:
            _run_controller.reset_run("Run reset.")

# == Signal handlers ==


func _on_world_advanced(_tick_count: int) -> void:
    _refresh_danger()
    _refresh_hud()


## A reward may have changed the run build's mobility payload or triggers, so the debug panel's
## button highlighting must catch up alongside the new wave's danger telegraphs.
func _on_reward_applied() -> void:
    _refresh_debug_payload_buttons()
    _refresh_debug_trigger_buttons()
    _refresh_danger()


func _on_run_reset_finished() -> void:
    _refresh_danger()
    _refresh_hud()

# == Debug (see dev/standards/debug_standard.md §4a/§5) ==


## Registers the Major-effect debug controls: the mobility-payload buttons from Phase 04a, plus the
## Guard Shredder and Execution toggles this phase adds through that same extension point.
func _wire_debug_panel() -> void:
    _dash_payload_button = _debug_panel.add_action("Dash Payload", _on_debug_set_dash_payload)
    _smash_payload_button = _debug_panel.add_action("Smash Payload", _on_debug_set_smash_payload)
    _refresh_debug_payload_buttons()
    _guard_shredder_button = _debug_panel.add_action("Guard Shredder", _on_debug_toggle_guard_shredder)
    _execution_button = _debug_panel.add_action("Execution", _on_debug_toggle_execution)
    _refresh_debug_trigger_buttons()


func _on_debug_set_dash_payload() -> void:
    if not Debug.enabled:
        return
    _set_debug_mobility_payload(RunBuild.PAYLOAD_DASH)


func _on_debug_set_smash_payload() -> void:
    if not Debug.enabled:
        return
    _set_debug_mobility_payload(RunBuild.PAYLOAD_SMASH)


func _on_debug_toggle_guard_shredder() -> void:
    if not Debug.enabled:
        return
    _toggle_debug_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER, "Guard Shredder")


func _on_debug_toggle_execution() -> void:
    if not Debug.enabled:
        return
    _toggle_debug_mobility_trigger(RunBuild.TRIGGER_EXECUTION, "Execution")


## Writes through the same RunBuild override real Major effects use, so debug behavior stays
## representative of perk behavior instead of a parallel scene-only flag.
func _set_debug_mobility_payload(payload: StringName) -> void:
    _action_controller.cancel_smash_windup()
    _run_build.set_mobility_payload_override(payload)
    _action_controller.set_message("Mobility slot: %s" % _mobility_mode_name())
    _refresh_debug_payload_buttons()
    _refresh_hud()


## Flips one mobility-slot-triggered Major through the same RunBuild store real Major effects write to.
## Guard Shredder and Execution toggle independently so both can be tested alone, together, and
## alongside either mobility payload before reward-loop acquisition exists.
func _toggle_debug_mobility_trigger(trigger_id: StringName, display_name: String) -> void:
    var next_active := not _run_build.has_mobility_trigger(trigger_id)
    _run_build.set_mobility_trigger(trigger_id, next_active)
    _action_controller.set_message("%s: %s" % [display_name, "ON" if next_active else "OFF"])
    _refresh_debug_trigger_buttons()


## Marks whichever payload button matches the run build's current mobility payload as active, so the
## panel stays the readable source of truth instead of the player needing to remember hidden state.
func _refresh_debug_payload_buttons() -> void:
    var payload := _run_build.get_mobility_payload()
    _dash_payload_button.text = "Dash Payload%s" % (" (Active)" if payload == RunBuild.PAYLOAD_DASH else "")
    _smash_payload_button.text = "Smash Payload%s" % (" (Active)" if payload == RunBuild.PAYLOAD_SMASH else "")


## Marks the Guard Shredder / Execution buttons active per the run build's mobility-trigger state, the
## same readability convention the payload buttons use.
func _refresh_debug_trigger_buttons() -> void:
    var guard_shredder_active := _run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER)
    var execution_active := _run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION)
    _guard_shredder_button.text = "Guard Shredder%s" % (" (Active)" if guard_shredder_active else "")
    _execution_button.text = "Execution%s" % (" (Active)" if execution_active else "")

# == View and HUD ==


## Pushes the actors' pending attacks to the production telegraph layer, which GridTerrainView paints
## in the enemy-danger palette, and to the debug overlay for the tick countdowns; runs after every
## world advance (hits resolve in stage 1 and are covered by the advance that follows every consumed verb).
func _refresh_danger() -> void:
    _grid.clear_all_telegraphs()
    var danger: Array[Dictionary] = []
    for enemy in _engine.actors():
        var enemy_danger := enemy.get_danger()
        if enemy_danger.is_empty():
            continue
        danger.append(enemy_danger)
        var cells: Array[Vector2i] = enemy_danger["cells"]
        var phase := GridArena.TelegraphPhase.CHARGE if int(enemy_danger["ticks"]) <= 1 else GridArena.TelegraphPhase.WARNING
        _grid.set_telegraph(enemy, cells, phase)
    _view.set_danger(danger)


func _refresh_hud() -> void:
    _stats_label.text = "HP %d/%d    Dash CD %d    Smash CD %d    Mode: %s    Mobility: %s    Tick %d\nSpeed Energy %d/%d (+%d/action) %s\n%s" % [
        int(_player.hp),
        int(_player.max_hp(_run_build.total(RunBuild.CH_MAX_HEALTH))),
        _player.dash_cooldown,
        _player.smash_cooldown,
        _action_controller.aim_mode_name(),
        _mobility_mode_name(),
        _engine.tick_count(),
        _player.speed_meter,
        TickPlayer.SPEED_METER_MAX,
        _player.speed_meter_fill_for(_run_build.total(RunBuild.CH_SPEED)),
        "— NEXT MOVE/ATTACK FREE" if _player.is_speed_meter_full() else "",
        _action_controller.current_message(),
    ]


func _mobility_mode_name() -> String:
    var payload := _run_build.get_mobility_payload()
    if payload == RunBuild.PAYLOAD_DASH:
        return "DASH"
    if payload == RunBuild.PAYLOAD_SMASH:
        return "SMASH"
    if payload == RunBuild.PAYLOAD_DEBUG_STUB:
        return "DEBUG STUB"
    return "UNKNOWN"
