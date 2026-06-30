@tool
# dash_and_slash_arena.gd
# Main game scene for Dash & Slash. Contains the dynamic GridArena, Player,
# Camera2D, and HUD. Manages the run flow: four normal waves into a boss gate.
# Spawns enemies, tracks alive counts, transitions waves.
extends Node2D

const SmallEnemyScene := preload("res://game/entities/enemies/small_enemy.tscn")
const PuffEnemyScene := preload("res://game/entities/enemies/puff_enemy.tscn")
const ChargeEnemyScene := preload("res://game/entities/enemies/charge_enemy.tscn")
const BossScene := preload("res://game/entities/enemies/mode_enemy.tscn")

const ENEMY_POOL := [SmallEnemyScene, PuffEnemyScene, ChargeEnemyScene]

const WAVE_GAP := 2.0
const WAVE_BANNER_FADE := 0.35
const SPAWN_TELEGRAPH_DURATION := 0.8
const ENEMY_SPAWN_MIN_RADIUS := 2.0
const ENEMY_SPAWN_MAX_RADIUS := 6.0
const ENEMY_SPAWN_OUTWARD_BIAS := 1.8
const ENEMY_SPAWN_RADIUS_JITTER := 1.25
const ENEMY_SPAWN_RESERVED_DISTANCE_WEIGHT := 0.45
const ENEMY_SPAWN_RANDOM_SCORE_WEIGHT := 0.3

@onready var _grid: GridArena = %GridArena
@onready var _player: Player = %Player
@onready var _hp_label: Label = %HpLabel
@onready var _dash_label: Label = %DashLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _boss_guard_label: Label = %BossGuardLabel
@onready var _wave_banner_overlay: Control = %WaveBannerOverlay
@onready var _wave_banner_label: Label = %WaveBannerLabel
@onready var _reward_overlay: WaveRewardOverlay = %WaveRewardOverlay

var _wave_controller: WaveController
var _alive_enemies: Array[Node] = []
var _pending_spawns: Array[Dictionary] = []
var _wave_gap_timer: Timer
var _spawn_telegraph_timer: Timer
var _wave_banner_tween: Tween
var _boss_ref: CharacterBody2D = null
var _boss_resolving: bool = false
var _reward_controller: WaveRewardChoiceController


func _ready() -> void:
    if Engine.is_editor_hint():
        return

    if _player.has_method("setup"):
        _player.setup(_grid)

    _wave_controller = WaveController.new()

    _wave_gap_timer = Timer.new()
    _wave_gap_timer.one_shot = true
    _wave_gap_timer.timeout.connect(_on_wave_gap_timeout)
    add_child(_wave_gap_timer)

    _spawn_telegraph_timer = Timer.new()
    _spawn_telegraph_timer.one_shot = true
    _spawn_telegraph_timer.timeout.connect(_on_spawn_telegraph_timeout)
    add_child(_spawn_telegraph_timer)

    var reward_rng := RandomNumberGenerator.new()
    reward_rng.randomize()
    var reward_generator := WaveRewardChoiceGenerator.new(reward_rng)
    var reward_applier := WaveRewardApplier.new(_grid, _player, _add_future_enemy_bonus, reward_rng)
    _reward_controller = WaveRewardChoiceController.new(
        _reward_overlay,
        reward_generator,
        reward_applier,
        _grid,
        _player,
    )
    _reward_controller.choice_applied.connect(_on_reward_choice_applied)

    _player.health_changed.connect(_on_player_health_changed)
    _player.emit_health_snapshot()

    _boss_guard_label.visible = false

    _start_next_wave()


func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        return
    _update_dash_label()


func _start_next_wave() -> void:
    if _wave_controller.advance_wave():
        _start_wave_gap()


func _begin_wave() -> void:
    _wave_label.text = _wave_display_text()
    if _wave_controller.is_boss_wave():
        _boss_guard_label.visible = true
    _wave_label.visible = false

    _pending_spawns.clear()
    var reserved_spawn_cells: Array[Vector2i] = []
    var telegraph_cells: Array[Vector2i] = []

    var support_count := _wave_controller.get_support_spawn_count()
    for i in support_count:
        var picked: PackedScene = ENEMY_POOL[randi() % ENEMY_POOL.size()]
        var cell := _choose_enemy_spawn_cell(i, max(support_count, 1), reserved_spawn_cells)
        reserved_spawn_cells.append(cell)
        _pending_spawns.append({ "scene": picked, "cell": cell })
        telegraph_cells.append(cell)

    if _wave_controller.is_boss_wave():
        var boss_cell := _choose_enemy_spawn_cell(0, 1, reserved_spawn_cells)
        _pending_spawns.append({ "scene": BossScene, "cell": boss_cell })
        telegraph_cells.append(boss_cell)

    _grid.set_telegraph(self, telegraph_cells, GridArena.TelegraphPhase.SPAWNING)
    _spawn_telegraph_timer.start(SPAWN_TELEGRAPH_DURATION)


func _on_spawn_telegraph_timeout() -> void:
    var cells: Array[Vector2i] = []
    for s in _pending_spawns:
        cells.append(s["cell"])
    _grid.clear_telegraph(self, cells)

    for s in _pending_spawns:
        _spawn_enemy(s["scene"], s["cell"])
    _pending_spawns.clear()


func _spawn_enemy(picked: PackedScene, spawn_cell: Vector2i) -> void:
    var enemy: Node = picked.instantiate()
    enemy.global_position = _grid.cell_center(spawn_cell)

    if enemy.has_method("setup"):
        enemy.setup(_grid, _player)

    if not enemy.has_signal("died"):
        push_warning("enemy missing died signal")
        return

    enemy.died.connect(func(e: Entity) -> void: _on_enemy_died(e))
    add_child(enemy)
    _alive_enemies.append(enemy)

    if picked == BossScene:
        _boss_ref = enemy
        var boss := enemy as ModeEnemy
        if boss != null:
            boss.guard_changed.connect(_on_boss_guard_changed)
            boss.guard_stagger_started.connect(func() -> void: _boss_guard_label.text = "GUARD BROKEN - STAGGERED!")
            boss.emit_guard_snapshot()


## Picks a spawn cell from available LAND cells, spreading each wave from inner to outer bands.
func _choose_enemy_spawn_cell(index: int, spawn_count: int, reserved_spawn_cells: Array[Vector2i]) -> Vector2i:
    var player_cell := _grid.world_to_grid(_player.global_position)
    var candidates := _get_available_enemy_spawn_cells(player_cell, reserved_spawn_cells)
    if not candidates.is_empty():
        var target_radius := _enemy_spawn_target_radius(index, spawn_count, player_cell, candidates)
        return _pick_enemy_spawn_candidate(candidates, player_cell, reserved_spawn_cells, target_radius)

    var empty_cell := _choose_any_empty_spawn_cell(player_cell, reserved_spawn_cells)
    if empty_cell != Vector2i(-1, -1):
        return empty_cell

    var walkable_cell := _choose_any_walkable_spawn_cell(player_cell, reserved_spawn_cells)
    return walkable_cell if walkable_cell != Vector2i(-1, -1) else player_cell


## Collects currently valid LAND cells for enemy spawn reservation.
func _get_available_enemy_spawn_cells(player_cell: Vector2i, reserved_spawn_cells: Array[Vector2i]) -> Array[Vector2i]:
    var candidates: Array[Vector2i] = []
    for x in _grid.grid_size.x:
        for y in _grid.grid_size.y:
            var candidate := Vector2i(x, y)
            if _is_enemy_spawn_cell_available(candidate, player_cell, reserved_spawn_cells):
                candidates.append(candidate)
    return candidates


## Returns the preferred ring radius for this enemy, biased toward inner rings while expanding outward.
func _enemy_spawn_target_radius(index: int, spawn_count: int, player_cell: Vector2i, candidates: Array[Vector2i]) -> float:
    var available_outer_radius := ENEMY_SPAWN_MIN_RADIUS
    for candidate in candidates:
        available_outer_radius = max(available_outer_radius, _cell_distance(player_cell, candidate))

    var outer_radius: float = min(ENEMY_SPAWN_MAX_RADIUS, available_outer_radius)
    var inner_radius: float = min(ENEMY_SPAWN_MIN_RADIUS, outer_radius)
    var progress := 0.0
    if spawn_count > 1:
        progress = float(index) / float(spawn_count - 1)
    progress = pow(progress, ENEMY_SPAWN_OUTWARD_BIAS)

    var target_radius := lerpf(inner_radius, outer_radius, progress)
    target_radius += randf_range(-ENEMY_SPAWN_RADIUS_JITTER, ENEMY_SPAWN_RADIUS_JITTER)
    return clamp(target_radius, inner_radius, outer_radius)


## Picks the lowest-scoring candidate for the target radius while spreading away from reserved spawns.
func _pick_enemy_spawn_candidate(
        candidates: Array[Vector2i],
        player_cell: Vector2i,
        reserved_spawn_cells: Array[Vector2i],
        target_radius: float,
) -> Vector2i:
    candidates.shuffle()
    var best_cell := candidates[0]
    var best_score := INF

    for candidate in candidates:
        var radius_error := absf(_cell_distance(player_cell, candidate) - target_radius)
        var score := radius_error
        if not reserved_spawn_cells.is_empty():
            var nearest_reserved_distance := _nearest_reserved_spawn_distance(candidate, reserved_spawn_cells)
            score -= min(nearest_reserved_distance / max(target_radius, 1.0), 1.0) * ENEMY_SPAWN_RESERVED_DISTANCE_WEIGHT
        score += randf() * ENEMY_SPAWN_RANDOM_SCORE_WEIGHT

        if score < best_score:
            best_score = score
            best_cell = candidate

    return best_cell


## Randomly picks any empty LAND cell as a simple fallback.
func _choose_any_empty_spawn_cell(player_cell: Vector2i, reserved_spawn_cells: Array[Vector2i]) -> Vector2i:
    var candidates := _get_available_enemy_spawn_cells(player_cell, reserved_spawn_cells)
    if candidates.is_empty():
        return Vector2i(-1, -1)
    candidates.shuffle()
    return candidates[0]


## Final fallback that allows overlapping enemies but still requires LAND.
func _choose_any_walkable_spawn_cell(player_cell: Vector2i, reserved_spawn_cells: Array[Vector2i]) -> Vector2i:
    var candidates: Array[Vector2i] = []
    var overlapping_candidates: Array[Vector2i] = []
    for x in _grid.grid_size.x:
        for y in _grid.grid_size.y:
            var candidate := Vector2i(x, y)
            if candidate == player_cell:
                continue
            if not _grid.is_walkable(candidate):
                continue
            overlapping_candidates.append(candidate)
            if not reserved_spawn_cells.has(candidate):
                candidates.append(candidate)
    if candidates.is_empty():
        candidates = overlapping_candidates
    if candidates.is_empty():
        return Vector2i(-1, -1)
    candidates.shuffle()
    return candidates[0]


func _is_enemy_spawn_cell_available(cell: Vector2i, player_cell: Vector2i, reserved_spawn_cells: Array[Vector2i]) -> bool:
    return (
        cell != player_cell
        and not reserved_spawn_cells.has(cell)
        and _grid.is_in_bounds(cell)
        and _grid.is_walkable(cell)
        and _grid.is_empty(cell)
    )


func _nearest_reserved_spawn_distance(cell: Vector2i, reserved_spawn_cells: Array[Vector2i]) -> float:
    var nearest_distance := INF
    for reserved_cell in reserved_spawn_cells:
        nearest_distance = min(nearest_distance, _cell_distance(cell, reserved_cell))
    return nearest_distance


func _cell_distance(a: Vector2i, b: Vector2i) -> float:
    return Vector2(a - b).length()


func _on_enemy_died(enemy: Entity) -> void:
    _alive_enemies.erase(enemy)
    _grid.unregister_occupant(enemy)

    if _boss_resolving:
        return

    if _boss_ref != null and enemy == _boss_ref:
        _boss_ref = null
        _boss_guard_label.visible = false
        _resolve_boss_wave()
    elif _alive_enemies.is_empty():
        _on_normal_wave_complete()


func _resolve_boss_wave() -> void:
    _boss_resolving = true
    _pending_spawns.clear()

    var remaining := _alive_enemies.duplicate()
    for e in remaining:
        var ge := e as GridEnemy
        if ge != null:
            ge.force_death()

    _wave_label.modulate.a = 1.0
    _wave_label.visible = true
    _wave_label.text = "RUN COMPLETE!"
    _boss_resolving = false


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


func _on_normal_wave_complete() -> void:
    if _player.has_method("set_input_locked"):
        _player.set_input_locked(true)
    _show_wave_banner("WAVE END")
    var delay := create_tween()
    delay.tween_interval(WAVE_GAP)
    delay.tween_callback(_open_reward_choice)


func _open_reward_choice() -> void:
    _move_player_to_safe_center_cell()
    var wave_number := _wave_controller.get_wave_number()
    _reward_controller.open_reward_choice(wave_number, _reward_target_points(wave_number))


func _on_reward_choice_applied() -> void:
    if _player.has_method("set_input_locked"):
        _player.set_input_locked(false)
    _start_next_wave()


func _add_future_enemy_bonus(amount: int) -> void:
    _wave_controller.add_future_enemy_count(amount)


func _reward_target_points(wave_number: int) -> float:
    return float(max(wave_number - 1, 0))


func _move_player_to_safe_center_cell() -> void:
    var player_cell := _grid.world_to_grid(_player.global_position)
    var target_cell := player_cell if _grid.is_walkable(player_cell) and _grid.is_empty(player_cell) else _grid.nearest_empty_cell(_player.global_position)
    _player.global_position = _grid.cell_center(target_cell)
    _grid.set_player_cell(_player.global_position)


func _start_wave_gap() -> void:
    _show_wave_banner(_wave_display_text())
    _wave_gap_timer.start(WAVE_GAP)


func _on_wave_gap_timeout() -> void:
    _hide_wave_banner()
    _begin_wave()


func _show_wave_banner(text: String) -> void:
    if _wave_banner_tween != null and _wave_banner_tween.is_valid():
        _wave_banner_tween.kill()
    _wave_banner_label.text = text
    _wave_banner_overlay.modulate.a = 0.0
    _wave_banner_overlay.visible = true
    _wave_banner_tween = create_tween()
    _wave_banner_tween.tween_property(_wave_banner_overlay, "modulate:a", 1.0, WAVE_BANNER_FADE)
    _wave_banner_tween.tween_interval(max(WAVE_GAP - WAVE_BANNER_FADE * 2.0, 0.0))
    _wave_banner_tween.tween_property(_wave_banner_overlay, "modulate:a", 0.0, WAVE_BANNER_FADE)


func _hide_wave_banner() -> void:
    if _wave_banner_tween != null and _wave_banner_tween.is_valid():
        _wave_banner_tween.kill()
    _wave_banner_overlay.visible = false
    _wave_banner_overlay.modulate.a = 1.0


func _wave_display_text() -> String:
    if _wave_controller.is_boss_wave():
        return "Final Wave: BOSS"
    return "Wave %d" % _wave_controller.get_wave_number()
