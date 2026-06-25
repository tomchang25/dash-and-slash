# tile_telegraph.gd
# Draws telegraph overlays on the GridArena. Managed per-entity — each enemy
# that can telegraph owns one of these as a sibling to its body.
# Phases: WARNING (faint fill) → CHARGE (pulsing border) → ACTIVE (flash).
class_name TileTelegraph
extends Node2D

var _grid: GridArena
var _tiles: Array[Vector2i] = []
var _phase: int = 0 # GridArena.TelegraphPhase


func setup(grid: GridArena) -> void:
    _grid = grid


func show_warning(tiles: Array[Vector2i]) -> void:
    _tiles = tiles
    _grid.set_telegraph(tiles, GridArena.TelegraphPhase.WARNING)
    queue_redraw()


func show_charge(tiles: Array[Vector2i]) -> void:
    _tiles = tiles
    _grid.set_telegraph(tiles, GridArena.TelegraphPhase.CHARGE)
    queue_redraw()


func show_active(tiles: Array[Vector2i]) -> void:
    _tiles = tiles
    _grid.set_telegraph(tiles, GridArena.TelegraphPhase.ACTIVE)
    queue_redraw()


func clear() -> void:
    _grid.clear_telegraph(_tiles)
    _tiles.clear()
    queue_redraw()


func _draw() -> void:
    if _tiles.is_empty() or _grid == null:
        return
    var color := _phase_color()
    var outline := color.lightened(0.5)
    for t in _tiles:
        var pos := _grid.cell_center(t)
        var half := Vector2.ONE * _grid.tile_size * 0.45
        var rect := Rect2(pos - half, half * 2.0)
        draw_rect(rect, color, true)
        draw_rect(rect, outline, false, 2.0)


func _phase_color() -> Color:
    match _phase:
        GridArena.TelegraphPhase.WARNING:
            return Color(1.0, 0.4, 0.2, 0.25)
        GridArena.TelegraphPhase.CHARGE:
            return Color(1.0, 0.2, 0.1, 0.45)
        GridArena.TelegraphPhase.ACTIVE:
            return Color(1.0, 0.05, 0.0, 0.7)
        _:
            return Color.TRANSPARENT
