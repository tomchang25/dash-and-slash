# wave_controller.gd
# Scene-local RefCounted that owns wave progression, spawn flow, alive enemies, and future pressure modifier.
class_name WaveController
extends RefCounted

signal wave_gap_started(display_text: String)
signal wave_gap_finished
signal wave_started(display_text: String, is_milestone_wave: bool)
signal normal_wave_completed(wave_number: int, is_milestone_wave: bool)
signal elite_spawned(elite: Node)
signal elite_cleared

const SmallEnemyScene := preload("res://game/entities/enemies/small_enemy.tscn")
const PuffEnemyScene := preload("res://game/entities/enemies/puff_enemy.tscn")
const ChargeEnemyScene := preload("res://game/entities/enemies/charge_enemy.tscn")
const EliteScene := preload("res://game/entities/enemies/mode_enemy.tscn")

const SUPPORT_ENEMY_SCENES := [SmallEnemyScene, PuffEnemyScene, ChargeEnemyScene]
const WAVE_GAP := 2.0
const SPAWN_TELEGRAPH_DURATION := 0.8

var _current_wave_number := 0
var _future_enemy_count_modifier := 0
var _grid: GridArena
var _spawn_planner: EnemySpawnPlanner
var _spawner: EnemySpawner
var _alive_enemies: Array[Node] = []
var _spawn_queue: Array[Dictionary] = []
var _current_batch: Array[Dictionary] = []
var _elite_ref: Node = null
var _run_over := false
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


## Advances to the next wave number. Always advances unless the run has ended.
func advance_wave() -> bool:
    if _run_over:
        return false
    _current_wave_number += 1
    return true


## Returns true when the current wave is a milestone elite wave.
func is_milestone_wave() -> bool:
    return WaveScaling.is_milestone_wave(_current_wave_number)


## Returns the number of support enemies to spawn for the current wave,
## including any future enemy count modifier.
func get_support_spawn_count() -> int:
    if _current_wave_number <= 0:
        return 0
    return WaveScaling.get_support_count(_current_wave_number) + _future_enemy_count_modifier


## Returns 1 for milestone waves (elite spawn), 0 otherwise.
func get_elite_spawn_count() -> int:
    return 1 if is_milestone_wave() else 0


## Adds non-negative future enemy count pressure to subsequent waves.
func add_future_enemy_count(amount: int) -> void:
    _future_enemy_count_modifier += max(amount, 0)


## Returns the 1-based current wave number.
func get_wave_number() -> int:
    return _current_wave_number


## Returns the text shown for the current wave.
func get_wave_display_text() -> String:
    if is_milestone_wave():
        return "Wave %d: ELITE" % get_wave_number()
    return "Wave %d" % get_wave_number()


## Stops all further wave progression and spawning, and force-kills every enemy
## still alive so nothing keeps pathing/attacking against the input-locked
## player. Called on player death.
func end_run() -> void:
    _run_over = true
    _clear_spawn_queue_telegraphs()
    if _wave_gap_timer != null:
        _wave_gap_timer.stop()
    if _spawn_telegraph_timer != null:
        _spawn_telegraph_timer.stop()
    _kill_all_alive_enemies()


## Returns true once end_run() has been called for the current run.
func is_run_over() -> bool:
    return _run_over


## Resets all state for a fresh run.
func reset() -> void:
    _current_wave_number = 0
    _future_enemy_count_modifier = 0
    _alive_enemies.clear()
    _spawn_queue.clear()
    _current_batch.clear()
    _elite_ref = null
    _run_over = false


## Debug-only: instantly kills every currently alive enemy. Callers must guard
## with Debug.enabled (see debug_standard.md).
func force_kill_all_enemies() -> void:
    _kill_all_alive_enemies()

# == Wave Flow ==


## Iterates a copy of _alive_enemies because each kill synchronously fires
## _on_enemy_died, which mutates the live array.
func _kill_all_alive_enemies() -> void:
    for enemy in _alive_enemies.duplicate():
        if enemy == null or not is_instance_valid(enemy):
            continue
        var killable := enemy as Enemy
        if killable != null and killable.health != null:
            killable.health.kill()


func _begin_wave() -> void:
    if _run_over:
        return
    wave_started.emit(get_wave_display_text(), is_milestone_wave())
    _prepare_spawn_queue()
    _spawn_next_batch()


## Builds this wave's full spawn list (support + elite on milestone waves). Cells
## are not chosen here; selection is deferred to _spawn_next_batch so spacing
## reflects what's actually spawning at that moment, not a stale full-wave plan.
func _prepare_spawn_queue() -> void:
    _spawn_queue.clear()

    var support_count := get_support_spawn_count()
    for i in support_count:
        var picked: PackedScene = SUPPORT_ENEMY_SCENES[randi() % SUPPORT_ENEMY_SCENES.size()]
        _spawn_queue.append({ "scene": picked, "index": i, "support_count": support_count })

    if is_milestone_wave():
        _spawn_queue.append({ "scene": EliteScene, "index": 0, "support_count": 1 })


## Pulls as many entries from _spawn_queue as current population headroom allows,
## telegraphs only that batch, and starts the spawn timer. No-ops if the queue is
## empty or there is no headroom.
func _spawn_next_batch() -> void:
    if _run_over or _spawn_queue.is_empty():
        return

    var headroom := WaveScaling.get_population_cap(get_wave_number()) - _alive_enemies.size()
    if headroom <= 0:
        return

    var batch_size := min(headroom, _spawn_queue.size())
    _current_batch = _spawn_queue.slice(0, batch_size)
    _spawn_queue = _spawn_queue.slice(batch_size)

    var reserved_spawn_cells: Array[Vector2i] = []
    for entry in _current_batch:
        var cell := _spawn_planner.choose_enemy_spawn_cell(entry["index"], entry["support_count"], reserved_spawn_cells)
        reserved_spawn_cells.append(cell)
        entry["cell"] = cell

    var telegraph_cells: Array[Vector2i] = []
    for entry in _current_batch:
        telegraph_cells.append(entry["cell"])
    _grid.set_telegraph(self, telegraph_cells, GridArena.TelegraphPhase.SPAWNING)
    _spawn_telegraph_timer.start(SPAWN_TELEGRAPH_DURATION)


func _spawn_current_batch() -> void:
    var cells: Array[Vector2i] = []
    for entry in _current_batch:
        cells.append(entry["cell"])
    _grid.clear_telegraph(self, cells)

    for entry in _current_batch:
        var scene: PackedScene = entry["scene"]
        var spawn_cell: Vector2i = entry["cell"]
        var enemy := _spawner.spawn_enemy(
            scene,
            spawn_cell,
            Callable(self, "_on_enemy_died"),
            Callable(self, "_apply_wave_scaling"),
        )
        if enemy == null:
            continue
        _alive_enemies.append(enemy)
        if scene == EliteScene:
            _elite_ref = enemy
            elite_spawned.emit(enemy)

    _current_batch.clear()
    # Pulls any queue headroom freed by deaths that happened during this
    # batch's telegraph window (those deaths were deliberately not allowed to
    # re-enter _spawn_next_batch while this batch was in flight; see
    # _on_enemy_died).
    _spawn_next_batch()


func _apply_wave_scaling(enemy: Node) -> void:
    var grid_enemy := enemy as GridEnemy
    if grid_enemy == null:
        return
    var wave_number := get_wave_number()
    grid_enemy.apply_wave_scaling(
        WaveScaling.get_hp_multiplier(wave_number),
        WaveScaling.get_damage_multiplier(wave_number),
        WaveScaling.get_defense(wave_number),
    )


func _clear_spawn_queue_telegraphs() -> void:
    if _current_batch.is_empty():
        return
    var cells: Array[Vector2i] = []
    for entry in _current_batch:
        cells.append(entry["cell"])
    _grid.clear_telegraph(self, cells)
    _current_batch.clear()
    _spawn_queue.clear()

# == Signal handlers ==


func _on_wave_gap_timeout() -> void:
    wave_gap_finished.emit()
    _begin_wave()


func _on_spawn_telegraph_timeout() -> void:
    _spawn_current_batch()


func _on_enemy_died(enemy: Entity) -> void:
    _alive_enemies.erase(enemy)
    _grid.unregister_occupant(enemy)

    if enemy == _elite_ref:
        _elite_ref = null
        elite_cleared.emit()

    if _run_over:
        return

    if not _spawn_queue.is_empty():
        # A batch already telegraphing (_current_batch non-empty) must not be
        # overwritten here: _spawn_next_batch() replaces _current_batch
        # wholesale, so calling it again mid-telegraph would silently drop
        # that batch's entries and orphan their telegraph tiles. Let the
        # in-flight batch resolve first; _spawn_current_batch() re-attempts
        # the queue once it does.
        if _current_batch.is_empty():
            _spawn_next_batch()
        return

    if _alive_enemies.is_empty() and _current_batch.is_empty():
        normal_wave_completed.emit(get_wave_number(), is_milestone_wave())

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
