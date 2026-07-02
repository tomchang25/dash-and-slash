@tool
# grid_terrain_view.gd
# Presentation adapter that draws GridArena terrain, water, grid lines, telegraphs, and arena bounds.
class_name GridTerrainView
extends Node2D

const WALL_THICKNESS := 128.0

@export var grid: GridArena
@export var land_layer: TileMapLayer
@export var water_layer: TileMapLayer
@export var visual_tile_size := 16
@export var terrain_set := 0
@export var land_terrain := 0
@export var grid_color: Color = Color(0.3, 0.3, 0.3, 0.6)
@export var grid_line_width: float = 1.0

var _arena_collision: Node2D

# == Lifecycle ================================================================


func _ready() -> void:
    if grid == null:
        return

    grid.terrain_generated.connect(_on_terrain_generated)
    grid.terrain_cells_changed.connect(_on_terrain_cells_changed)
    grid.telegraphs_changed.connect(_on_telegraphs_changed)

    redraw_all()


func _draw() -> void:
    if grid == null:
        return

    _draw_grid_lines()
    _draw_telegraphs()

# == Signal Handlers ==========================================================


func _on_terrain_generated() -> void:
    redraw_all()


func _on_terrain_cells_changed(cells: Array[Vector2i]) -> void:
    redraw_cells(cells)


func _on_telegraphs_changed() -> void:
    queue_redraw()

# == Common API ===============================================================


## Redraws all presentation state from the current GridArena truth.
func redraw_all() -> void:
    _position_tile_layers()
    _redraw_water_layer()
    _redraw_land_layer()
    _rebuild_arena_collision()
    queue_redraw()


## Redraws a local group of gameplay cells after terrain mutation.
func redraw_cells(cells: Array[Vector2i]) -> void:
    if grid == null or land_layer == null:
        return

    var visual_cells := _gameplay_cells_to_visual_cells(cells)
    for visual_cell: Vector2i in visual_cells:
        land_layer.erase_cell(visual_cell)

    var land_visual_cells: Array[Vector2i] = []
    for cell: Vector2i in cells:
        if grid.is_land(cell):
            land_visual_cells.append_array(_gameplay_cell_to_visual_cells(cell))

    if not land_visual_cells.is_empty():
        land_layer.set_cells_terrain_connect(land_visual_cells, terrain_set, land_terrain)

    queue_redraw()

# == Tile Layers ==============================================================


func _position_tile_layers() -> void:
    if grid == null:
        return

    var top_left := _top_left()
    if land_layer != null:
        land_layer.position = top_left
    if water_layer != null:
        water_layer.position = top_left


func _redraw_water_layer() -> void:
    if grid == null or water_layer == null:
        return

    water_layer.clear()
    var total := Vector2(grid.grid_size) * grid.tile_size
    var tile_count := Vector2i(total / float(visual_tile_size))
    for x in tile_count.x:
        for y in tile_count.y:
            water_layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)


func _redraw_land_layer() -> void:
    if grid == null or land_layer == null:
        return

    land_layer.clear()
    var land_visual_cells := _gameplay_cells_to_visual_cells(grid.get_land_cells())
    if not land_visual_cells.is_empty():
        land_layer.set_cells_terrain_connect(land_visual_cells, terrain_set, land_terrain)


func _gameplay_cells_to_visual_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
    var visual_cells: Array[Vector2i] = []
    for cell: Vector2i in cells:
        visual_cells.append_array(_gameplay_cell_to_visual_cells(cell))
    return visual_cells


func _gameplay_cell_to_visual_cells(cell: Vector2i) -> Array[Vector2i]:
    var visual_cells: Array[Vector2i] = []
    var cells_per_gameplay := int(grid.tile_size / float(visual_tile_size))
    var visual_origin := cell * cells_per_gameplay
    for vx in cells_per_gameplay:
        for vy in cells_per_gameplay:
            visual_cells.append(visual_origin + Vector2i(vx, vy))
    return visual_cells

# == Arena Bounds =============================================================


func _rebuild_arena_collision() -> void:
    if grid == null:
        return

    if _arena_collision != null:
        _arena_collision.free()

    _arena_collision = Node2D.new()
    _arena_collision.name = "ArenaCollision"
    # node-src: ephemeral - rebuilt from grid configuration
    add_child(_arena_collision)

    var half := Vector2(grid.grid_size) * grid.tile_size * 0.5
    _add_wall("WallTop", Vector2(half.x * 2.0 + WALL_THICKNESS * 2.0, WALL_THICKNESS), Vector2(0.0, -half.y - WALL_THICKNESS * 0.5))
    _add_wall("WallBottom", Vector2(half.x * 2.0 + WALL_THICKNESS * 2.0, WALL_THICKNESS), Vector2(0.0, half.y + WALL_THICKNESS * 0.5))
    _add_wall("WallLeft", Vector2(WALL_THICKNESS, half.y * 2.0), Vector2(-half.x - WALL_THICKNESS * 0.5, 0.0))
    _add_wall("WallRight", Vector2(WALL_THICKNESS, half.y * 2.0), Vector2(half.x + WALL_THICKNESS * 0.5, 0.0))


func _add_wall(wall_name: String, size: Vector2, wall_position: Vector2) -> void:
    var body := StaticBody2D.new()
    body.name = wall_name
    var shape := RectangleShape2D.new()
    shape.size = size
    var collision_shape := CollisionShape2D.new()
    collision_shape.shape = shape
    # node-src: ephemeral - rebuilt from grid configuration
    body.add_child(collision_shape)
    body.position = wall_position
    # node-src: ephemeral - rebuilt from grid configuration
    _arena_collision.add_child(body)

# == Overlay Drawing ==========================================================


func _draw_grid_lines() -> void:
    var origin := to_local(_top_left())
    var total := Vector2(grid.grid_size) * grid.tile_size

    for x in range(grid.grid_size.x + 1):
        var offset := float(x) * grid.tile_size
        draw_line(origin + Vector2(offset, 0.0), origin + Vector2(offset, total.y), grid_color, grid_line_width)

    for y in range(grid.grid_size.y + 1):
        var offset := float(y) * grid.tile_size
        draw_line(origin + Vector2(0.0, offset), origin + Vector2(total.x, offset), grid_color, grid_line_width)


func _draw_telegraphs() -> void:
    for cell: Vector2i in grid.get_telegraphed_cells():
        var phase := grid.get_telegraph_phase(cell)
        var color := _telegraph_color(phase)
        if color == Color.TRANSPARENT:
            continue
        var half := Vector2.ONE * grid.tile_size * 0.45
        var center := to_local(grid.cell_center(cell))
        var rect := Rect2(center - half, half * 2.0)
        draw_rect(rect, color, true)
        draw_rect(rect, color.lightened(0.5), false, 2.0)


func _telegraph_color(phase: int) -> Color:
    match phase:
        GridArena.TelegraphPhase.WARNING:
            return Color(1.0, 0.4, 0.2, 0.25)
        GridArena.TelegraphPhase.CHARGE:
            return Color(1.0, 0.55, 0.0, 0.5)
        GridArena.TelegraphPhase.ACTIVE:
            return Color(0.95, 0.1, 0.0, 0.75)
        GridArena.TelegraphPhase.SPAWNING:
            return Color.YELLOW
        GridArena.TelegraphPhase.NONE:
            return Color.TRANSPARENT
        _:
            ToastManager.show_dev_error("Unexpected telegraph phase: %d" % phase)
            return Color.TRANSPARENT

# == Geometry =================================================================


func _top_left() -> Vector2:
    var total := Vector2(grid.grid_size) * grid.tile_size
    return grid.global_position - total * 0.5
