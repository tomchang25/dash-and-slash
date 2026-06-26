# small_enemy_attack_controller.gd
# Owns SmallEnemy attack snapshots, telegraph display, and hitbox activation.
class_name SmallEnemyAttackController
extends Node

var _grid: GridArena
var _telegraph: TileTelegraph
var _hitbox: Hitbox
var _attack_cells: Array[Vector2i] = []
var _hitbox_position := Vector2.ZERO
var _prepared := false


func setup(grid: GridArena, telegraph: TileTelegraph, hitbox: Hitbox) -> void:
    _grid = grid
    _telegraph = telegraph
    _hitbox = hitbox
    if _telegraph != null:
        _telegraph.setup(grid)
    cancel()


func prepare(origin_cell: Vector2i, facing: Vector2) -> bool:
    cancel()
    if _grid == null:
        return false

    var facing_cell := Vector2i(int(facing.x), int(facing.y))
    if facing_cell == Vector2i.ZERO:
        return false

    var attack_cell := origin_cell + facing_cell
    if not _grid.is_in_bounds(attack_cell):
        return false

    _attack_cells = [attack_cell]
    _hitbox_position = _grid.cell_center(attack_cell)
    _prepared = true
    return true


func get_cells() -> Array[Vector2i]:
    return _attack_cells.duplicate()


func show_telegraph() -> void:
    if _prepared and _telegraph != null:
        _telegraph.show_warning(_attack_cells)


func begin_attack() -> void:
    if not _prepared or _hitbox == null:
        return
    if _telegraph != null:
        _telegraph.clear()
    _hitbox.global_position = _hitbox_position
    _hitbox.set_enabled(true)


func end_attack() -> void:
    if _hitbox != null:
        _hitbox.set_enabled(false)


func cancel() -> void:
    if _telegraph != null:
        _telegraph.clear()
    if _hitbox != null:
        _hitbox.set_enabled(false)
    _attack_cells.clear()
    _prepared = false
