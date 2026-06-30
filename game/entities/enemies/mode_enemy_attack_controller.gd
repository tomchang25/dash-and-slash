# mode_enemy_attack_controller.gd
# Controls ModeEnemy attack snapshots, telegraphs, and mode-specific hitboxes.
class_name ModeEnemyAttackController
extends Node

enum Mode { TILE = 0, PUFF = 1, CHARGE = 2 }
enum TileShape { WIDE_2X3 = 0, SELF_3X3 = 1, LINE_1X4 = 2 }

const MODE_COUNT := 3
const TILE_SHAPE_COUNT := 3
const TILE_ATTACK_DAMAGE := 12.0
const CONTACT_DAMAGE := 10.0
const PUFF_DAMAGE := 14.0

var _grid: GridArena
var _telegraph: TileTelegraph
var _tile_hitbox: Hitbox
var _contact_hitbox: Hitbox
var _puff_hitbox: Hitbox
var _mode: int = Mode.TILE
var _tile_shape: int = TileShape.WIDE_2X3
var _attack_data: EnemyAttackData
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


func randomize_tile_shape() -> void:
    _tile_shape = randi() % TILE_SHAPE_COUNT


func get_tile_shape() -> int:
    return _tile_shape


func set_attack_data(attack_data: EnemyAttackData) -> void:
    _attack_data = attack_data


func get_attack_data() -> EnemyAttackData:
    return _attack_data


func prepare(origin_cell: Vector2i, facing: Vector2) -> bool:
    cancel()
    if _grid == null:
        return false

    _attack_cells = get_attack_cells(origin_cell, facing)
    match _mode:
        Mode.TILE:
            var tile_damage := _attack_data.damage if _attack_data != null else TILE_ATTACK_DAMAGE
            var tile_damage_interval := _attack_data.damage_interval if _attack_data != null else 0.0
            _configure_tile_hitbox(tile_damage, tile_damage_interval)
        Mode.CHARGE:
            _configure_contact_hitbox()
        Mode.PUFF:
            _configure_puff_hitbox()

    _prepared = not _attack_cells.is_empty()
    return _prepared


func get_attack_cells(origin_cell: Vector2i, facing: Vector2) -> Array[Vector2i]:
    if _attack_data != null:
        return EnemyAttackController.get_attack_cells(origin_cell, facing, _attack_data, _grid)

    match _mode:
        Mode.TILE:
            return _get_tile_attack_cells(origin_cell, facing)
        Mode.CHARGE:
            return _get_charge_cells(origin_cell, facing)
        Mode.PUFF:
            return AttackCellShapes.square(origin_cell, 1, _grid, true)
    return []


func get_attack_origin_cells(target_cell: Vector2i) -> Array[Vector2i]:
    var attack_data := _attack_data if _attack_data != null else _create_origin_candidate_attack_data()
    if attack_data == null:
        return []
    return EnemyAttackController.get_attack_origin_cells(target_cell, attack_data, _grid)


func show_warning() -> void:
    if _prepared and _telegraph != null:
        _telegraph.show_warning(_attack_cells)


func show_charge() -> void:
    if _prepared and _telegraph != null:
        _telegraph.show_charge(_attack_cells)


func show_active() -> void:
    if _prepared and _telegraph != null:
        _telegraph.show_active(_attack_cells)


func begin_attack() -> void:
    if not _prepared:
        return
    show_active()
    match _mode:
        Mode.TILE:
            if _tile_hitbox != null:
                _tile_hitbox.global_position = _tile_hitbox_position
                _tile_hitbox.set_enabled(true)
        Mode.CHARGE:
            if _contact_hitbox != null:
                _contact_hitbox.set_enabled(true)
        Mode.PUFF:
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


func _configure_tile_hitbox(damage: float, damage_interval: float) -> void:
    if _tile_hitbox == null:
        return
    _tile_hitbox.damage = damage
    _tile_hitbox.damage_interval = damage_interval
    _tile_hitbox.guard_damage_profile = Hitbox.GuardDamageProfile.NORMAL
    _apply_tile_hitbox_geometry(_tile_hitbox)


func _configure_contact_hitbox() -> void:
    if _contact_hitbox == null:
        return
    _contact_hitbox.damage = _attack_data.damage if _attack_data != null else CONTACT_DAMAGE
    _contact_hitbox.damage_interval = _attack_data.damage_interval if _attack_data != null else 0.45
    _contact_hitbox.guard_damage_profile = Hitbox.GuardDamageProfile.NORMAL


func _configure_puff_hitbox() -> void:
    if _puff_hitbox == null:
        return
    _puff_hitbox.damage = _attack_data.damage if _attack_data != null else PUFF_DAMAGE
    _puff_hitbox.damage_interval = _attack_data.damage_interval if _attack_data != null else 0.0
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
    if facing_cell == Vector2i.ZERO:
        return []

    match _tile_shape:
        TileShape.WIDE_2X3:
            return AttackCellShapes.wide(origin_cell, facing_cell, 2, 3, _grid, true)
        TileShape.SELF_3X3:
            return AttackCellShapes.square(origin_cell, 1, _grid, true)
        TileShape.LINE_1X4:
            return AttackCellShapes.line(origin_cell, facing_cell, 4, _grid, true)
    return []


func _create_origin_candidate_attack_data() -> EnemyAttackData:
    var attack_data := EnemyAttackData.new()
    match _mode:
        Mode.TILE:
            match _tile_shape:
                TileShape.WIDE_2X3:
                    attack_data.cell_shape = EnemyAttackData.CellShape.WIDE
                    attack_data.width = 3
                    attack_data.depth = 2
                TileShape.SELF_3X3:
                    attack_data.cell_shape = EnemyAttackData.CellShape.SQUARE
                    attack_data.radius = 1
                TileShape.LINE_1X4:
                    attack_data.cell_shape = EnemyAttackData.CellShape.LINE
                    attack_data.line_length = 4
            return attack_data
        Mode.CHARGE:
            attack_data.cell_shape = EnemyAttackData.CellShape.FULL_LINE
            return attack_data
        Mode.PUFF:
            attack_data.cell_shape = EnemyAttackData.CellShape.SQUARE
            attack_data.radius = 1
            return attack_data
    return null


func _get_charge_cells(origin_cell: Vector2i, facing: Vector2) -> Array[Vector2i]:
    var facing_cell := Vector2i(int(facing.x), int(facing.y))
    var cells: Array[Vector2i] = []
    var cell := origin_cell + facing_cell
    while _grid.is_in_bounds(cell) and _grid.is_land(cell):
        cells.append(cell)
        cell += facing_cell
    return cells
