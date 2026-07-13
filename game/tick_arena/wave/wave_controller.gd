# wave_controller.gd
# Scene-local RefCounted that owns wave progression, ordered-group spawn scheduling, and alive
# enemies for tick-paced combat, driven entirely by an injected WaveCatalog. Spawn timing is driven
# by player-action world ticks (TickEngine.world_advanced) instead of real-time Timers: a scheduled
# batch drawn from one currently-eligible group telegraphs as a SPAWNING warning (unless its group
# authors zero warning ticks), counts down on world advances, then revalidates and spawns. Group
# eligibility, once granted, is never revoked; earlier eligible groups always claim population
# headroom before later ones, so a batch is always drawn from a single group at a time. Each spawned
# enemy's final level and projected stats come from the catalog's EnemyLevelProgressionProfile,
# applied through the enemy's existing pre-ready spawn callback.
class_name WaveController
extends RefCounted

signal wave_started(display_text: String, is_milestone_wave: bool)
signal normal_wave_completed(wave_number: int, is_milestone_wave: bool)
signal boss_spawned(boss: Node)
signal boss_cleared
signal spawn_warning_changed(cells: Array[Vector2i], ticks: int)

var _catalog: WaveCatalog
var _catalog_valid := false
var _wave_rng := RandomNumberGenerator.new()
var _current_wave_number := 0
var _grid: GridArena
var _spawn_planner: EnemySpawnPlanner
var _spawner: EnemySpawner
var _engine: TickEngine
var _alive_enemies: Array[Node] = []
var _enemy_group_index: Dictionary = { }
## One queue of not-yet-spawned entries per group in the active wave, indexed by group position.
var _group_queues: Array = []
## Latched per-group eligibility for the active wave; once true, never reset false.
var _group_eligible: Array[bool] = []
## Currently-alive spawned member count per group, used only for predecessor threshold checks.
var _group_living_count: Array[int] = []
## True once a group has ever actually spawned a member. PREVIOUS_GROUP_CLEARED and
## PREVIOUS_GROUP_SURVIVORS_AT_MOST require this before trusting a living count of zero as
## "cleared" rather than "never spawned yet."
var _group_ever_spawned: Array[bool] = []
var _pending_batch: Array[Dictionary] = []
var _pending_batch_group_index := -1
var _warning_ticks_remaining := 0
var _boss_ref: Node = null
var _run_over := false

# == Signal handlers ==


## Counts a pending spawn-warning batch down by one player-action world tick and resolves it at
## zero. A Speed-spent free move/attack never calls advance_world(), so it never emits
## world_advanced and never counts down; Dash always advances the world normally, even when it
## triggers Chain Dash's cooldown-clear and Speed-ready state.
func _on_world_advanced(_tick_count: int) -> void:
    if _run_over:
        return
    if _pending_batch.is_empty():
        _schedule_next_warning_batch()
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

    var group_index: int = _enemy_group_index.get(enemy, -1)
    if group_index != -1:
        _group_living_count[group_index] = max(_group_living_count[group_index] - 1, 0)
        _enemy_group_index.erase(enemy)

    if enemy == _boss_ref:
        _boss_ref = null
        boss_cleared.emit()

    if _run_over:
        return

    _evaluate_group_eligibility()
    if _pending_batch.is_empty():
        # A batch already warning must not be overwritten here: _schedule_next_warning_batch()
        # replaces _pending_batch wholesale, so calling it again mid-warning would silently drop
        # that batch's entries. Let the in-flight batch resolve first; _resolve_pending_batch()
        # re-attempts scheduling once it does.
        _schedule_next_warning_batch()
    _check_wave_completion()

# == Common API ==


## Wires the scene collaborators needed for tick-paced wave flow and enemy spawning, seeds the
## group-expansion RNG, and connects to the engine's world_advanced signal, the clock source for
## spawn-warning countdowns.
func setup(grid: GridArena, spawn_planner: EnemySpawnPlanner, spawner: EnemySpawner, engine: TickEngine) -> void:
    _grid = grid
    _spawn_planner = spawn_planner
    _spawner = spawner
    _engine = engine
    _wave_rng.randomize()
    if _engine != null and not _engine.world_advanced.is_connected(_on_world_advanced):
        _engine.world_advanced.connect(_on_world_advanced)


## Injects the authored catalog that drives every wave's groups, composition, warning timing, and
## enemy level projection. A missing or invalid catalog is reported once here and blocks every wave
## from starting or advancing; the controller never falls back to formula scaling.
func set_catalog(catalog: WaveCatalog) -> void:
    _catalog = catalog
    _catalog_valid = catalog != null and catalog.validate()
    if not _catalog_valid:
        ToastManager.show_dev_error("WaveController: missing or invalid WaveCatalog; waves cannot start or advance")


## Overrides the group-expansion RNG's seed. Tests use a fixed seed so weighted-group draws are
## deterministic; production relies on the randomize() call in setup() instead.
func set_wave_rng_seed(value: int) -> void:
    _wave_rng.seed = value


## Advances to the next wave and begins it immediately. Between-wave UI timing (banner, reward
## choice) belongs to the run controller, not this class.
func start_next_wave() -> void:
    if advance_wave():
        _begin_wave()


## Advances to the next wave number. Always advances unless the run has ended or the catalog is
## missing/invalid.
func advance_wave() -> bool:
    if _run_over or not _catalog_valid:
        return false
    _current_wave_number += 1
    return true


## Returns true when the active wave's groups include an authored boss group.
func is_milestone_wave() -> bool:
    var wave := _active_wave()
    if wave == null:
        return false
    for group in wave.groups:
        if group != null and group.is_boss:
            return true
    return false


## Returns the 1-based current wave number.
func get_wave_number() -> int:
    return _current_wave_number


## Returns the text shown for the current wave.
func get_wave_display_text() -> String:
    if is_milestone_wave():
        return "Wave %d: BOSS" % get_wave_number()
    return "Wave %d" % get_wave_number()


## Stops all further wave progression and spawning, and force-kills every enemy
## still alive so nothing keeps pathing/attacking against the input-locked
## player. Called on player death or a successful End Run.
func end_run() -> void:
    _run_over = true
    _clear_spawn_queue_telegraphs()
    _kill_all_alive_enemies()


## Returns true once end_run() has been called for the current run.
func is_run_over() -> bool:
    return _run_over


## Resets all wave-local state for a fresh run, including clearing any pending spawn-warning's grid
## telegraphs and every group's scheduling state.
func reset() -> void:
    _clear_spawn_queue_telegraphs()
    _current_wave_number = 0
    _group_eligible.clear()
    _group_living_count.clear()
    _group_ever_spawned.clear()
    _enemy_group_index.clear()
    _alive_enemies.clear()
    _warning_ticks_remaining = 0
    _boss_ref = null
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
    if _run_over or not _catalog_valid:
        return
    var wave := _active_wave()
    if wave == null:
        ToastManager.show_dev_error("WaveController: no wave definition resolved for wave %d" % _current_wave_number)
        return
    wave_started.emit(get_wave_display_text(), is_milestone_wave())
    _prepare_group_queues(wave)
    _evaluate_group_eligibility()
    _schedule_next_warning_batch()


## Resolves the current wave's definition from the catalog: the matching demo wave for waves 1-10,
## the reusable endless template beyond that. Returns null before the catalog is valid or before any
## wave has started.
func _active_wave() -> WaveDefinition:
    if not _catalog_valid or _current_wave_number <= 0:
        return null
    if _current_wave_number <= WaveCatalog.DEMO_WAVE_COUNT:
        return _catalog.demo_waves[_current_wave_number - 1]
    return _catalog.endless_template


func _population_cap() -> int:
    var wave := _active_wave()
    return wave.population_cap if wave != null else 0


func _check_wave_completion() -> void:
    if _run_over or not _pending_batch.is_empty():
        return
    if not _all_queues_empty():
        return
    if not _alive_enemies.is_empty():
        return
    normal_wave_completed.emit(get_wave_number(), is_milestone_wave())


func _all_queues_empty() -> bool:
    for queue in _group_queues:
        if not queue.is_empty():
            return false
    return true

# == Group Eligibility And Scheduling ==


## Builds this wave's per-group queues by expanding each group's authored composition once. Cells
## are not chosen here; selection is deferred to _schedule_next_warning_batch so spacing reflects
## what's actually warning at that moment, not a stale full-wave plan.
func _prepare_group_queues(wave: WaveDefinition) -> void:
    _group_queues.clear()
    _group_eligible.clear()
    _group_living_count.clear()
    _group_ever_spawned.clear()
    for group in wave.groups:
        _group_queues.append(_expand_group(group))
        _group_eligible.append(false)
        _group_living_count.append(0)
        _group_ever_spawned.append(false)


## Latches eligibility in authored order: the first group is always eligible by position; a later
## group can only become eligible once its immediate predecessor already is, checked against that
## predecessor's own living count. Once true, a group's eligibility is never revoked.
func _evaluate_group_eligibility() -> void:
    var wave := _active_wave()
    if wave == null:
        return
    for i in wave.groups.size():
        if _group_eligible[i]:
            continue
        if i == 0:
            _group_eligible[i] = true
            continue
        if not _group_eligible[i - 1]:
            continue
        _group_eligible[i] = _condition_met(wave.groups[i], i - 1)


## A predecessor's living count of zero only means "cleared" once it has actually spawned at least
## one member; otherwise CLEARED and SURVIVORS_AT_MOST would trivially pass on a predecessor that
## simply hasn't had its turn at population headroom yet.
func _condition_met(group: WaveGroupDefinition, predecessor_index: int) -> bool:
    var predecessor_living: int = _group_living_count[predecessor_index]
    match group.start_condition:
        WaveGroupDefinition.StartCondition.PREVIOUS_GROUP_CLEARED:
            return _group_ever_spawned[predecessor_index] and predecessor_living <= 0
        WaveGroupDefinition.StartCondition.PREVIOUS_GROUP_SURVIVORS_AT_MOST:
            return _group_ever_spawned[predecessor_index] and predecessor_living <= group.survivor_threshold
        WaveGroupDefinition.StartCondition.IMMEDIATE_OVERLAP:
            return true
        _:
            ToastManager.show_dev_error("WaveController: unknown start_condition %s" % group.start_condition)
            return false


## Pulls as many entries as current population headroom allows from the earliest eligible group
## that still has queued entries, and telegraphs only that batch as a SPAWNING warning, counted down
## in player-action world ticks. A group authored with zero warning ticks resolves its batch
## immediately instead of telegraphing. No-ops if no group is schedulable, there is no headroom, or
## a warning batch is already pending — deaths that free headroom while a batch is pending only
## unlock the next scheduling pass once that batch resolves.
func _schedule_next_warning_batch() -> void:
    if _run_over or not _pending_batch.is_empty():
        return

    var group_index := _next_schedulable_group_index()
    if group_index == -1:
        return

    var headroom := _population_cap() - _alive_enemies.size()
    if headroom <= 0:
        return

    var group_queue: Array = _group_queues[group_index]
    var batch_size: int = min(headroom, group_queue.size())
    _pending_batch = group_queue.slice(0, batch_size)
    _group_queues[group_index] = group_queue.slice(batch_size)
    _pending_batch_group_index = group_index

    var reserved_spawn_cells: Array[Vector2i] = []
    for i in _pending_batch.size():
        var cell := _spawn_planner.choose_enemy_spawn_cell(i, _pending_batch.size(), reserved_spawn_cells)
        reserved_spawn_cells.append(cell)
        _pending_batch[i]["cell"] = cell
        _pending_batch[i]["index"] = i
        _pending_batch[i]["count"] = _pending_batch.size()

    var wave := _active_wave()
    var group: WaveGroupDefinition = wave.groups[group_index] if wave != null else null
    var warning_ticks: int = group.warning_ticks if group != null else 0
    if warning_ticks <= 0:
        _resolve_pending_batch()
        return

    var telegraph_cells: Array[Vector2i] = []
    for entry in _pending_batch:
        telegraph_cells.append(entry["cell"])
    _grid.set_telegraph(self, telegraph_cells, GridArena.TelegraphPhase.SPAWNING)
    _warning_ticks_remaining = warning_ticks
    _emit_spawn_warning_changed()


## Returns the group index of the earliest eligible group that still has queued entries, or -1 when
## none is schedulable right now. Earlier groups are always returned before later ones, so overlap
## never lets a later group bypass unspawned entries from an earlier one.
func _next_schedulable_group_index() -> int:
    for i in _group_queues.size():
        if _group_eligible[i] and not _group_queues[i].is_empty():
            return i
    return -1


## Clears the pending batch's SPAWNING telegraph, revalidates each entry's reserved cell against
## current land/player/occupancy, relocates or requeues invalid entries back into their source
## group's queue, then spawns everything that resolved to a valid cell. Re-evaluates eligibility and
## schedules the next batch immediately only when every reserved entry resolved. A requeued entry
## waits for a later world tick or relevant death before retrying, so zero-warning groups cannot
## recurse indefinitely while the grid has no valid spawn cell.
func _resolve_pending_batch() -> void:
    var telegraph_cells: Array[Vector2i] = []
    for entry in _pending_batch:
        telegraph_cells.append(entry["cell"])
    _grid.clear_telegraph(self, telegraph_cells)

    var resolving := _pending_batch
    var resolving_group_index := _pending_batch_group_index
    _pending_batch = []
    _pending_batch_group_index = -1

    var accepted_cells: Array[Vector2i] = []
    var requeued: Array[Dictionary] = []
    var to_spawn: Array[Dictionary] = []
    for entry in resolving:
        var cell: Vector2i = entry["cell"]
        if _spawn_planner.is_spawn_cell_still_valid(cell, accepted_cells):
            accepted_cells.append(cell)
            to_spawn.append(entry)
            continue

        var replacement := _spawn_planner.find_valid_spawn_replacement(entry["index"], entry["count"], accepted_cells)
        if replacement == EnemySpawnPlanner.NO_CELL:
            requeued.append(entry)
            continue

        accepted_cells.append(replacement)
        entry["cell"] = replacement
        to_spawn.append(entry)

    if not requeued.is_empty():
        _group_queues[resolving_group_index] = requeued + _group_queues[resolving_group_index]

    for entry in to_spawn:
        _spawn_one(entry, resolving_group_index)

    _evaluate_group_eligibility()
    if requeued.is_empty():
        _schedule_next_warning_batch()
    if _pending_batch.is_empty():
        var empty_cells: Array[Vector2i] = []
        spawn_warning_changed.emit(empty_cells, 0)


func _spawn_one(entry: Dictionary, group_index: int) -> void:
    var scene: PackedScene = entry["scene"]
    var spawn_cell: Vector2i = entry["cell"]
    var level: int = entry["level"]
    var is_boss: bool = entry.get("is_boss", false)
    var enemy := _spawner.spawn_enemy(
        scene,
        spawn_cell,
        Callable(self, "_on_enemy_died"),
        func(e: Node) -> void: _apply_level_projection(e, level),
    )
    if enemy == null:
        return
    _alive_enemies.append(enemy)
    _enemy_group_index[enemy] = group_index
    _group_living_count[group_index] += 1
    _group_ever_spawned[group_index] = true
    if is_boss:
        _boss_ref = enemy
        boss_spawned.emit(enemy)


## Projects the spawned enemy's final level from the catalog's progression profile and applies it
## before the enemy enters the tree, matching EnemySpawner's pre-ready setup contract.
func _apply_level_projection(enemy: Node, level: int) -> void:
    var grid_enemy := enemy as GridEnemy
    if grid_enemy == null:
        return
    if _catalog == null or _catalog.progression_profile == null:
        return
    var projection := _catalog.progression_profile.project(grid_enemy.enemy_data, level, _current_wave_number)
    grid_enemy.apply_level_projection(level, projection)


## Clears any pending warning batch's grid telegraphs, then drops both the pending batch and every
## group's remaining queue. Queues are always cleared, even with no batch pending, so a caller
## resetting mid-drain doesn't leak queued entries.
func _clear_spawn_queue_telegraphs() -> void:
    if not _pending_batch.is_empty():
        var cells: Array[Vector2i] = []
        for entry in _pending_batch:
            cells.append(entry["cell"])
        _grid.clear_telegraph(self, cells)
        _pending_batch.clear()
        _pending_batch_group_index = -1
    _group_queues.clear()
    var empty_cells: Array[Vector2i] = []
    spawn_warning_changed.emit(empty_cells, 0)


func _pending_batch_cells() -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for entry in _pending_batch:
        cells.append(entry["cell"])
    return cells


func _emit_spawn_warning_changed() -> void:
    spawn_warning_changed.emit(_pending_batch_cells(), _warning_ticks_remaining)

# == Group Expansion ==


## Expands one group's authored composition into queue entries: fixed mode appends count copies of
## each entry in authored order; weighted mode draws weighted_total_count entries from the injected
## per-run wave RNG, independent of the reward RNG so reward choices can never alter encounter
## composition.
func _expand_group(group: WaveGroupDefinition) -> Array[Dictionary]:
    var entries: Array[Dictionary] = []
    match group.composition_mode:
        WaveGroupDefinition.CompositionMode.FIXED:
            for composition_entry in group.entries:
                for i in composition_entry.count:
                    entries.append(_make_queue_entry(composition_entry.enemy_scene, group))
        WaveGroupDefinition.CompositionMode.WEIGHTED:
            for i in group.weighted_total_count:
                var picked := _pick_weighted_entry(group.entries)
                if picked != null:
                    entries.append(_make_queue_entry(picked.enemy_scene, group))
        _:
            ToastManager.show_dev_error("WaveController: unknown composition_mode %s" % group.composition_mode)
    return entries


func _make_queue_entry(scene: PackedScene, group: WaveGroupDefinition) -> Dictionary:
    return {
        "scene": scene,
        "level": _current_wave_number + group.level_offset,
        "is_boss": group.is_boss,
    }


func _pick_weighted_entry(entries: Array[WaveCompositionEntry]) -> WaveCompositionEntry:
    var total_weight := 0.0
    for entry in entries:
        total_weight += entry.weight
    if total_weight <= 0.0:
        return null
    var roll := _wave_rng.randf_range(0.0, total_weight)
    var running := 0.0
    for entry in entries:
        running += entry.weight
        if roll <= running:
            return entry
    return entries[entries.size() - 1]
