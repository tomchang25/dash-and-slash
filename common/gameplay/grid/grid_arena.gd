@tool
# grid_arena.gd
# 6x6 grid manager. Owns tile occupancy, world↔grid coordinate conversion,
# telegraph state, and node-based arena visuals. Enemy AI queries this node for
# pathfinding obstacles and player position; the player is never constrained
# by the grid — only enemies are.
class_name GridArena
extends Node2D

enum TelegraphPhase { NONE, WARNING, CHARGE, ACTIVE }

const GRID_SIZE := Vector2i(6, 6)
const WALL_THICKNESS := 128.0

@export var tile_size: float = 128.0
@export var grid_color: Color = Color(0.3, 0.3, 0.3, 0.6)
@export var grid_line_width: float = 1.0

var _occupants: Dictionary = { } # { Object: Array[Vector2i] }
var _reservations: Dictionary = { } # { Object: Vector2i }
var _telegraphs: Dictionary = { } # { (x,y): TelegraphPhase }
var _player_grid: Vector2i = Vector2i.ZERO
var _arena_visuals: Node2D


func _ready() -> void:
    _build_arena_visuals()
    _build_arena_collision()


func _build_arena_visuals() -> void:
    if _arena_visuals != null:
        _arena_visuals.queue_free()

    _arena_visuals = Node2D.new()
    _arena_visuals.name = "ArenaVisuals"
    # node-src: runtime visual grid
    add_child(_arena_visuals)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.1, 0.12, 0.18)
    style.border_color = grid_color
    style.border_width_left = int(grid_line_width)
    style.border_width_top = int(grid_line_width)
    style.border_width_right = int(grid_line_width)
    style.border_width_bottom = int(grid_line_width)

    var origin := -Vector2(GRID_SIZE) * tile_size * 0.5
    for x in GRID_SIZE.x:
        for y in GRID_SIZE.y:
            var tile := Panel.new()
            tile.name = "Tile_%d_%d" % [x, y]
            tile.position = origin + Vector2(x, y) * tile_size
            tile.size = Vector2.ONE * tile_size
            tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
            tile.add_theme_stylebox_override("panel", style)
            _arena_visuals.add_child(tile)


func _build_arena_collision() -> void:
    var collision := Node2D.new()
    collision.name = "ArenaCollision"
    # node-src: runtime arena walls
    add_child(collision)

    var half := Vector2(GRID_SIZE) * tile_size * 0.5
    var shape := RectangleShape2D.new()

    # Top wall
    var top := StaticBody2D.new()
    top.name = "WallTop"
    shape.size = Vector2(half.x * 2.0 + WALL_THICKNESS * 2.0, WALL_THICKNESS)
    var top_shape := CollisionShape2D.new()
    top_shape.shape = shape
    top.add_child(top_shape)
    top.position = Vector2(0.0, -half.y - WALL_THICKNESS * 0.5)
    collision.add_child(top)

    # Bottom wall
    var bottom := StaticBody2D.new()
    bottom.name = "WallBottom"
    shape = RectangleShape2D.new()
    shape.size = Vector2(half.x * 2.0 + WALL_THICKNESS * 2.0, WALL_THICKNESS)
    var bottom_shape := CollisionShape2D.new()
    bottom_shape.shape = shape
    bottom.add_child(bottom_shape)
    bottom.position = Vector2(0.0, half.y + WALL_THICKNESS * 0.5)
    collision.add_child(bottom)

    # Left wall
    var left := StaticBody2D.new()
    left.name = "WallLeft"
    shape = RectangleShape2D.new()
    shape.size = Vector2(WALL_THICKNESS, half.y * 2.0)
    var left_shape := CollisionShape2D.new()
    left_shape.shape = shape
    left.add_child(left_shape)
    left.position = Vector2(-half.x - WALL_THICKNESS * 0.5, 0.0)
    collision.add_child(left)

    # Right wall
    var right := StaticBody2D.new()
    right.name = "WallRight"
    shape = RectangleShape2D.new()
    shape.size = Vector2(WALL_THICKNESS, half.y * 2.0)
    var right_shape := CollisionShape2D.new()
    right_shape.shape = shape
    right.add_child(right_shape)
    right.position = Vector2(half.x + WALL_THICKNESS * 0.5, 0.0)
    collision.add_child(right)


func _top_left() -> Vector2:
    var total := Vector2(GRID_SIZE) * tile_size
    return global_position - total * 0.5


func world_to_grid(world: Vector2) -> Vector2i:
    var local := world - _top_left()
    return Vector2i(int(local.x / tile_size), int(local.y / tile_size))


func grid_to_world(cell: Vector2i) -> Vector2:
    return _top_left() + Vector2(cell) * tile_size + Vector2.ONE * tile_size * 0.5


func cell_center(cell: Vector2i) -> Vector2:
    return grid_to_world(cell)


func is_in_bounds(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < GRID_SIZE.x and cell.y < GRID_SIZE.y


func is_occupied(cell: Vector2i) -> bool:
    for tiles in _occupants.values():
        if cell in tiles:
            return true
    return false


func is_reserved(cell: Vector2i) -> bool:
    return cell in _reservations.values()


func register_occupant(entity: Object, tiles: Array[Vector2i]) -> void:
    _occupants[entity] = tiles.duplicate()


func unregister_occupant(entity: Object) -> void:
    _occupants.erase(entity)
    _reservations.erase(entity)


func reserve_cell(entity: Object, cell: Vector2i) -> void:
    _reservations[entity] = cell


func clear_reservation(entity: Object) -> void:
    _reservations.erase(entity)


func is_blocked(cell: Vector2i) -> bool:
    return is_occupied(cell) or is_reserved(cell)


func is_empty(cell: Vector2i) -> bool:
    return not is_blocked(cell)


func get_occupants() -> Array:
    return _occupants.keys()


func set_player_cell(pos: Vector2) -> void:
    _player_grid = world_to_grid(pos)


func get_player_cell() -> Vector2i:
    return _player_grid


func nearest_empty_cell(near: Vector2) -> Vector2i:
    var center := world_to_grid(near)
    if is_empty(center) and is_in_bounds(center):
        return center
    var best: Vector2i = Vector2i.ZERO
    var best_dist := 9999.0
    for x in GRID_SIZE.x:
        for y in GRID_SIZE.y:
            var c := Vector2i(x, y)
            if is_empty(c):
                var d := Vector2(c).distance_squared_to(Vector2(center))
                if d < best_dist:
                    best_dist = d
                    best = c
    return best


func set_telegraph(tiles: Array[Vector2i], phase: TelegraphPhase) -> void:
    for t in tiles:
        _telegraphs[t] = phase
    queue_redraw()


func clear_telegraph(tiles: Array[Vector2i]) -> void:
    for t in tiles:
        _telegraphs.erase(t)
    queue_redraw()


func clear_all_telegraphs() -> void:
    _telegraphs.clear()
    queue_redraw()
