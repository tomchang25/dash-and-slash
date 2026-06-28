# enemy_attack_controller.gd
# Shared cell-based attack controller that owns cell snapshots, telegraph phases,
# per-cell tile hitbox creation, hitbox enablement, and cleanup for tile attacks.
class_name EnemyAttackController
extends Node

var _grid: GridArena
var _telegraph: TileTelegraph
var _tile_hitboxes: Array[Hitbox] = []
var _hitbox_parent: Node
var _attack_cells: Array[Vector2i] = []
var _prepared := false


func setup(grid: GridArena, telegraph: TileTelegraph, hitbox_parent: Node) -> void:
    _grid = grid
    _telegraph = telegraph
    _hitbox_parent = hitbox_parent
    if _telegraph != null:
        _telegraph.setup(grid)
    cancel()


## Computes attack cells for the given origin, facing, and attack data without side effects.
static func get_attack_cells(origin_cell: Vector2i, facing: Vector2, attack_data: EnemyAttackData, grid: GridArena = null) -> Array[Vector2i]:
    var facing_cell := Vector2i(int(facing.x), int(facing.y))
    if facing_cell == Vector2i.ZERO:
        return []

    match attack_data.cell_shape:
        EnemyAttackData.CellShape.LINE:
            return AttackCellShapes.line(origin_cell, facing_cell, attack_data.line_length, grid, true)
        EnemyAttackData.CellShape.WIDE:
            return AttackCellShapes.wide(origin_cell, facing_cell, attack_data.depth, attack_data.width, grid, true)
        EnemyAttackData.CellShape.SQUARE:
            return AttackCellShapes.square(origin_cell, attack_data.radius, grid, true)
        EnemyAttackData.CellShape.FULL_LINE:
            return _full_line_cells(origin_cell, facing_cell, grid)
    return []


## Prepares the controller for an attack. Computes cells, configures the tile hitbox geometry,
## and stores prepared state for subsequent telegraph/attack calls.
func prepare(origin_cell: Vector2i, facing: Vector2, attack_data: EnemyAttackData) -> bool:
    cancel()
    if _grid == null:
        return false

    _attack_cells = get_attack_cells(origin_cell, facing, attack_data, _grid)
    if _attack_cells.is_empty():
        return false

    _create_tile_hitboxes(attack_data.damage, attack_data.damage_interval)
    _prepared = true
    return true


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
    if _telegraph != null:
        _telegraph.show_active(_attack_cells)
    for hitbox in _tile_hitboxes:
        hitbox.set_enabled(true)


func end_attack() -> void:
    for hitbox in _tile_hitboxes:
        hitbox.set_enabled(false)
    if _telegraph != null:
        _telegraph.clear()
    _attack_cells.clear()
    _prepared = false


func cancel() -> void:
    for hitbox in _tile_hitboxes:
        if is_instance_valid(hitbox):
            hitbox.set_enabled(false)
            hitbox.queue_free()
    _tile_hitboxes.clear()
    if _telegraph != null:
        _telegraph.clear()
    _attack_cells.clear()
    _prepared = false


func get_cells() -> Array[Vector2i]:
    return _attack_cells.duplicate()


func clear_cell(cell: Vector2i) -> void:
    if _telegraph != null:
        _telegraph.clear_cell(cell)


## Computes a full line from the cell adjacent to origin to the grid boundary in the facing direction.
static func _full_line_cells(origin_cell: Vector2i, facing_cell: Vector2i, grid: GridArena) -> Array[Vector2i]:
    var cells: Array[Vector2i] = []
    var cell := origin_cell + facing_cell
    while grid != null and grid.is_in_bounds(cell):
        cells.append(cell)
        cell += facing_cell
    return cells


## Creates one Hitbox per attack cell, each sized to a single tile.
func _create_tile_hitboxes(damage: float, damage_interval: float) -> void:
    if _grid == null or _hitbox_parent == null or _attack_cells.is_empty():
        return

    var size := Vector2.ONE * _grid.tile_size * 0.9
    for cell in _attack_cells:
        var hitbox := Hitbox.new()
        hitbox.damage = damage
        hitbox.damage_interval = damage_interval
        hitbox.guard_damage_profile = Hitbox.GuardDamageProfile.NORMAL

        var shape := CollisionShape2D.new()
        var rect := RectangleShape2D.new()
        rect.size = size
        shape.shape = rect
        hitbox.collision_shape = shape

        # node-src: ephemeral - per-cell tile hitbox collision shape
        hitbox.add_child(shape)

        hitbox.monitoring = false

        # node-src: ephemeral - per-cell tile hitbox
        _hitbox_parent.add_child(hitbox)
        hitbox.global_position = _grid.cell_center(cell)
        _tile_hitboxes.append(hitbox)
