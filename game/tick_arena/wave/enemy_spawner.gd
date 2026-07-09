# enemy_spawner.gd
# Instantiates wave enemies, wires their grid/target setup, binds tick-clocked enemies to the
# tick engine, connects death, and adds them to the arena.
class_name EnemySpawner
extends RefCounted

var _grid: GridArena
var _target: Node2D
var _parent: Node
var _tick_engine: TickEngine

# == Lifecycle ==


func _init(grid: GridArena = null, target: Node2D = null, parent: Node = null, tick_engine: TickEngine = null) -> void:
    _grid = grid
    _target = target
    _parent = parent
    _tick_engine = tick_engine

# == Common API ==


func setup(grid: GridArena, target: Node2D, parent: Node, tick_engine: TickEngine) -> void:
    _grid = grid
    _target = target
    _parent = parent
    _tick_engine = tick_engine


## Creates one enemy at the given grid cell, binds it to the tick engine, and connects its death
## callback before it enters the tree. pre_ready_setup, if valid, is called with the enemy right
## before it enters the tree so one-time setup (e.g. wave stat scaling) is visible during the
## enemy's own _ready(), matching enemies whose attack executors stamp damage once at ready-time
## rather than per attack cycle.
func spawn_enemy(picked: PackedScene, spawn_cell: Vector2i, died_callback: Callable, pre_ready_setup: Callable = Callable()) -> Node:
    var enemy := picked.instantiate() as Node2D
    if enemy == null:
        ToastManager.show_dev_error("EnemySpawner: enemy scene root must be Node2D")
        return null

    enemy.global_position = _grid.cell_center(spawn_cell)

    if enemy.has_method("setup"):
        enemy.setup(_grid, _target)

    if not enemy.has_signal("died"):
        ToastManager.show_dev_error("EnemySpawner: enemy missing died signal")
        enemy.free()
        return null

    enemy.connect(&"died", died_callback)

    var grid_enemy := enemy as GridEnemy
    if grid_enemy != null and _tick_engine != null:
        grid_enemy.bind_tick_engine(_tick_engine)

    if pre_ready_setup.is_valid():
        pre_ready_setup.call(enemy)

    _parent.add_child(enemy)

    if grid_enemy != null and _tick_engine != null:
        _tick_engine.register_actor(grid_enemy)

    return enemy
