# tick_grid_view.gd
# Debug preview overlay for the tick arena. Terrain, water, grid lines, arena bounds, and the enemy
# danger telegraph fills are drawn by the production GridTerrainView; this overlay only keeps the
# prototype affordances that have no production equivalent yet: player-side previews in a distinct
# cyan palette, per-attack tick countdowns and charge destinations, and deny/detonation/swing flashes.
class_name TickGridView
extends Node2D

# -- Constants --

# Danger palette matches the production telegraph colors (GridTerrainView) so the countdown badges and
# charge-destination markers read as the same enemy-danger phase the production fills paint underneath.
const DANGER_WARNING_COLOR := Color(1.0, 0.4, 0.2, 0.25)
const DANGER_CHARGE_COLOR := Color(1.0, 0.55, 0.0, 0.5)
const DANGER_ACTIVE_COLOR := Color(0.95, 0.1, 0.0, 0.75)
# Player-side previews stay in a cyan family, strictly separated from the enemy danger palette.
const PREVIEW_FILL_COLOR := Color(0.3, 0.9, 1.0, 0.32)
const PREVIEW_OUTLINE_COLOR := Color(0.3, 0.9, 1.0, 0.95)
const PREVIEW_BLOCKED_COLOR := Color(0.55, 0.65, 0.75, 0.15)
const SWING_FLASH_COLOR := Color(0.5, 0.95, 1.0, 0.55)
const DENY_FLASH_COLOR := Color(1.0, 1.0, 1.0, 0.85)
const GHOST_COLOR := Color(0.93, 0.96, 1.0, 0.4)
const GHOST_RADIUS := 40.0
const OUTCOME_LABEL_COLORS: Array[Color] = [
    Color(0.55, 0.85, 0.95, 0.75),
    Color(0.3, 0.95, 1.0, 1.0),
    Color(1.0, 1.0, 1.0, 1.0),
]
const OUTCOME_FONT_SIZE := 30
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
        ToastManager.show_dev_error("TickGridView: grid export is not wired.")
        return
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
    _flashes.append(
        {
            "cells": cells.duplicate(),
            "color": color,
            "outline_only": outline_only,
            "time_left": FLASH_SEC,
        },
    )
    queue_redraw()


## Draws the debug tick countdown over each telegraphed cell plus the charge-destination marker; the
## danger fill itself is painted by the production GridTerrainView from GridArena telegraph state.
func _draw_danger() -> void:
    var font := ThemeDB.fallback_font
    for danger in _danger:
        var ticks := int(danger["ticks"])
        var fill := DANGER_CHARGE_COLOR if ticks <= 1 else DANGER_WARNING_COLOR
        for danger_cell: Vector2i in danger["cells"]:
            var text_pos := to_local(grid.cell_center(danger_cell)) + Vector2(-grid.tile_size * 0.5, COUNTDOWN_FONT_SIZE * 0.35)
            draw_string(font, text_pos, str(ticks), HORIZONTAL_ALIGNMENT_CENTER, grid.tile_size, COUNTDOWN_FONT_SIZE, Color(1.0, 1.0, 1.0, 0.9))
        if danger.has("dest"):
            _draw_diamond(danger["dest"], fill.lightened(0.3))


func _draw_preview() -> void:
    if _preview.has("aim_cell"):
        draw_rect(_cell_rect(_preview["aim_cell"], 0.8), PREVIEW_OUTLINE_COLOR, false, 4.0)

    if _preview.has("dash_path"):
        var fill := PREVIEW_FILL_COLOR if bool(_preview.get("dash_legal", false)) else PREVIEW_BLOCKED_COLOR
        for path_cell: Vector2i in _preview["dash_path"]:
            draw_rect(_cell_rect(path_cell, 0.7), fill)
        if _preview.has("dash_landing"):
            draw_rect(_cell_rect(_preview["dash_landing"], 0.72), PREVIEW_OUTLINE_COLOR, false, 5.0)

    if _preview.has("smash_center"):
        var fill := PREVIEW_FILL_COLOR if bool(_preview.get("smash_legal", false)) else PREVIEW_BLOCKED_COLOR
        _draw_smash_area(_preview["smash_center"], fill, false)

    if _preview.has("smash_armed_center"):
        _draw_smash_area(_preview["smash_armed_center"], Color(PREVIEW_FILL_COLOR, 0.45), true)

    if _preview.has("ghost_cell"):
        _draw_ghost(_preview["ghost_cell"])

    if _preview.has("outcomes"):
        _draw_outcomes(_preview["outcomes"])


func _draw_flashes() -> void:
    for flash in _flashes:
        var strength := float(flash["time_left"]) / FLASH_SEC
        var color := Color(flash["color"], flash["color"].a * strength)
        for flash_cell: Vector2i in flash["cells"]:
            if bool(flash["outline_only"]):
                draw_rect(_cell_rect(flash_cell, 0.85), color, false, 5.0)
            else:
                draw_rect(_cell_rect(flash_cell, 0.85), color)


## Draws a translucent copy of the player body at the committed landing cell.
func _draw_ghost(target_cell: Vector2i) -> void:
    var center := to_local(grid.cell_center(target_cell))
    draw_circle(center, GHOST_RADIUS, GHOST_COLOR)
    draw_arc(center, GHOST_RADIUS + 4.0, 0.0, TAU, 32, PREVIEW_OUTLINE_COLOR, 2.0)


## Draws each predicted-hit badge: a bracket on the victim's cell plus an angle/result label above it.
func _draw_outcomes(outcomes: Array) -> void:
    var font := ThemeDB.fallback_font
    for outcome: Dictionary in outcomes:
        var target_cell: Vector2i = outcome["cell"]
        var tier: int = clampi(outcome["tier"], 0, OUTCOME_LABEL_COLORS.size() - 1)
        var color := OUTCOME_LABEL_COLORS[tier]
        draw_rect(_cell_rect(target_cell, 0.86), color, false, 2.0 + float(tier) * 1.5)
        var center := to_local(grid.cell_center(target_cell))
        var text_pos := center + Vector2(-grid.tile_size, -grid.tile_size * 0.62)
        draw_string(font, text_pos, String(outcome["label"]), HORIZONTAL_ALIGNMENT_CENTER, grid.tile_size * 2.0, OUTCOME_FONT_SIZE, color)


func _draw_smash_area(center: Vector2i, fill: Color, armed: bool) -> void:
    for ox in range(-1, 2):
        for oy in range(-1, 2):
            draw_rect(_cell_rect(center + Vector2i(ox, oy), 0.8), fill)
    var outline_width := 5.0 if armed else 3.0
    draw_rect(_cell_rect(center, 0.8), PREVIEW_OUTLINE_COLOR, false, outline_width)


func _draw_diamond(target_cell: Vector2i, color: Color) -> void:
    var center := to_local(grid.cell_center(target_cell))
    var radius := grid.tile_size * 0.3
    var points := PackedVector2Array(
        [
            center + Vector2(0.0, -radius),
            center + Vector2(radius, 0.0),
            center + Vector2(0.0, radius),
            center + Vector2(-radius, 0.0),
            center + Vector2(0.0, -radius),
        ],
    )
    draw_polyline(points, color, 3.0)


func _cell_rect(target_cell: Vector2i, size_ratio: float) -> Rect2:
    var half := Vector2.ONE * grid.tile_size * 0.5 * size_ratio
    var center := to_local(grid.cell_center(target_cell))
    return Rect2(center - half, half * 2.0)
