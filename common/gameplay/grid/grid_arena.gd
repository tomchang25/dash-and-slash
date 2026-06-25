# grid_arena.gd
# 6x6 grid manager. Owns tile occupancy, world↔grid coordinate conversion,
# telegraph state, and debug grid drawing. Enemy AI queries this node for
# pathfinding obstacles and player position; the player is never constrained
# by the grid — only enemies are.
class_name GridArena
extends Node2D

enum TelegraphPhase { NONE, WARNING, CHARGE, ACTIVE }

const GRID_SIZE := Vector2i(6, 6)

@export var tile_size: float = 64.0
@export var grid_color: Color = Color(0.3, 0.3, 0.3, 0.6)
@export var grid_line_width: float = 1.0

var _occupants: Dictionary = { } # { Object: Array[Vector2i] }
var _telegraphs: Dictionary = { } # { (x,y): TelegraphPhase }
var _player_grid: Vector2i = Vector2i.ZERO


func _ready() -> void:
    queue_redraw()


func _draw() -> void:
    var origin := _top_left()
    var total := GRID_SIZE * tile_size
    for i in GRID_SIZE.x + 1:
        var x := origin.x + i * tile_size
        draw_line(Vector2(x, origin.y), Vector2(x, origin.y + total.y), grid_color, grid_line_width)
    for j in GRID_SIZE.y + 1:
        var y := origin.y + j * tile_size
        draw_line(Vector2(origin.x, y), Vector2(origin.x + total.x, y), grid_color, grid_line_width)


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


func register_occupant(entity: Object, tiles: Array[Vector2i]) -> void:
    _occupants[entity] = tiles.duplicate()


func unregister_occupant(entity: Object) -> void:
    _occupants.erase(entity)


func get_occupants() -> Array:
    return _occupants.keys()


func set_player_cell(pos: Vector2) -> void:
    _player_grid = world_to_grid(pos)


func get_player_cell() -> Vector2i:
    return _player_grid


func nearest_empty_cell(near: Vector2) -> Vector2i:
    var center := world_to_grid(near)
    if not is_occupied(center) and is_in_bounds(center):
        return center
    var best: Vector2i = Vector2i.ZERO
    var best_dist := 9999.0
    for x in GRID_SIZE.x:
        for y in GRID_SIZE.y:
            var c := Vector2i(x, y)
            if not is_occupied(c):
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
