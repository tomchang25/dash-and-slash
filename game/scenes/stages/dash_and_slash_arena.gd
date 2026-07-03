@tool
# dash_and_slash_arena.gd
# Main game scene for Dash & Slash. Contains the dynamic GridArena, Player,
# Camera2D, HUD, reward UI, and scene-level wiring.
extends Node2D

const REWARD_OPEN_DELAY := 2.0
const WAVE_BANNER_FADE := 0.35

@onready var _grid: GridArena = %GridArena
@onready var _player: Player = %Player
@onready var _hp_label: Label = %HpLabel
@onready var _dash_label: Label = %DashLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _boss_guard_label: Label = %BossGuardLabel
@onready var _wave_banner_overlay: Control = %WaveBannerOverlay
@onready var _wave_banner_label: Label = %WaveBannerLabel
@onready var _death_banner_overlay: Control = %DeathBannerOverlay
@onready var _restart_button: Button = %RestartButton
@onready var _reward_overlay: WaveRewardOverlay = %WaveRewardOverlay
@onready var _debug_panel: DebugPanel = %DebugPanel

var _wave_controller: WaveController
var _wave_banner_tween: Tween
var _reward_delay_tween: Tween
var _reward_controller: WaveRewardChoiceController
var _spawn_planner: EnemySpawnPlanner
var _spawner: EnemySpawner
var _reward_rng: RandomNumberGenerator
var _current_elite: ModeEnemy
var _elite_stagger_callback: Callable
var _god_mode_button: Button


func _ready() -> void:
    if Engine.is_editor_hint():
        return

    _restart_button.pressed.connect(_on_restart_pressed)

    if _player.has_method("setup"):
        _player.setup(_grid)
    _player.setup_run_stats()

    _spawn_planner = EnemySpawnPlanner.new(_grid, _player)
    _spawner = EnemySpawner.new(_grid, _player, self)
    _wave_controller = WaveController.new()
    _wave_controller.setup(self, _grid, _spawn_planner, _spawner)
    _wave_controller.wave_gap_started.connect(_on_wave_gap_started)
    _wave_controller.wave_gap_finished.connect(_on_wave_gap_finished)
    _wave_controller.wave_started.connect(_on_wave_started)
    _wave_controller.normal_wave_completed.connect(_on_normal_wave_complete)
    _wave_controller.elite_spawned.connect(_on_elite_spawned)
    _wave_controller.elite_cleared.connect(_on_elite_cleared)

    _reward_rng = RandomNumberGenerator.new()
    _reward_rng.randomize()
    var reward_generator := WaveRewardChoiceGenerator.new(_reward_rng)
    var reward_applier := WaveRewardApplier.new(_grid, _player, _add_future_enemy_bonus, _reward_rng)
    _reward_controller = WaveRewardChoiceController.new(
        _reward_overlay,
        reward_generator,
        reward_applier,
        _grid,
        _player,
    )
    _reward_controller.choice_applied.connect(_on_reward_choice_applied)

    _player.health_changed.connect(_on_player_health_changed)
    _player.died.connect(_on_player_died)
    _player.emit_health_snapshot()

    _boss_guard_label.visible = false

    _wire_debug_panel()
    _wave_controller.start_next_wave()


func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        return
    _update_dash_label()


func _on_player_health_changed(current: float, maximum: float) -> void:
    _hp_label.text = "HP: %d / %d" % [int(current), int(maximum)]


func _on_boss_guard_changed(current: int, maximum: int) -> void:
    var shields := current / 4
    var max_shields := maximum / 4
    var s := ""
    for i in max_shields:
        s += "[" + ("\u2593" if i < shields else "\u2591") + "] "
    _boss_guard_label.text = "Boss Guard: " + s


func _update_dash_label() -> void:
    var cd := 0.0
    if _player.has_method("get_dash_cooldown"):
        cd = _player.get_dash_cooldown()
    var status := "READY" if cd <= 0.0 else "CD: %.1f" % cd
    _dash_label.text = "Dash: " + status


func _on_wave_gap_started(display_text: String) -> void:
    _show_wave_banner(display_text)


func _on_wave_gap_finished() -> void:
    _hide_wave_banner()


func _on_wave_started(display_text: String, is_milestone_wave: bool) -> void:
    _wave_label.text = display_text
    _boss_guard_label.visible = is_milestone_wave
    _wave_label.visible = false


func _on_elite_spawned(enemy: Node) -> void:
    var elite := enemy as ModeEnemy
    if elite == null:
        return
    _current_elite = elite
    _elite_stagger_callback = func() -> void: _boss_guard_label.text = "GUARD BROKEN - STAGGERED!"
    elite.guard_changed.connect(_on_boss_guard_changed)
    elite.guard_stagger_started.connect(_elite_stagger_callback)
    elite.emit_guard_snapshot()


func _on_elite_cleared() -> void:
    _disconnect_elite_signals()
    _boss_guard_label.visible = false


func _on_player_died(_entity: Player) -> void:
    _wave_controller.end_run()
    _disconnect_elite_signals()
    _boss_guard_label.visible = false
    if _reward_delay_tween != null and _reward_delay_tween.is_valid():
        _reward_delay_tween.kill()
    if _player.has_method("set_input_locked"):
        _player.set_input_locked(true)
    _hide_wave_banner()
    _death_banner_overlay.visible = true


func _on_restart_pressed() -> void:
    SceneRouter.go_to_arena()


func _on_normal_wave_complete(_wave_number: int, is_milestone_wave: bool) -> void:
    if _player.has_method("set_input_locked"):
        _player.set_input_locked(true)
    if is_milestone_wave:
        _grant_milestone_expand_land()
    _show_wave_banner("WAVE END")
    _reward_delay_tween = create_tween()
    _reward_delay_tween.tween_interval(REWARD_OPEN_DELAY)
    _reward_delay_tween.tween_callback(_open_reward_choice.bind(is_milestone_wave))


func _grant_milestone_expand_land() -> void:
    for i in WaveScaling.EXPAND_LAND_AMOUNT:
        _grid.add_random_connected_land(_reward_rng)


func _open_reward_choice(is_milestone_wave: bool = false) -> void:
    if _wave_controller.is_run_over():
        return
    _move_player_to_safe_center_cell()
    var wave_number := _wave_controller.get_wave_number()
    _reward_controller.open_reward_choice(wave_number, _reward_target_points(wave_number), is_milestone_wave)


func _on_reward_choice_applied() -> void:
    if _player.has_method("set_input_locked"):
        _player.set_input_locked(false)
    _wave_controller.start_next_wave()


func _add_future_enemy_bonus(amount: int) -> void:
    _wave_controller.add_future_enemy_count(amount)


func _reward_target_points(wave_number: int) -> float:
    return float(max(wave_number - 1, 0))


func _move_player_to_safe_center_cell() -> void:
    var player_cell := _grid.world_to_grid(_player.global_position)
    var target_cell := player_cell if _grid.is_walkable(player_cell) and _grid.is_empty(player_cell) else _grid.nearest_empty_cell(_player.global_position)
    _player.global_position = _grid.cell_center(target_cell)
    _grid.set_player_cell(_player.global_position)


func _disconnect_elite_signals() -> void:
    if _current_elite == null or not is_instance_valid(_current_elite):
        _current_elite = null
        return
    if _current_elite.guard_changed.is_connected(_on_boss_guard_changed):
        _current_elite.guard_changed.disconnect(_on_boss_guard_changed)
    if _elite_stagger_callback.is_valid() and _current_elite.guard_stagger_started.is_connected(_elite_stagger_callback):
        _current_elite.guard_stagger_started.disconnect(_elite_stagger_callback)
    _current_elite = null


func _show_wave_banner(text: String) -> void:
    if _wave_banner_tween != null and _wave_banner_tween.is_valid():
        _wave_banner_tween.kill()
    _wave_banner_label.text = text
    _wave_banner_overlay.modulate.a = 0.0
    _wave_banner_overlay.visible = true
    _wave_banner_tween = create_tween()
    _wave_banner_tween.tween_property(_wave_banner_overlay, "modulate:a", 1.0, WAVE_BANNER_FADE)
    _wave_banner_tween.tween_interval(max(WaveController.WAVE_GAP - WAVE_BANNER_FADE * 2.0, 0.0))
    _wave_banner_tween.tween_property(_wave_banner_overlay, "modulate:a", 0.0, WAVE_BANNER_FADE)


func _hide_wave_banner() -> void:
    if _wave_banner_tween != null and _wave_banner_tween.is_valid():
        _wave_banner_tween.kill()
    _wave_banner_overlay.visible = false
    _wave_banner_overlay.modulate.a = 1.0

# -- Debug (see dev/standards/debug_standard.md §4a/§5) -----------------------


func _wire_debug_panel() -> void:
    _debug_panel.add_action("Instant Dash", _on_debug_instant_dash)
    _debug_panel.add_action("Kill All Enemies", _on_debug_kill_all_enemies)
    _debug_panel.add_action("Add Tile", _on_debug_add_tile)
    _debug_panel.add_action("Remove Tile", _on_debug_remove_tile)
    _debug_panel.add_action("Move Tile", _on_debug_move_tile)
    _god_mode_button = _debug_panel.add_action("God Mode: Off", _on_debug_cycle_god_mode)
    _debug_panel.add_action("Instant Kill", _on_debug_instant_kill)


func _on_debug_instant_dash() -> void:
    if not Debug.enabled:
        return
    _player.debug_force_dash_ready()


func _on_debug_kill_all_enemies() -> void:
    if not Debug.enabled:
        return
    _wave_controller.force_kill_all_enemies()


func _on_debug_cycle_god_mode() -> void:
    if not Debug.enabled:
        return
    var mode := _player.debug_cycle_god_mode()
    _god_mode_button.text = "God Mode: %s" % _god_mode_label(mode)


func _on_debug_instant_kill() -> void:
    if not Debug.enabled:
        return
    _player.debug_instant_kill()


func _on_debug_add_tile() -> void:
    if not Debug.enabled:
        return
    _grid.add_random_connected_land()


func _on_debug_remove_tile() -> void:
    if not Debug.enabled:
        return
    _grid.remove_random_safe_connected_land()


func _on_debug_move_tile() -> void:
    if not Debug.enabled:
        return
    _grid.move_random_safe_land()


func _god_mode_label(mode: Health.GodMode) -> String:
    match mode:
        Health.GodMode.OFF:
            return "Off"
        Health.GodMode.UNDEAD:
            return "Undead"
        Health.GodMode.NO_DAMAGE:
            return "No-Damage"
    ToastManager.show_dev_error("Arena: unexpected god mode %s" % mode)
    return "Off"
