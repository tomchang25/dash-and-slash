# small_enemy_attack_controller.gd
# Owns SmallEnemy attack snapshots, telegraph display, hitbox activation,
# and per-cell attack VFX spawned on charge.
class_name SmallEnemyAttackController
extends Node

enum AttackPattern { LINE_1X4 = 0, WIDE_2X3 = 1, SURROUND_3X3 = 2 }

const ATTACK_PATTERN_COUNT := 3
const VFX_DURATION := 0.5

var _grid: GridArena
var _telegraph: TileTelegraph
var _hitbox: Hitbox
var _attack_pattern: int = AttackPattern.LINE_1X4
var _attack_cells: Array[Vector2i] = []
var _hitbox_position := Vector2.ZERO
var _prepared := false
var _active_vfx: Array[Polygon2D] = []
var _vfx_parent: Node2D


func setup(grid: GridArena, telegraph: TileTelegraph, hitbox: Hitbox, vfx_parent: Node2D) -> void:
    _grid = grid
    _telegraph = telegraph
    _hitbox = hitbox
    _vfx_parent = vfx_parent
    if _telegraph != null:
        _telegraph.setup(grid)
    cancel()


func randomize_attack_pattern() -> void:
    _attack_pattern = randi() % ATTACK_PATTERN_COUNT


func set_attack_pattern(attack_pattern: int) -> void:
    _attack_pattern = clampi(attack_pattern, 0, ATTACK_PATTERN_COUNT - 1)


func get_attack_pattern() -> int:
    return _attack_pattern


func get_attack_cells(origin_cell: Vector2i, facing: Vector2) -> Array[Vector2i]:
    var facing_cell := Vector2i(int(facing.x), int(facing.y))
    if facing_cell == Vector2i.ZERO:
        var empty_cells: Array[Vector2i] = []
        return empty_cells

    var right_cell := Vector2i(facing_cell.y, -facing_cell.x)
    var cells: Array[Vector2i] = []
    match _attack_pattern:
        AttackPattern.LINE_1X4:
            for depth in range(1, 4):
                _append_cell_if_in_bounds(cells, origin_cell + facing_cell * depth)
        AttackPattern.WIDE_2X3:
            for depth in range(2):
                var center_cell := origin_cell + facing_cell * (depth + 1)
                _append_cell_if_in_bounds(cells, center_cell - right_cell)
                _append_cell_if_in_bounds(cells, center_cell)
                _append_cell_if_in_bounds(cells, center_cell + right_cell)
        AttackPattern.SURROUND_3X3:
            for x_offset in range(-1, 2):
                for y_offset in range(-1, 2):
                    var offset := Vector2i(x_offset, y_offset)
                    _append_cell_if_in_bounds(cells, origin_cell + offset)
    return cells


func prepare(origin_cell: Vector2i, facing: Vector2) -> bool:
    cancel()
    if _grid == null:
        return false

    _attack_cells = get_attack_cells(origin_cell, facing)
    if _attack_cells.is_empty():
        return false

    _apply_hitbox_geometry()
    _prepared = true
    return true


func get_cells() -> Array[Vector2i]:
    return _attack_cells.duplicate()


func show_telegraph() -> void:
    if _prepared and _telegraph != null:
        _telegraph.show_warning(_attack_cells)


func show_charge() -> void:
    if _prepared and _telegraph != null:
        _telegraph.show_charge(_attack_cells)


func begin_attack() -> void:
    if not _prepared or _hitbox == null:
        return
    if _telegraph != null:
        _telegraph.show_active(_attack_cells)

    _hitbox.global_position = _hitbox_position
    _hitbox.set_enabled(true)


func end_attack() -> void:
    if _hitbox != null:
        _hitbox.set_enabled(false)

    _attack_cells.clear()
    _telegraph.clear()


func cancel() -> void:
    if _telegraph != null:
        _telegraph.clear()
    if _hitbox != null:
        _hitbox.set_enabled(false)
    _attack_cells.clear()
    _telegraph.clear()

    _prepared = false


func _append_cell_if_in_bounds(cells: Array[Vector2i], cell: Vector2i) -> void:
    if _grid != null and not _grid.is_in_bounds(cell):
        return
    if cell not in cells:
        cells.append(cell)


func _on_vfx_tween_done(vfx: Polygon2D) -> void:
    _active_vfx.erase(vfx)
    if is_instance_valid(vfx):
        vfx.queue_free()


func _apply_hitbox_geometry() -> void:
    if _grid == null or _hitbox == null or _attack_cells.is_empty():
        return

    var min_cell := _attack_cells[0]
    var max_cell := _attack_cells[0]
    for cell in _attack_cells:
        min_cell.x = mini(min_cell.x, cell.x)
        min_cell.y = mini(min_cell.y, cell.y)
        max_cell.x = maxi(max_cell.x, cell.x)
        max_cell.y = maxi(max_cell.y, cell.y)

    var cell_span := max_cell - min_cell + Vector2i.ONE
    var rect := RectangleShape2D.new()
    rect.size = Vector2(cell_span) * _grid.tile_size * 0.9
    _hitbox.set_collision_shape(rect)
    _hitbox_position = _grid.cell_center(min_cell)
    _hitbox_position += Vector2(cell_span - Vector2i.ONE) * _grid.tile_size * 0.5
