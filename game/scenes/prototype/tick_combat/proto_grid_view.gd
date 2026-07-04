# proto_grid_view.gd
# Grey-box presentation for the tick prototype: land tiles, grid lines, enemy danger tiles with
# tick countdowns, player-side previews in a distinct cyan palette, and deny/detonation/swing flashes.
class_name ProtoGridView
extends Node2D

# -- Constants --

const LAND_COLOR := Color(0.22, 0.24, 0.27)
const GRID_LINE_COLOR := Color(0.36, 0.39, 0.43, 0.5)
# Danger palette matches the production telegraph colors (GridTerrainView) so the read carries over.
const DANGER_WARNING_COLOR := Color(1.0, 0.4, 0.2, 0.25)
const DANGER_CHARGE_COLOR := Color(1.0, 0.55, 0.0, 0.5)
const DANGER_ACTIVE_COLOR := Color(0.95, 0.1, 0.0, 0.75)
# Player-side previews stay in a cyan family, strictly separated from the enemy danger palette.
const PREVIEW_FILL_COLOR := Color(0.3, 0.9, 1.0, 0.22)
const PREVIEW_OUTLINE_COLOR := Color(0.3, 0.9, 1.0, 0.9)
const PREVIEW_BLOCKED_COLOR := Color(0.55, 0.65, 0.75, 0.15)
const SWING_FLASH_COLOR := Color(0.5, 0.95, 1.0, 0.55)
const DENY_FLASH_COLOR := Color(1.0, 1.0, 1.0, 0.85)
const FLASH_SEC := 0.2
const COUNTDOWN_FONT_SIZE := 52

# -- Exports --

@export var grid: GridArena

# -- State --

var _danger: Array[Dictionary] = []
var _preview: Dictionary = { }
var _flashes: Array[Dictionary] = []


# == Lifecycle ==


func _ready() -> void:
    if grid == null:
        ToastManager.show_dev_error("ProtoGridView: grid export is not wired.")
        return
    grid.terrain_generated.connect(queue_redraw)
    grid.terrain_cells_changed.connect(func(_cells: Array[Vector2i]) -> void: queue_redraw())
    queue_redraw()


func _process(delta: float) -> void:
    if _flashes.is_empty():
        return
    for flash in _flashes:
        flash["time_left"] = float(flash["time_left"]) - delta
    for i in range(_flashes.size() - 1, -1, -1):
        if float(_flashes[i]["time_left"]) <= 0.0:
            _flashes.remove_at(i)
    queue_redraw()


func _draw() -> void:
    if grid == null:
        return
    _draw_terrain()
    _draw_danger()
    _draw_preview()
    _draw_flashes()


# == Common API ==


## Replaces the enemy danger display data: one {cells, ticks, dest?} dictionary per pending attack.
func set_danger(danger: Array[Dictionary]) -> void:
    _danger = danger
    queue_redraw()


## Replaces the player preview state; redraws only when the preview actually changed.
func set_preview(preview: Dictionary) -> void:
    if preview == _preview:
        return
    _preview = preview
    queue_redraw()


## Flashes a soft-deny marker on an illegal input's target cell; a denied input never consumes a tick.
func flash_deny(target_cell: Vector2i) -> void:
    _add_flash([target_cell], DENY_FLASH_COLOR, true)


## Flashes the player-side swing/impact color over the given cells.
func flash_swing(cells: Array[Vector2i]) -> void:
    _add_flash(cells, SWING_FLASH_COLOR, false)


## Flashes the enemy detonation color over the given cells.
func flash_detonation(cells: Array[Vector2i]) -> void:
    _add_flash(cells, DANGER_ACTIVE_COLOR, false)


# == Drawing ==


func _add_flash(cells: Array[Vector2i], color: Color, outline_only: bool) -> void:
    _flashes.append({
        "cells": cells.duplicate(),
        "color": color,
        "outline_only": outline_only,
        "time_left": FLASH_SEC,
    })
    queue_redraw()


func _draw_terrain() -> void:
    for land_cell: Vector2i in grid.get_land_cells():
        draw_rect(_cell_rect(land_cell, 1.0), LAND_COLOR)
    for x in range(grid.grid_size.x + 1):
        var top := to_local(grid.cell_center(Vector2i(x, 0))) + Vector2(-grid.tile_size * 0.5, -grid.tile_size * 0.5)
        draw_line(top, top + Vector2(0.0, grid.grid_size.y * grid.tile_size), GRID_LINE_COLOR, 1.0)
    for y in range(grid.grid_size.y + 1):
        var left := to_local(grid.cell_center(Vector2i(0, y))) + Vector2(-grid.tile_size * 0.5, -grid.tile_size * 0.5)
        draw_line(left, left + Vector2(grid.grid_size.x * grid.tile_size, 0.0), GRID_LINE_COLOR, 1.0)


func _draw_danger() -> void:
    var font := ThemeDB.fallback_font
    for danger in _danger:
        var ticks := int(danger["ticks"])
        var fill := DANGER_CHARGE_COLOR if ticks <= 1 else DANGER_WARNING_COLOR
        for danger_cell: Vector2i in danger["cells"]:
            var rect := _cell_rect(danger_cell, 0.9)
            draw_rect(rect, fill)
            draw_rect(rect, fill.lightened(0.5), false, 2.0)
            var text_pos := to_local(grid.cell_center(danger_cell)) + Vector2(-grid.tile_size * 0.5, COUNTDOWN_FONT_SIZE * 0.35)
            draw_string(font, text_pos, str(ticks), HORIZONTAL_ALIGNMENT_CENTER, grid.tile_size, COUNTDOWN_FONT_SIZE, Color(1.0, 1.0, 1.0, 0.9))
        if danger.has("dest"):
            _draw_diamond(danger["dest"], fill.lightened(0.3))


func _draw_preview() -> void:
    if _preview.has("aim_cell"):
        draw_rect(_cell_rect(_preview["aim_cell"], 0.8), PREVIEW_OUTLINE_COLOR, false, 3.0)

    if _preview.has("dash_path"):
        var fill := PREVIEW_FILL_COLOR if bool(_preview.get("dash_legal", false)) else PREVIEW_BLOCKED_COLOR
        for path_cell: Vector2i in _preview["dash_path"]:
            draw_rect(_cell_rect(path_cell, 0.62), fill)
        if _preview.has("dash_landing"):
            draw_rect(_cell_rect(_preview["dash_landing"], 0.72), PREVIEW_OUTLINE_COLOR, false, 4.0)

    if _preview.has("smash_center"):
        var fill := PREVIEW_FILL_COLOR if bool(_preview.get("smash_legal", false)) else PREVIEW_BLOCKED_COLOR
        _draw_smash_area(_preview["smash_center"], fill, false)

    if _preview.has("smash_armed_center"):
        _draw_smash_area(_preview["smash_armed_center"], Color(PREVIEW_FILL_COLOR, 0.45), true)


func _draw_flashes() -> void:
    for flash in _flashes:
        var strength := float(flash["time_left"]) / FLASH_SEC
        var color := Color(flash["color"], flash["color"].a * strength)
        for flash_cell: Vector2i in flash["cells"]:
            if bool(flash["outline_only"]):
                draw_rect(_cell_rect(flash_cell, 0.85), color, false, 5.0)
            else:
                draw_rect(_cell_rect(flash_cell, 0.85), color)


func _draw_smash_area(center: Vector2i, fill: Color, armed: bool) -> void:
    for ox in range(-1, 2):
        for oy in range(-1, 2):
            draw_rect(_cell_rect(center + Vector2i(ox, oy), 0.8), fill)
    var outline_width := 5.0 if armed else 3.0
    draw_rect(_cell_rect(center, 0.8), PREVIEW_OUTLINE_COLOR, false, outline_width)


func _draw_diamond(target_cell: Vector2i, color: Color) -> void:
    var center := to_local(grid.cell_center(target_cell))
    var radius := grid.tile_size * 0.3
    var points := PackedVector2Array([
        center + Vector2(0.0, -radius),
        center + Vector2(radius, 0.0),
        center + Vector2(0.0, radius),
        center + Vector2(-radius, 0.0),
        center + Vector2(0.0, -radius),
    ])
    draw_polyline(points, color, 3.0)


func _cell_rect(target_cell: Vector2i, size_ratio: float) -> Rect2:
    var half := Vector2.ONE * grid.tile_size * 0.5 * size_ratio
    var center := to_local(grid.cell_center(target_cell))
    return Rect2(center - half, half * 2.0)
