# boss_attack_controller.gd
# Owns Boss attack mode selection snapshots, telegraphs, and hitbox activation.
class_name BossAttackController
extends Node

enum BossMode { TILE_ATTACK = 0, CONTACT_CHARGE = 1, PUFF_STATION = 2 }

const MODE_COUNT := 3
const BOSS_FOOTPRINT := Vector2i(2, 2)
const TILE_ATTACK_DAMAGE := 12.0
const CONTACT_DAMAGE := 10.0
const PUFF_DAMAGE := 14.0

var _grid: GridArena
var _telegraph: TileTelegraph
var _tile_hitbox: Hitbox
var _contact_hitbox: Hitbox
var _puff_hitbox: Hitbox
var _mode: int = BossMode.TILE_ATTACK
var _attack_cells: Array[Vector2i] = []
var _tile_hitbox_position := Vector2.ZERO
var _prepared := false


func setup(grid: GridArena, telegraph: TileTelegraph, tile_hitbox: Hitbox, contact_hitbox: Hitbox, puff_hitbox: Hitbox) -> void:
    _grid = grid
    _telegraph = telegraph
    _tile_hitbox = tile_hitbox
    _contact_hitbox = contact_hitbox
    _puff_hitbox = puff_hitbox
    if _telegraph != null:
        _telegraph.setup(grid)
    cancel()


func set_mode(mode: int) -> void:
    _mode = clampi(mode, 0, MODE_COUNT - 1)


func get_mode() -> int:
    return _mode


func prepare(origin_cell: Vector2i, facing: Vector2) -> bool:
    cancel()
    if _grid == null:
        return false

    match _mode:
        BossMode.TILE_ATTACK:
            _attack_cells = _get_tile_attack_cells(origin_cell, facing)
            _configure_tile_hitbox(TILE_ATTACK_DAMAGE)
        BossMode.CONTACT_CHARGE:
            _attack_cells = _get_charge_cells(origin_cell, facing)
            _configure_contact_hitbox()
        BossMode.PUFF_STATION:
            _attack_cells = _get_puff_cells(origin_cell)
            _configure_puff_hitbox()

    _prepared = not _attack_cells.is_empty()
    return _prepared


func show_warning() -> void:
    if _prepared and _telegraph != null:
        _telegraph.show_warning(_attack_cells)


func show_charge() -> void:
    if _prepared and _telegraph != null:
        _telegraph.show_charge(_attack_cells)


func begin_attack() -> void:
    if not _prepared:
        return
    if _telegraph != null:
        _telegraph.show_active(_attack_cells)

    match _mode:
        BossMode.TILE_ATTACK:
            if _tile_hitbox != null:
                _tile_hitbox.global_position = _tile_hitbox_position
                _tile_hitbox.set_enabled(true)
        BossMode.CONTACT_CHARGE:
            if _contact_hitbox != null:
                _contact_hitbox.set_enabled(true)
        BossMode.PUFF_STATION:
            if _puff_hitbox != null:
                _puff_hitbox.set_enabled(true)


func end_attack() -> void:
    _disable_hitboxes()
    if _telegraph != null:
        _telegraph.clear()
    _attack_cells.clear()
    _prepared = false


func cancel() -> void:
    _disable_hitboxes()
    if _telegraph != null:
        _telegraph.clear()
    _attack_cells.clear()
    _prepared = false


func get_cells() -> Array[Vector2i]:
    return _attack_cells.duplicate()


func clear_cell(cell: Vector2i) -> void:
    if _telegraph != null:
        _telegraph.clear_cell(cell)


func _disable_hitboxes() -> void:
    if _tile_hitbox != null:
        _tile_hitbox.set_enabled(false)
    if _contact_hitbox != null:
        _contact_hitbox.set_enabled(false)
    if _puff_hitbox != null:
        _puff_hitbox.set_enabled(false)


func _configure_tile_hitbox(damage: float) -> void:
    if _tile_hitbox == null:
        return
    _tile_hitbox.damage = damage
    _tile_hitbox.damage_interval = 0.0
    _tile_hitbox.guard_damage_profile = Hitbox.GuardDamageProfile.NORMAL
    _apply_tile_hitbox_geometry(_tile_hitbox)


func _configure_contact_hitbox() -> void:
    if _contact_hitbox == null:
        return
    _contact_hitbox.damage = CONTACT_DAMAGE
    _contact_hitbox.damage_interval = 0.45
    _contact_hitbox.guard_damage_profile = Hitbox.GuardDamageProfile.NORMAL


func _configure_puff_hitbox() -> void:
    if _puff_hitbox == null:
        return
    _puff_hitbox.damage = PUFF_DAMAGE
    _puff_hitbox.damage_interval = 0.0
    _puff_hitbox.guard_damage_profile = Hitbox.GuardDamageProfile.NORMAL


func _apply_tile_hitbox_geometry(hitbox: Hitbox) -> void:
    if _grid == null or hitbox == null or _attack_cells.is_empty():
        return

    var min_cell := _attack_cells[0]
    var max_cell := _attack_cells[0]
    for cell: Vector2i in _attack_cells:
        min_cell.x = mini(min_cell.x, cell.x)
        min_cell.y = mini(min_cell.y, cell.y)
        max_cell.x = maxi(max_cell.x, cell.x)
        max_cell.y = maxi(max_cell.y, cell.y)

    var cell_span := max_cell - min_cell + Vector2i.ONE
    var rect := RectangleShape2D.new()
    rect.size = Vector2(cell_span) * _grid.tile_size * 0.9
    hitbox.set_collision_shape(rect)
    _tile_hitbox_position = _grid.cell_center(min_cell)
    _tile_hitbox_position += Vector2(cell_span - Vector2i.ONE) * _grid.tile_size * 0.5


func _get_tile_attack_cells(origin_cell: Vector2i, facing: Vector2) -> Array[Vector2i]:
    var facing_cell := Vector2i(int(facing.x), int(facing.y))
    var right_cell := Vector2i(facing_cell.y, -facing_cell.x)
    var cells: Array[Vector2i] = []
    for depth in range(1, 4):
        var center := origin_cell + Vector2i(1, 1) + facing_cell * depth
        _append_cell_if_in_bounds(cells, center - right_cell)
        _append_cell_if_in_bounds(cells, center)
        _append_cell_if_in_bounds(cells, center + right_cell)
    return cells


func _get_charge_cells(origin_cell: Vector2i, facing: Vector2) -> Array[Vector2i]:
    var facing_cell := Vector2i(int(facing.x), int(facing.y))
    var cells: Array[Vector2i] = []
    var cell := origin_cell + facing_cell
    while _is_valid_footprint(cell) and cells.size() < 3:
        cells.append(cell)
        cell += facing_cell
    return cells


func _get_puff_cells(origin_cell: Vector2i) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    for x_offset in range(-1, BOSS_FOOTPRINT.x + 1):
        for y_offset in range(-1, BOSS_FOOTPRINT.y + 1):
            _append_cell_if_in_bounds(cells, origin_cell + Vector2i(x_offset, y_offset))
    return cells


func _append_cell_if_in_bounds(cells: Array[Vector2i], cell: Vector2i) -> void:
    if _grid == null or not _grid.is_in_bounds(cell):
        return
    if cell not in cells:
        cells.append(cell)


func _is_valid_footprint(top_left: Vector2i) -> bool:
    if _grid == null:
        return false
    for x in range(BOSS_FOOTPRINT.x):
        for y in range(BOSS_FOOTPRINT.y):
            if not _grid.is_in_bounds(top_left + Vector2i(x, y)):
                return false
    return true
