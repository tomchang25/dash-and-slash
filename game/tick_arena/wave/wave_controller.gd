# wave_controller.gd
# Scene-local RefCounted that owns wave progression, spawn queueing, and alive enemies for
# tick-paced combat. Spawn timing is driven by player-action world ticks
# (TickEngine.world_advanced) instead of real-time Timers: a scheduled batch telegraphs as a
# SPAWNING warning, counts down on world advances, then revalidates and spawns. Future enemy
# count and enemy-toughness pressure are both read from the injected run-scoped RunBuild store
# rather than owned here.
class_name WaveController
extends RefCounted

signal wave_started(display_text: String, is_milestone_wave: bool)
signal normal_wave_completed(wave_number: int, is_milestone_wave: bool)
signal elite_spawned(elite: Node)
signal elite_cleared
signal spawn_warning_changed(cells: Array[Vector2i], ticks: int)

const SmallEnemyScene := preload("res://game/entities/enemies/small_enemy.tscn")
const ChargeEnemyScene := preload("res://game/entities/enemies/charge_enemy.tscn")
const EliteScene := preload("res://game/entities/enemies/mode_enemy.tscn")

## PuffEnemy is intentionally excluded: it is a parked special-enemy prototype, not part of the
## normal support pool. See tick_arena_visual_readability_03a_support_pool_identity_cleanup.
const SUPPORT_ENEMY_SCENES := [SmallEnemyScene, ChargeEnemyScene]
## Player-action world ticks a spawn-warning batch telegraphs before it resolves.
const SPAWN_WARNING_TICKS := 2

var _current_wave_number := 0
var _run_build: RunBuild
var _grid: GridArena
var _spawn_planner: EnemySpawnPlanner
var _spawner: EnemySpawner
var _engine: TickEngine
var _alive_enemies: Array[Node] = []
var _spawn_queue: Array[Dictionary] = []
var _pending_batch: Array[Dictionary] = []
var _warning_ticks_remaining := 0
var _elite_ref: Node = null
var _run_over := false

# == Signal handlers ==


## Counts a pending spawn-warning batch down by one player-action world tick and resolves it at
## zero. Free actions (a Speed-spent move/attack, a Mobility Free Action refund) never call
## advance_world(), so they never emit world_advanced and never count down.
func _on_world_advanced(_tick_count: int) -> void:
    if _run_over or _pending_batch.is_empty():
        return
    _warning_ticks_remaining -= 1
    if _warning_ticks_remaining <= 0:
        _resolve_pending_batch()
        return
    _emit_spawn_warning_changed()


func _on_enemy_died(enemy: Entity) -> void:
    _alive_enemies.erase(enemy)
    _grid.unregister_occupant(enemy)
    if _engine != null and enemy is GridEnemy:
        _engine.unregister_actor(enemy)

    if enemy == _elite_ref:
        _elite_ref = null
        elite_cleared.emit()

    if _run_over:
        return

    if not _spawn_queue.is_empty():
        # A batch already warning (_pending_batch non-empty) must not be overwritten here:
        # _schedule_next_warning_batch() replaces _pending_batch wholesale, so calling it again
        # mid-warning would silently drop that batch's entries and orphan their telegraph tiles.
        # Let the in-flight batch resolve first; _resolve_pending_batch() re-attempts the queue
        # once it does.
        if _pending_batch.is_empty():
            _schedule_next_warning_batch()
        return

    if _alive_enemies.is_empty() and _pending_batch.is_empty():
        normal_wave_completed.emit(get_wave_number(), is_milestone_wave())

# == Common API ==


## Wires the scene collaborators needed for tick-paced wave flow and enemy spawning, and connects
## to the engine's world_advanced signal, the clock source for spawn-warning countdowns.
func setup(grid: GridArena, spawn_planner: EnemySpawnPlanner, spawner: EnemySpawner, engine: TickEngine) -> void:
    _grid = grid
    _spawn_planner = spawn_planner
    _spawner = spawner
    _engine = engine
    if _engine != null and not _engine.world_advanced.is_connected(_on_world_advanced):
        _engine.world_advanced.connect(_on_world_advanced)


## Injects the run-scoped modifier store that future-enemy pressure is read
## from. A required dependency wired by the arena, like the grid and spawner —
## not lazily created.
func set_run_build(run_build: RunBuild) -> void:
    _run_build = run_build


## Advances to the next wave and begins it immediately. Between-wave UI timing (banner, reward
## choice) belongs to the run controller, not this class.
func start_next_wave() -> void:
    if advance_wave():
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
## including future enemy count pressure read from the run-build store.
func get_support_spawn_count() -> int:
    if _current_wave_number <= 0:
        return 0
    var pressure := int(max(0.0, _run_build.total(RunBuild.CH_FUTURE_ENEMY_COUNT)))
    return WaveScaling.get_support_count(_current_wave_number) + pressure


## Returns 1 for milestone waves (elite spawn), 0 otherwise.
func get_elite_spawn_count() -> int:
    return 1 if is_milestone_wave() else 0


## Returns the hp multiplier for the current wave: WaveScaling's tier-formula
## baseline plus any enemy-health pressure recorded in the run-build store.
func get_hp_multiplier() -> float:
    var pressure := max(0.0, _run_build.total(RunBuild.CH_ENEMY_HEALTH_PRESSURE))
    return WaveScaling.get_hp_multiplier(get_wave_number()) + pressure


## Returns the outgoing-damage multiplier for the current wave: WaveScaling's
## tier-formula baseline plus any enemy-damage pressure recorded in the run-build store.
func get_damage_multiplier() -> float:
    var pressure := max(0.0, _run_build.total(RunBuild.CH_ENEMY_DAMAGE_PRESSURE))
    return WaveScaling.get_damage_multiplier(get_wave_number()) + pressure


## Returns the flat defense value for the current wave: WaveScaling's
## tier-formula baseline plus any enemy-defense pressure recorded in the run-build store.
func get_defense() -> float:
    var pressure := max(0.0, _run_build.total(RunBuild.CH_ENEMY_DEFENSE_PRESSURE))
    return WaveScaling.get_defense(get_wave_number()) + pressure


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
    _kill_all_alive_enemies()


## Returns true once end_run() has been called for the current run.
func is_run_over() -> bool:
    return _run_over


## Resets all wave-local state for a fresh run, including clearing any pending spawn-warning's grid
## telegraphs. Future-enemy pressure is already cleared by TickRunController through the injected
## RunBuild before this runs, so the wave controller keeps its original store reference.
func reset() -> void:
    _clear_spawn_queue_telegraphs()
    _current_wave_number = 0
    _alive_enemies.clear()
    _warning_ticks_remaining = 0
    _elite_ref = null
    _run_over = false


## Returns the current spawn-warning display payload ({cells, ticks}), or an empty dictionary.
func get_spawn_warning_danger() -> Dictionary:
    if _pending_batch.is_empty() or _warning_ticks_remaining <= 0:
        return { }
    return {
        "cells": _pending_batch_cells(),
        "ticks": _warning_ticks_remaining,
        "kind": "spawn",
    }


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
    _schedule_next_warning_batch()


## Builds this wave's full spawn list (support + elite on milestone waves). Cells are not chosen
## here; selection is deferred to _schedule_next_warning_batch so spacing reflects what's actually
## warning at that moment, not a stale full-wave plan.
func _prepare_spawn_queue() -> void:
    _spawn_queue.clear()

    var support_count := get_support_spawn_count()
    for i in support_count:
        var picked: PackedScene = SUPPORT_ENEMY_SCENES[randi() % SUPPORT_ENEMY_SCENES.size()]
        _spawn_queue.append({ "scene": picked, "index": i, "support_count": support_count })

    if is_milestone_wave():
        _spawn_queue.append({ "scene": EliteScene, "index": 0, "support_count": 1 })


## Pulls as many entries from _spawn_queue as current population headroom allows and telegraphs
## only that batch as a SPAWNING warning, counted down in player-action world ticks. No-ops if the
## queue is empty, there is no headroom, or a warning batch is already pending — deaths that free
## headroom while a batch is pending only unlock the next scheduling pass once that batch resolves.
func _schedule_next_warning_batch() -> void:
    if _run_over or _spawn_queue.is_empty() or not _pending_batch.is_empty():
        return

    var headroom := WaveScaling.get_population_cap(get_wave_number()) - _alive_enemies.size()
    if headroom <= 0:
        return

    var batch_size := min(headroom, _spawn_queue.size())
    _pending_batch = _spawn_queue.slice(0, batch_size)
    _spawn_queue = _spawn_queue.slice(batch_size)

    var reserved_spawn_cells: Array[Vector2i] = []
    for entry in _pending_batch:
        var cell := _spawn_planner.choose_enemy_spawn_cell(entry["index"], entry["support_count"], reserved_spawn_cells)
        reserved_spawn_cells.append(cell)
        entry["cell"] = cell

    var telegraph_cells: Array[Vector2i] = []
    for entry in _pending_batch:
        telegraph_cells.append(entry["cell"])
    _grid.set_telegraph(self, telegraph_cells, GridArena.TelegraphPhase.SPAWNING)
    _warning_ticks_remaining = SPAWN_WARNING_TICKS
    _emit_spawn_warning_changed()


## Clears the pending batch's SPAWNING telegraph, revalidates each entry's reserved cell against
## current land/player/occupancy, relocates or requeues invalid entries, then spawns everything
## that resolved to a valid cell. Schedules the next batch immediately after, so headroom this
## batch's own spawns didn't use is picked up without waiting for a death.
func _resolve_pending_batch() -> void:
    var telegraph_cells: Array[Vector2i] = []
    for entry in _pending_batch:
        telegraph_cells.append(entry["cell"])
    _grid.clear_telegraph(self, telegraph_cells)

    var resolving := _pending_batch
    _pending_batch = []

    var accepted_cells: Array[Vector2i] = []
    var requeued: Array[Dictionary] = []
    var to_spawn: Array[Dictionary] = []
    for entry in resolving:
        var cell: Vector2i = entry["cell"]
        if _spawn_planner.is_spawn_cell_still_valid(cell, accepted_cells):
            accepted_cells.append(cell)
            to_spawn.append(entry)
            continue

        var replacement := _spawn_planner.find_valid_spawn_replacement(entry["index"], entry["support_count"], accepted_cells)
        if replacement == EnemySpawnPlanner.NO_CELL:
            requeued.append(entry)
            continue

        accepted_cells.append(replacement)
        entry["cell"] = replacement
        to_spawn.append(entry)

    if not requeued.is_empty():
        _spawn_queue = requeued + _spawn_queue

    for entry in to_spawn:
        _spawn_one(entry)

    _schedule_next_warning_batch()
    if _pending_batch.is_empty():
        var empty_cells: Array[Vector2i] = []
        spawn_warning_changed.emit(empty_cells, 0)


func _spawn_one(entry: Dictionary) -> void:
    var scene: PackedScene = entry["scene"]
    var spawn_cell: Vector2i = entry["cell"]
    var enemy := _spawner.spawn_enemy(
        scene,
        spawn_cell,
        Callable(self, "_on_enemy_died"),
        Callable(self, "_apply_wave_scaling"),
    )
    if enemy == null:
        return
    _alive_enemies.append(enemy)
    if scene == EliteScene:
        _elite_ref = enemy
        elite_spawned.emit(enemy)


func _apply_wave_scaling(enemy: Node) -> void:
    var grid_enemy := enemy as GridEnemy
    if grid_enemy == null:
        return
    grid_enemy.apply_wave_scaling(
        get_hp_multiplier(),
        get_damage_multiplier(),
        get_defense(),
    )


## Clears any pending warning batch's grid telegraphs, then drops both the pending batch and the
## rest of the spawn queue. The queue is always cleared, even with no batch pending, so a caller
## resetting mid-drain (population at cap, queue still holding overflow) doesn't leak queued entries.
func _clear_spawn_queue_telegraphs() -> void:
    if not _pending_batch.is_empty():
        var cells: Array[Vector2i] = []
        for entry in _pending_batch:
            cells.append(entry["cell"])
        _grid.clear_telegraph(self, cells)
        _pending_batch.clear()
    _spawn_queue.clear()
    var empty_cells: Array[Vector2i] = []
    spawn_warning_changed.emit(empty_cells, 0)


func _pending_batch_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for entry in _pending_batch:
        cells.append(entry["cell"])
    return cells


func _emit_spawn_warning_changed() -> void:
    spawn_warning_changed.emit(_pending_batch_cells(), _warning_ticks_remaining)
