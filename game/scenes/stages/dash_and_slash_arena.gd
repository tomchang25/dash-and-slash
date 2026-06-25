@tool
# dash_and_slash_arena.gd
# Main game scene for Dash & Slash. Contains the 6x6 GridArena, Player,
# Camera2D, and HUD. Manages the run flow: Wave 1 → Wave 2 → Boss.
# Spawns enemies, tracks alive counts, transitions waves.
extends Node2D

enum Wave { NO_WAVE = -1, WAVE_1 = 0, WAVE_2 = 1, BOSS = 2, COMPLETE = 3 }

const SmallEnemyScene := preload("res://game/entities/enemies/small_enemy.tscn")
const BossScene := preload("res://game/entities/enemies/boss.tscn")

const WAVES := {
    Wave.WAVE_1: { "count": 3, "scene": SmallEnemyScene },
    Wave.WAVE_2: { "count": 3, "scene": SmallEnemyScene },
    Wave.BOSS: { "count": 1, "scene": BossScene },
}

const WAVE_GAP := 1.2
const GRASS_TILE_SIZE := 16.0
const GRASS_SOURCE_ID := 0
const GRASS_ATLAS_SIZE := Vector2i(16, 16)
const ENEMY_SPAWN_OFFSETS := [
    Vector2i(2, 0),
    Vector2i(-2, 0),
    Vector2i(0, 2),
    Vector2i(0, -2),
    Vector2i(2, 1),
    Vector2i(-2, 1),
    Vector2i(1, 2),
    Vector2i(1, -2),
    Vector2i(2, -1),
    Vector2i(-2, -1),
    Vector2i(-1, 2),
    Vector2i(-1, -2),
]

@onready var _grass_tiles: TileMapLayer = $TileMapLayer
@onready var _grid: GridArena = $GridArena
@onready var _player = $Player
@onready var _hp_label: Label = $HUD/VBox/HpLabel
@onready var _dash_label: Label = $HUD/VBox/DashLabel
@onready var _wave_label: Label = $HUD/VBox/WaveLabel
@onready var _boss_guard_label: Label = $HUD/VBox/BossGuardLabel

var _current_wave: int = Wave.NO_WAVE
var _alive_enemies: Array[Node] = []
var _wave_gap_timer: Timer
var _boss_ref: CharacterBody2D = null


func _ready() -> void:
    _fill_arena_grass()
    if Engine.is_editor_hint():
        return

    if _player.has_method("setup"):
        _player.setup(_grid)

    var cam: Camera2D = $Player/Camera2D as Camera2D
    if cam != null:
        cam.make_current()

    _wave_gap_timer = Timer.new()
    _wave_gap_timer.one_shot = true
    _wave_gap_timer.timeout.connect(_start_next_wave)
    # node-src: timer
    add_child(_wave_gap_timer)

    if _player.has_node("Health"):
        var hp := _player.get_node("Health") as Health
        hp.health_changed.connect(_on_player_health_changed)
        _on_player_health_changed(hp.current(), hp.max_health)

    _boss_guard_label.visible = false

    _start_next_wave()


func _fill_arena_grass() -> void:
    _grass_tiles.clear()
    var total := Vector2(GridArena.GRID_SIZE) * _grid.tile_size
    _grass_tiles.position = _grid.position - total * 0.5

    var rng := RandomNumberGenerator.new()
    rng.randomize()
    var tile_count := Vector2i(total / GRASS_TILE_SIZE)
    for x in tile_count.x:
        for y in tile_count.y:
            var atlas_coords := Vector2i(
                rng.randi_range(0, GRASS_ATLAS_SIZE.x - 1),
                rng.randi_range(0, GRASS_ATLAS_SIZE.y / 2 - 1),
            )
            _grass_tiles.set_cell(Vector2i(x, y), GRASS_SOURCE_ID, atlas_coords)


func _process(_delta: float) -> void:
    if Engine.is_editor_hint():
        return
    _update_dash_label()


func _start_next_wave() -> void:
    match _current_wave:
        Wave.NO_WAVE:
            _begin_wave(Wave.WAVE_1)
        Wave.WAVE_1:
            _begin_wave(Wave.WAVE_2)
        Wave.WAVE_2:
            _begin_wave(Wave.BOSS)
        Wave.BOSS:
            _begin_wave(Wave.COMPLETE)


func _begin_wave(wave: int) -> void:
    _current_wave = wave

    match wave:
        Wave.WAVE_1:
            _wave_label.text = "Wave 1"
        Wave.WAVE_2:
            _wave_label.text = "Wave 2"
        Wave.BOSS:
            _wave_label.text = "BOSS"
            _boss_guard_label.visible = true
        Wave.COMPLETE:
            _wave_label.text = "RUN COMPLETE"
            return

    _wave_label.visible = true
    var info: Dictionary = WAVES.get(wave, { })
    var count: int = info.get("count", 0)
    var scene: PackedScene = info.get("scene")

    for i in count:
        _spawn_enemy(scene, i)


func _spawn_enemy(scene: PackedScene, index: int) -> void:
    var enemy := scene.instantiate()
    var spawn_cell := _choose_enemy_spawn_cell(index)
    enemy.global_position = _grid.cell_center(spawn_cell)

    if enemy.has_method("setup"):
        enemy.setup(_grid, _player)

    if not enemy.has_signal("died"):
        push_warning("enemy missing died signal")
        return

    enemy.died.connect(func(e: Entity) -> void: _on_enemy_died(e))
    add_child(enemy)
    _alive_enemies.append(enemy)

    if _current_wave == Wave.BOSS:
        _boss_ref = enemy
        if enemy.has_node("Guard"):
            var g := enemy.get_node("Guard") as Guard
            if g != null:
                g.guard_changed.connect(_on_boss_guard_changed)
                g.stagger_started.connect(func() -> void: _boss_guard_label.text = "GUARD BROKEN — STAGGERED!")
                g.stagger_ended.connect(func() -> void: _on_boss_guard_changed(g.current(), g.max_guard))


func _choose_enemy_spawn_cell(index: int) -> Vector2i:
    var player_cell := _grid.world_to_grid(_player.global_position)
    for i in ENEMY_SPAWN_OFFSETS.size():
        var offset: Vector2i = ENEMY_SPAWN_OFFSETS[(index + i) % ENEMY_SPAWN_OFFSETS.size()]
        var candidate := player_cell + offset
        if _is_enemy_spawn_cell_available(candidate, player_cell):
            return candidate

    var best := Vector2i(-1, -1)
    var best_distance := INF
    for x in GridArena.GRID_SIZE.x:
        for y in GridArena.GRID_SIZE.y:
            var candidate := Vector2i(x, y)
            if not _is_enemy_spawn_cell_available(candidate, player_cell):
                continue
            var distance := Vector2(candidate).distance_squared_to(Vector2(player_cell))
            if distance < best_distance:
                best_distance = distance
                best = candidate

    return best if best != Vector2i(-1, -1) else player_cell


func _is_enemy_spawn_cell_available(cell: Vector2i, player_cell: Vector2i) -> bool:
    return cell != player_cell and _grid.is_in_bounds(cell) and _grid.is_empty(cell)


func _on_enemy_died(enemy: Entity) -> void:
    _alive_enemies.erase(enemy)
    _grid.unregister_occupant(enemy)

    if _alive_enemies.is_empty():
        if _current_wave == Wave.BOSS:
            _boss_ref = null
            _boss_guard_label.visible = false
            _current_wave = Wave.COMPLETE
            _wave_label.text = "RUN COMPLETE!"
        else:
            _wave_label.visible = false
            _wave_gap_timer.start(WAVE_GAP)


func _on_player_health_changed(current: float, maximum: float) -> void:
    _hp_label.text = "HP: %d / %d" % [int(current), int(maximum)]


func _on_boss_guard_changed(current: int, maximum: int) -> void:
    var shields := current / 4
    var max_shields := maximum / 4
    var s := ""
    for i in max_shields:
        s += "[" + ("▓" if i < shields else "░") + "] "
    _boss_guard_label.text = "Boss Guard: " + s


func _update_dash_label() -> void:
    var cd := 0.0
    if _player.has_method("get_dash_cooldown"):
        cd = _player.get_dash_cooldown()
    var status := "READY" if cd <= 0.0 else "CD: %.1f" % cd
    _dash_label.text = "Dash: " + status
