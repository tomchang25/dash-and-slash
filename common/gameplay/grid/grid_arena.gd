@tool
# grid_arena.gd
# Dynamic grid manager with LAND/SEA terrain, generation, TileMapLayer drawing,
# occupancy, reservations, and telegraph system. Enemy AI queries terrain + occupancy
# for pathfinding; the player is never constrained by the grid.
class_name GridArena
extends Node2D

enum TelegraphPhase { NONE, WARNING, CHARGE, ACTIVE, SPAWNING }
enum TerrainTile { SEA, LAND }

const WALL_THICKNESS := 128.0

@export var grid_size := Vector2i(16, 16)
@export var starting_land_size := Vector2i(8, 8)
@export var tile_size: float = 128.0
@export var visual_tile_size := 16
@export var terrain_layer: TileMapLayer
@export var terrain_set := 0
@export var land_terrain := 0
@export var grid_color: Color = Color(0.3, 0.3, 0.3, 0.6)
@export var grid_line_width: float = 1.0

var _terrain: Array[int] = []
var _occupants: Dictionary = { }
var _reservations: Dictionary = { }
var _telegraphs: Dictionary = { }
var _player_grid: Vector2i = Vector2i.ZERO
var _arena_visuals: Node2D
var _generated := false

# == Lifecycle ================================================================


func _ready() -> void:
    if not _generated:
        generate_grid()
    _build_arena_visuals()
    _build_arena_collision()


func _draw() -> void:
    for cell: Vector2i in _telegraphs.keys():
        var sources: Dictionary = _telegraphs[cell]
        var phase: int = _resolve_highest_phase(sources)
        var color := _telegraph_color(phase)
        if color == Color.TRANSPARENT:
            continue
        var half := Vector2.ONE * tile_size * 0.45
        var center := to_local(cell_center(cell))
        var rect := Rect2(center - half, half * 2.0)
        draw_rect(rect, color, true)
        draw_rect(rect, color.lightened(0.5), false, 2.0)

# == Terrain Generation =======================================================


func generate_grid() -> void:
    var total_cells := grid_size.x * grid_size.y
    if _terrain.size() != total_cells:
        _terrain.resize(total_cells)
    for i in total_cells:
        _terrain[i] = TerrainTile.SEA
    _generate_starting_land()
    _ensure_spawn_land()
    redraw_terrain_layer()
    _generated = true


func _generate_starting_land() -> void:
    var offset := (grid_size - starting_land_size) / 2
    for x in starting_land_size.x:
        for y in starting_land_size.y:
            var cell := Vector2i(offset.x + x, offset.y + y)
            _terrain[_terrain_index(cell)] = TerrainTile.LAND


func _ensure_spawn_land() -> void:
    var center := grid_size / 2
    if is_in_bounds(center) and not is_land(center):
        _terrain[_terrain_index(center)] = TerrainTile.LAND

# == Terrain Queries ==========================================================


func _terrain_index(cell: Vector2i) -> int:
    return cell.y * grid_size.x + cell.x


func is_land(cell: Vector2i) -> bool:
    return is_in_bounds(cell) and _terrain[_terrain_index(cell)] == TerrainTile.LAND


func is_sea(cell: Vector2i) -> bool:
    return not is_land(cell)


func is_walkable(cell: Vector2i) -> bool:
    return is_land(cell)


func can_move_between(from: Vector2i, to: Vector2i) -> bool:
    if not is_land(to):
        return false
    var delta := to - from
    if absi(delta.x) == 1 and absi(delta.y) == 1:
        if not is_land(from + Vector2i(delta.x, 0)):
            return false
        if not is_land(from + Vector2i(0, delta.y)):
            return false
    return true

# == Terrain Mutation =========================================================


func set_land(cell: Vector2i) -> bool:
    if not is_in_bounds(cell):
        return false
    _terrain[_terrain_index(cell)] = TerrainTile.LAND
    redraw_after_terrain_mutation(cell)
    return true


func set_sea(cell: Vector2i) -> bool:
    if not can_remove_land(cell):
        return false
    _terrain[_terrain_index(cell)] = TerrainTile.SEA
    redraw_after_terrain_mutation(cell)
    return true


func can_remove_land(cell: Vector2i) -> bool:
    if not is_land(cell):
        return false
    if is_occupied(cell) or is_reserved(cell):
        return false
    if _player_grid == cell:
        return false
    return true

# == TileMapLayer Drawing =====================================================


func redraw_terrain_layer() -> void:
    if terrain_layer == null:
        return

    terrain_layer.clear()
    var cells_per_gameplay := int(tile_size / float(visual_tile_size))
    var land_visual_cells: Array[Vector2i] = []

    for x in grid_size.x:
        for y in grid_size.y:
            var cell := Vector2i(x, y)
            if not is_land(cell):
                continue
            var visual_origin := cell * cells_per_gameplay
            for vx in cells_per_gameplay:
                for vy in cells_per_gameplay:
                    land_visual_cells.append(visual_origin + Vector2i(vx, vy))

    if not land_visual_cells.is_empty():
        terrain_layer.set_cells_terrain_connect(land_visual_cells, terrain_set, land_terrain)


func redraw_after_terrain_mutation(cell: Vector2i) -> void:
    redraw_cell_and_neighbors(cell)


func redraw_cell_and_neighbors(cell: Vector2i) -> void:
    if terrain_layer == null:
        return

    var cells_per_gameplay := int(tile_size / float(visual_tile_size))
    var visual_cells: Array[Vector2i] = []

    for ox in range(-1, 2):
        for oy in range(-1, 2):
            var gameplay_cell := cell + Vector2i(ox, oy)
            if not is_in_bounds(gameplay_cell):
                continue
            var visual_origin := gameplay_cell * cells_per_gameplay
            for vx in cells_per_gameplay:
                for vy in cells_per_gameplay:
                    visual_cells.append(visual_origin + Vector2i(vx, vy))

    for visual_cell in visual_cells:
        terrain_layer.erase_cell(visual_cell)

    var land_visual_cells: Array[Vector2i] = []
    for ox in range(-1, 2):
        for oy in range(-1, 2):
            var gameplay_cell := cell + Vector2i(ox, oy)
            if not is_land(gameplay_cell):
                continue
            var visual_origin := gameplay_cell * cells_per_gameplay
            for vx in cells_per_gameplay:
                for vy in cells_per_gameplay:
                    land_visual_cells.append(visual_origin + Vector2i(vx, vy))

    if not land_visual_cells.is_empty():
        terrain_layer.set_cells_terrain_connect(land_visual_cells, terrain_set, land_terrain)

# == Arena Visuals ============================================================


func _build_arena_visuals() -> void:
    if _arena_visuals != null:
        _arena_visuals.queue_free()

    _arena_visuals = Node2D.new()
    _arena_visuals.name = "ArenaVisuals"
    add_child(_arena_visuals)

    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.08, 0.1, 0.12, 0.18)
    style.border_color = grid_color
    style.border_width_left = int(grid_line_width)
    style.border_width_top = int(grid_line_width)
    style.border_width_right = int(grid_line_width)
    style.border_width_bottom = int(grid_line_width)

    var origin := -Vector2(grid_size) * tile_size * 0.5
    for x in grid_size.x:
        for y in grid_size.y:
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
    add_child(collision)

    var half := Vector2(grid_size) * tile_size * 0.5
    var shape := RectangleShape2D.new()

    var top := StaticBody2D.new()
    top.name = "WallTop"
    shape.size = Vector2(half.x * 2.0 + WALL_THICKNESS * 2.0, WALL_THICKNESS)
    var top_shape := CollisionShape2D.new()
    top_shape.shape = shape
    top.add_child(top_shape)
    top.position = Vector2(0.0, -half.y - WALL_THICKNESS * 0.5)
    collision.add_child(top)

    var bottom := StaticBody2D.new()
    bottom.name = "WallBottom"
    shape = RectangleShape2D.new()
    shape.size = Vector2(half.x * 2.0 + WALL_THICKNESS * 2.0, WALL_THICKNESS)
    var bottom_shape := CollisionShape2D.new()
    bottom_shape.shape = shape
    bottom.add_child(bottom_shape)
    bottom.position = Vector2(0.0, half.y + WALL_THICKNESS * 0.5)
    collision.add_child(bottom)

    var left := StaticBody2D.new()
    left.name = "WallLeft"
    shape = RectangleShape2D.new()
    shape.size = Vector2(WALL_THICKNESS, half.y * 2.0)
    var left_shape := CollisionShape2D.new()
    left_shape.shape = shape
    left.add_child(left_shape)
    left.position = Vector2(-half.x - WALL_THICKNESS * 0.5, 0.0)
    collision.add_child(left)

    var right := StaticBody2D.new()
    right.name = "WallRight"
    shape = RectangleShape2D.new()
    shape.size = Vector2(WALL_THICKNESS, half.y * 2.0)
    var right_shape := CollisionShape2D.new()
    right_shape.shape = shape
    right.add_child(right_shape)
    right.position = Vector2(half.x + WALL_THICKNESS * 0.5, 0.0)
    collision.add_child(right)

# == Coordinate Conversion ====================================================


func _top_left() -> Vector2:
    var total := Vector2(grid_size) * tile_size
    return global_position - total * 0.5


func world_to_grid(world: Vector2) -> Vector2i:
    var local := world - _top_left()
    return Vector2i(int(local.x / tile_size), int(local.y / tile_size))


func grid_to_world(cell: Vector2i) -> Vector2:
    return _top_left() + Vector2(cell) * tile_size + Vector2.ONE * tile_size * 0.5


func cell_center(cell: Vector2i) -> Vector2:
    return grid_to_world(cell)


func is_in_bounds(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y

# == Occupancy ================================================================


func is_occupied(cell: Vector2i) -> bool:
    for tiles in _occupants.values():
        if cell in tiles:
            return true
    return false


func is_reserved(cell: Vector2i) -> bool:
    for cells in _reservations.values():
        if cell in cells:
            return true
    return false


func register_occupant(entity: Object, tiles: Array[Vector2i]) -> void:
    _occupants[entity] = tiles.duplicate()


func unregister_occupant(entity: Object) -> void:
    _occupants.erase(entity)
    _reservations.erase(entity)


func reserve_cell(entity: Object, cell: Vector2i) -> void:
    reserve_cells(entity, [cell])


func reserve_cells(entity: Object, cells: Array[Vector2i]) -> void:
    _reservations[entity] = cells.duplicate()


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
    for x in grid_size.x:
        for y in grid_size.y:
            var c := Vector2i(x, y)
            if is_empty(c):
                var d := Vector2(c).distance_squared_to(Vector2(center))
                if d < best_dist:
                    best_dist = d
                    best = c
    return best

# == Telegraph =================================================================


func set_telegraph(source: Object, tiles: Array[Vector2i], phase: TelegraphPhase) -> void:
    for t in tiles:
        var sources: Dictionary = _telegraphs.get(t, { })
        sources[source] = phase
        _telegraphs[t] = sources
    queue_redraw()


func clear_telegraph(source: Object, tiles: Array[Vector2i]) -> void:
    for t in tiles:
        if not _telegraphs.has(t):
            continue
        var sources: Dictionary = _telegraphs[t]
        sources.erase(source)
        if sources.is_empty():
            _telegraphs.erase(t)
    queue_redraw()


func clear_all_telegraphs() -> void:
    _telegraphs.clear()
    queue_redraw()


func _resolve_highest_phase(sources: Dictionary) -> int:
    var best := int(TelegraphPhase.NONE)
    for phase: int in sources.values():
        if phase > best:
            best = phase
    return best


func _telegraph_color(phase: int) -> Color:
    match phase:
        TelegraphPhase.WARNING:
            return Color(1.0, 0.4, 0.2, 0.25)
        TelegraphPhase.CHARGE:
            return Color(1.0, 0.55, 0.0, 0.5)
        TelegraphPhase.ACTIVE:
            return Color(0.95, 0.1, 0.0, 0.75)
        TelegraphPhase.SPAWNING:
            return Color.YELLOW
        _:
            return Color.TRANSPARENT
