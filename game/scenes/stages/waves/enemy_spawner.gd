# enemy_spawner.gd
# Instantiates wave enemies, wires their grid/player setup, and adds them to the arena.
class_name EnemySpawner
extends RefCounted

var _grid: GridArena
var _player: Player
var _parent: Node

# == Lifecycle ==


func _init(grid: GridArena = null, player: Player = null, parent: Node = null) -> void:
    _grid = grid
    _player = player
    _parent = parent

# == Common API ==


func setup(grid: GridArena, player: Player, parent: Node) -> void:
    _grid = grid
    _player = player
    _parent = parent


## Creates one enemy at the given grid cell and connects its death callback before it enters the tree.
## pre_ready_setup, if valid, is called with the enemy right before it enters the tree so
## one-time setup (e.g. wave stat scaling) is visible during the enemy's own _ready(), matching
## enemies whose attack executors stamp damage once at ready-time rather than per attack cycle.
func spawn_enemy(picked: PackedScene, spawn_cell: Vector2i, died_callback: Callable, pre_ready_setup: Callable = Callable()) -> Node:
    var enemy := picked.instantiate() as Node2D
    if enemy == null:
        ToastManager.show_dev_error("EnemySpawner: enemy scene root must be Node2D")
        return null

    enemy.global_position = _grid.cell_center(spawn_cell)

    if enemy.has_method("setup"):
        enemy.setup(_grid, _player)

    if not enemy.has_signal("died"):
        ToastManager.show_dev_error("EnemySpawner: enemy missing died signal")
        enemy.free()
        return null

    enemy.connect(&"died", died_callback)
    if pre_ready_setup.is_valid():
        pre_ready_setup.call(enemy)
    _parent.add_child(enemy)
    return enemy
