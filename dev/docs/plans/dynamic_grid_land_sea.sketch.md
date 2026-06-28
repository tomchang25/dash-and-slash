# Dynamic Land/Sea Gameplay Grid

## Goal

Add a dynamic land/sea gameplay grid with a 16x16 maximum footprint and an 8x8 starting land area, separating gameplay terrain truth from TileMap visuals so enemies pathfind on generated LAND/SEA data while the TileMapLayer only draws land and provides player collision through existing TileSet physics.

## Requirements

1. The maximum gameplay grid is 16x16 cells, and each gameplay cell is 128x128 world pixels.
2. The grid generator owns terrain truth: LAND is enemy-walkable, SEA is enemy-blocking, and TileMapLayer cells are never the source of gameplay logic.
3. The initial generated map starts with a centered 8x8 LAND area inside the 16x16 maximum footprint, because this gives early combat enough room while preserving expansion space in every direction.
4. TileMapLayer is visual/collision output only: LAND gameplay cells are painted into Terrain 0, while SEA gameplay cells remain empty so the water background shows through.
5. Player collision remains handled by Godot TileSet physics on Terrain 0 tiles; the grid system must not generate SEA StaticBody2D collision.
6. Enemy pathfinding must reject SEA cells and prevent diagonal corner cutting when either orthogonal neighbor beside a diagonal step is SEA.
7. Terrain must be mutable at runtime so future player actions can create LAND cells or remove LAND cells back into unwalkable SEA.

## Design

The terrain pipeline is one-way for rendering but mutable for gameplay: generate or mutate gameplay terrain data, cache it in the grid system, draw LAND cells into TileMapLayer, then let Godot physics handle player collision from the painted Terrain 0 tiles. Runtime AI reads only the gameplay terrain cache.

The visual tile density is separate from gameplay cell density. If Terrain 0 uses 16x16 visual tiles, one 128x128 gameplay cell paints an 8x8 block of visual TileMap cells. SEA cells paint nothing, which lets the water background remain visible.

Terrain rules:

- LAND: enemy pathable, valid for enemy spawn, valid for player spawn, painted as Terrain 0 visual tiles.
- SEA: enemy unpathable, invalid for spawn, no visual land tiles, no generated collision.
- Occupied or reserved LAND: temporarily blocked for enemy pathfinding, using the existing occupancy/reservation model.

Diagonal movement rule:

```txt
from = (x, y)
to = (x + 1, y + 1)

Diagonal step is allowed only if:
to is LAND
(x + 1, y) is LAND
(x, y + 1) is LAND
to is not occupied/reserved, unless it is the moving enemy's start cell
```

Generation starts simple: the full 16x16 maximum grid exists immediately, but only a centered 8x8 footprint starts as LAND. Cells outside that starting footprint are SEA until generation rules or player actions convert them into LAND. A later version can add island shaping, connected-component validation, biome rules, authored seeds, or costs for changing terrain.

Runtime terrain mutation rules:

- Creating LAND is allowed only inside the 16x16 maximum bounds.
- Removing LAND is disallowed under the player, under an enemy, or on cells reserved by enemy pathfinding, because removing active gameplay support would create inconsistent movement state.
- Removing LAND may optionally require connectivity validation later; the first pass can skip this if enemy and player state safety checks are enforced.
- Every terrain mutation updates the terrain cache and redraws the affected gameplay cell plus its 8 neighboring gameplay cells, because Godot terrain/autotile output and TileSet collision can change when adjacent land is created or removed.

## Sketch (non-normative)

Proposed grid terrain state:

```gdscript
enum TerrainTile { SEA, LAND }

@export var grid_size := Vector2i(16, 16)
@export var starting_land_size := Vector2i(8, 8)
@export var tile_size := 128.0
@export var visual_tile_size := 16
@export var terrain_layer: TileMapLayer
@export var terrain_set := 0
@export var land_terrain := 0

var _terrain: Array[TerrainTile] = []
```

Suggested lookup helpers:

```gdscript
func _terrain_index(cell: Vector2i) -> int:
    return cell.y * grid_size.x + cell.x


func is_in_bounds(cell: Vector2i) -> bool:
    return cell.x >= 0 and cell.y >= 0 and cell.x < grid_size.x and cell.y < grid_size.y


func is_land(cell: Vector2i) -> bool:
    return is_in_bounds(cell) and _terrain[_terrain_index(cell)] == TerrainTile.LAND


func is_sea(cell: Vector2i) -> bool:
    return not is_land(cell)


func is_walkable(cell: Vector2i) -> bool:
    return is_land(cell)
```

Suggested movement gate:

```gdscript
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
```

Enemy BFS integration shape:

```gdscript
func _can_path_step(current: Vector2i, next: Vector2i, start: Vector2i, blocked_cell: Vector2i) -> bool:
    if not _grid.can_move_between(current, next):
        return false
    if next == blocked_cell:
        return false
    if next != start and _grid.is_blocked(next):
        return false
    return true
```

Suggested LAND painting:

```gdscript
func redraw_terrain_layer() -> void:
    if terrain_layer == null:
        return

    terrain_layer.clear()
    var visual_cells_per_gameplay_cell := int(tile_size / float(visual_tile_size))
    var land_visual_cells: Array[Vector2i] = []

    for x in grid_size.x:
        for y in grid_size.y:
            var gameplay_cell := Vector2i(x, y)
            if not is_land(gameplay_cell):
                continue
            var visual_origin := gameplay_cell * visual_cells_per_gameplay_cell
            for vx in visual_cells_per_gameplay_cell:
                for vy in visual_cells_per_gameplay_cell:
                    land_visual_cells.append(visual_origin + Vector2i(vx, vy))

    terrain_layer.set_cells_terrain_connect(land_visual_cells, terrain_set, land_terrain)
```

Suggested local redraw for runtime terrain mutation:

```gdscript
func redraw_cell_and_neighbors(cell: Vector2i) -> void:
    if terrain_layer == null:
        return

    var visual_cells_per_gameplay_cell := int(tile_size / float(visual_tile_size))
    var visual_cells: Array[Vector2i] = []

    for ox in range(-1, 2):
        for oy in range(-1, 2):
            var gameplay_cell := cell + Vector2i(ox, oy)
            if not is_in_bounds(gameplay_cell):
                continue

            var visual_origin := gameplay_cell * visual_cells_per_gameplay_cell
            for vx in visual_cells_per_gameplay_cell:
                for vy in visual_cells_per_gameplay_cell:
                    visual_cells.append(visual_origin + Vector2i(vx, vy))

    for visual_cell in visual_cells:
        terrain_layer.erase_cell(visual_cell)

    var land_visual_cells: Array[Vector2i] = []
    for ox in range(-1, 2):
        for oy in range(-1, 2):
            var gameplay_cell := cell + Vector2i(ox, oy)
            if not is_land(gameplay_cell):
                continue

            var visual_origin := gameplay_cell * visual_cells_per_gameplay_cell
            for vx in visual_cells_per_gameplay_cell:
                for vy in visual_cells_per_gameplay_cell:
                    land_visual_cells.append(visual_origin + Vector2i(vx, vy))

    if not land_visual_cells.is_empty():
        terrain_layer.set_cells_terrain_connect(land_visual_cells, terrain_set, land_terrain)
```

The local redraw erases and repaints the 3x3 gameplay-cell region around the edited cell. This is intentional: if a LAND cell changes to SEA, neighboring LAND cells may need new shoreline terrain variants and collision polygons.

Mutation calls should use the local redraw:

```gdscript
func redraw_after_terrain_mutation(cell: Vector2i) -> void:
    redraw_cell_and_neighbors(cell)
```

Suggested generation entry points:

```gdscript
func generate_grid(seed_value: int = 0) -> void:
    _terrain.resize(grid_size.x * grid_size.y)
    _fill_with_sea()
    _generate_starting_land(seed_value)
    _ensure_spawn_land()
    redraw_terrain_layer()
```

Suggested runtime mutation API:

```gdscript
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
    if world_to_grid(get_player_world_position()) == cell:
        return false
    return true
```

Migration steps:

1. Replace fixed grid-size constants with instance grid size reads inside grid conversion, bounds checks, nearest-cell search, arena visuals, and arena wall generation.
2. Add terrain cache and centered 8x8 starting LAND generation to the grid manager.
3. Export the visual terrain TileMapLayer on the grid manager or wire it from the arena scene.
4. Replace enemy path step validation so it uses the grid movement gate before occupancy/reservation checks.
5. Replace spawn fallback scans so they only accept LAND and search outward from the player rather than blindly accepting the player cell.
6. Add terrain mutation entry points for future player-created and player-removed land, with safety checks for occupied, reserved, and player cells.
7. Keep water background and water animation out of this change unless a visual regression appears.

## Non-Goals

1. Do not make TileMapLayer the gameplay terrain authority.
2. Do not generate collision for SEA cells.
3. Do not implement advanced procedural island generation in the first pass beyond the centered starting land footprint.
4. Do not replace enemy BFS with AStarGrid2D yet.
5. Do not change player movement to grid-based movement.

## Acceptance Criteria

1. A 16x16 maximum gameplay grid can generate a centered 8x8 LAND starting area surrounded by SEA without relying on TileMapLayer cell data for logic.
2. LAND gameplay cells are drawn into Terrain 0 on the TileMapLayer, and empty SEA cells show the water background.
3. Player collision continues to come from Terrain 0 TileSet physics.
4. Enemies never pathfind through SEA cells.
5. Enemies cannot move diagonally through a SEA corner.
6. Player and enemy spawn selection never chooses SEA.
7. Runtime terrain mutation can create LAND and remove LAND back into SEA while updating visuals and preserving player, enemy, and reservation safety.
8. Existing occupancy, reservation, telegraph, and enemy wave behavior continue to work on LAND cells.
