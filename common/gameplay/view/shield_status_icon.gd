# shield_status_icon.gd
# View widget that displays one guard shield split into four visible quadrants.
class_name ShieldStatusIcon
extends Node2D

const MAX_POINTS := 4

# -- Node references --

@onready var _quarters: Array[CanvasItem] = [%Quarter1, %Quarter2, %Quarter3, %Quarter4]

# == Lifecycle ==


func _ready() -> void:
    set_points(MAX_POINTS)

# == Common API ==


func set_points(points: int) -> void:
    var visible_quarters := clampi(points, 0, MAX_POINTS)
    for quarter_index in MAX_POINTS:
        _quarters[quarter_index].visible = quarter_index < visible_quarters


func reset() -> void:
    set_points(MAX_POINTS)
