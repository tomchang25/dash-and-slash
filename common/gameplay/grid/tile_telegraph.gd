# tile_telegraph.gd
# Per-entity adapter that writes telegraph phases into the GridArena overlay.
class_name TileTelegraph
extends Node2D

var _grid: GridArena
var _tiles: Array[Vector2i] = []


func setup(grid: GridArena) -> void:
    _grid = grid


func show_warning(tiles: Array[Vector2i]) -> void:
    clear()
    if _grid == null:
        return
    _tiles = tiles.duplicate()
    _grid.set_telegraph(self, _tiles, GridArena.TelegraphPhase.WARNING)


func show_charge(tiles: Array[Vector2i]) -> void:
    clear()
    if _grid == null:
        return
    _tiles = tiles.duplicate()
    _grid.set_telegraph(self, _tiles, GridArena.TelegraphPhase.CHARGE)


func show_active(tiles: Array[Vector2i]) -> void:
    clear()
    if _grid == null:
        return
    _tiles = tiles.duplicate()
    _grid.set_telegraph(self, _tiles, GridArena.TelegraphPhase.ACTIVE)


func clear() -> void:
    if _grid != null and not _tiles.is_empty():
        _grid.clear_telegraph(self, _tiles)
    _tiles.clear()
