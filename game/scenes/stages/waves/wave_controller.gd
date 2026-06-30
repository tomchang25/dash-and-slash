# wave_controller.gd
# Scene-local RefCounted that owns wave progression, spawn flow, alive enemies, and future pressure modifier.
class_name WaveController
extends RefCounted

signal wave_gap_started(display_text: String)
signal wave_gap_finished
signal wave_started(display_text: String, is_boss_wave: bool)
signal normal_wave_completed(wave_number: int)
signal boss_spawned(boss: Node)
signal boss_cleared
signal run_completed

const WAVE_DEFINITIONS := [
    { "index": 1, "kind": "normal", "base_count": 5 },
    { "index": 2, "kind": "normal", "base_count": 6 },
    { "index": 3, "kind": "normal", "base_count": 7 },
    { "index": 4, "kind": "normal", "base_count": 8 },
    { "index": 5, "kind": "boss", "boss_id": "first_boss", "support_base_count": 8 },
]
const SmallEnemyScene := preload("res://game/entities/enemies/small_enemy.tscn")
const PuffEnemyScene := preload("res://game/entities/enemies/puff_enemy.tscn")
const ChargeEnemyScene := preload("res://game/entities/enemies/charge_enemy.tscn")
const BossScene := preload("res://game/entities/enemies/mode_enemy.tscn")

const SUPPORT_ENEMY_SCENES := [SmallEnemyScene, PuffEnemyScene, ChargeEnemyScene]
const WAVE_GAP := 2.0
const SPAWN_TELEGRAPH_DURATION := 0.8

var _current_wave_index := -1
var _future_enemy_count_modifier := 0
var _grid: GridArena
var _spawn_planner: EnemySpawnPlanner
var _spawner: EnemySpawner
var _alive_enemies: Array[Node] = []
var _pending_spawns: Array[Dictionary] = []
var _boss_ref: Node = null
var _boss_resolving := false
var _wave_gap_timer: Timer
var _spawn_telegraph_timer: Timer

# == Common API ==


## Wires the scene collaborators needed for timed wave flow and enemy spawning.
func setup(timer_parent: Node, grid: GridArena, spawn_planner: EnemySpawnPlanner, spawner: EnemySpawner) -> void:
    _grid = grid
    _spawn_planner = spawn_planner
    _spawner = spawner
    _ensure_timers(timer_parent)


## Advances to the next wave and starts its pre-wave gap.
func start_next_wave() -> void:
    if advance_wave():
        wave_gap_started.emit(get_wave_display_text())
        if _wave_gap_timer != null:
            _wave_gap_timer.start(WAVE_GAP)
        else:
            _begin_wave()


## Returns the current wave definition, or an empty Dictionary before the first wave.
func get_current_wave() -> Dictionary:
    if _current_wave_index < 0 or _current_wave_index >= WAVE_DEFINITIONS.size():
        return { }
    return WAVE_DEFINITIONS[_current_wave_index]


## Advances to the next wave. Returns false if there are no more waves.
func advance_wave() -> bool:
    _current_wave_index += 1
    return _current_wave_index < WAVE_DEFINITIONS.size()


## Returns true when the current wave is a boss wave.
func is_boss_wave() -> bool:
    return get_current_wave().get("kind", "") == "boss"


## Returns the number of support enemies to spawn for the current wave,
## including any future enemy count modifier.
func get_support_spawn_count() -> int:
    var wave := get_current_wave()
    if wave.is_empty():
        return 0
    var base := 0
    if wave["kind"] == "boss":
        base = int(wave.get("support_base_count", 0))
    else:
        base = int(wave.get("base_count", 0))
    return base + _future_enemy_count_modifier


## Returns 1 for boss waves, 0 otherwise.
func get_boss_spawn_count() -> int:
    return 1 if is_boss_wave() else 0


## Adds non-negative future enemy count pressure to subsequent waves.
func add_future_enemy_count(amount: int) -> void:
    _future_enemy_count_modifier += max(amount, 0)


## Returns the 1-based wave number for display (1-5).
func get_wave_number() -> int:
    return _current_wave_index + 1


## Returns the text shown for the current wave.
func get_wave_display_text() -> String:
    if is_boss_wave():
        return "Final Wave: BOSS"
    return "Wave %d" % get_wave_number()


## Resets all state for a fresh run.
func reset() -> void:
    _current_wave_index = -1
    _future_enemy_count_modifier = 0
    _alive_enemies.clear()
    _pending_spawns.clear()
    _boss_ref = null
    _boss_resolving = false

# == Wave Flow ==


func _begin_wave() -> void:
    wave_started.emit(get_wave_display_text(), is_boss_wave())
    _prepare_pending_spawns()
    _show_spawn_telegraphs()


func _prepare_pending_spawns() -> void:
    _pending_spawns.clear()
    var reserved_spawn_cells: Array[Vector2i] = []

    var support_count := get_support_spawn_count()
    for i in support_count:
        var picked: PackedScene = SUPPORT_ENEMY_SCENES[randi() % SUPPORT_ENEMY_SCENES.size()]
        var cell := _spawn_planner.choose_enemy_spawn_cell(i, max(support_count, 1), reserved_spawn_cells)
        reserved_spawn_cells.append(cell)
        _pending_spawns.append({ "scene": picked, "cell": cell })

    if is_boss_wave():
        var boss_cell := _spawn_planner.choose_enemy_spawn_cell(0, 1, reserved_spawn_cells)
        _pending_spawns.append({ "scene": BossScene, "cell": boss_cell })


func _show_spawn_telegraphs() -> void:
    var telegraph_cells: Array[Vector2i] = []
    for pending_spawn in _pending_spawns:
        var cell: Vector2i = pending_spawn["cell"]
        telegraph_cells.append(cell)
    _grid.set_telegraph(self, telegraph_cells, GridArena.TelegraphPhase.SPAWNING)
    _spawn_telegraph_timer.start(SPAWN_TELEGRAPH_DURATION)


func _spawn_pending_enemies() -> void:
    var cells: Array[Vector2i] = []
    for pending_spawn in _pending_spawns:
        var cell: Vector2i = pending_spawn["cell"]
        cells.append(cell)
    _grid.clear_telegraph(self, cells)

    for pending_spawn in _pending_spawns:
        var scene: PackedScene = pending_spawn["scene"]
        var spawn_cell: Vector2i = pending_spawn["cell"]
        var enemy := _spawner.spawn_enemy(scene, spawn_cell, Callable(self, "_on_enemy_died"))
        if enemy == null:
            continue
        _alive_enemies.append(enemy)
        if scene == BossScene:
            _boss_ref = enemy
            boss_spawned.emit(enemy)

    _pending_spawns.clear()


func _clear_pending_spawn_telegraphs() -> void:
    if _pending_spawns.is_empty():
        return
    var cells: Array[Vector2i] = []
    for pending_spawn in _pending_spawns:
        var cell: Vector2i = pending_spawn["cell"]
        cells.append(cell)
    _grid.clear_telegraph(self, cells)
    _pending_spawns.clear()


func _resolve_boss_wave() -> void:
    _boss_resolving = true
    _clear_pending_spawn_telegraphs()

    var remaining := _alive_enemies.duplicate()
    for enemy in remaining:
        var grid_enemy := enemy as GridEnemy
        if grid_enemy != null:
            grid_enemy.force_death()

    _alive_enemies.clear()
    _boss_resolving = false
    run_completed.emit()

# == Signal handlers ==


func _on_wave_gap_timeout() -> void:
    wave_gap_finished.emit()
    _begin_wave()


func _on_spawn_telegraph_timeout() -> void:
    _spawn_pending_enemies()


func _on_enemy_died(enemy: Entity) -> void:
    _alive_enemies.erase(enemy)
    _grid.unregister_occupant(enemy)

    if _boss_resolving:
        return

    if _boss_ref != null and enemy == _boss_ref:
        _boss_ref = null
        boss_cleared.emit()
        _resolve_boss_wave()
    elif _alive_enemies.is_empty():
        normal_wave_completed.emit(get_wave_number())

# == Timer Setup ==


func _ensure_timers(timer_parent: Node) -> void:
    if _wave_gap_timer == null:
        _wave_gap_timer = Timer.new()
        _wave_gap_timer.one_shot = true
        _wave_gap_timer.timeout.connect(_on_wave_gap_timeout)
        # node-src: timer
        timer_parent.add_child(_wave_gap_timer)

    if _spawn_telegraph_timer == null:
        _spawn_telegraph_timer = Timer.new()
        _spawn_telegraph_timer.one_shot = true
        _spawn_telegraph_timer.timeout.connect(_on_spawn_telegraph_timeout)
        # node-src: timer
        timer_parent.add_child(_spawn_telegraph_timer)
