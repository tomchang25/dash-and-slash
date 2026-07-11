# enemy_status_bars.gd
# Floating combat status view for HP and dynamic shield guard indicators.
class_name EnemyStatusBars
extends Node2D

# -- Exports --

const GUARD_POINTS_PER_SHIELD := 4

@export var shield_scene: PackedScene
@export var shields_per_row: int = 4
@export var shield_icon_size: Vector2 = Vector2(16.0, 16.0)
@export var shield_gap: Vector2 = Vector2(2.0, 2.0)

# -- State --

var _current_guard := 0
var _max_guard := 0
var _shield_icons: Array[ShieldStatusIcon] = []

# -- Node references --

@onready var _hp_bar: ProgressBar = %HpBar
@onready var _shield_container: Node2D = %ShieldContainer

# == Lifecycle ==


func _ready() -> void:
    _apply_health(1.0, 1.0)
    _apply_guard()

# == Common API ==


func set_health(current: float, maximum: float) -> void:
    _apply_health(current, maximum)


func set_guard(current: int, maximum: int) -> void:
    _current_guard = current
    _max_guard = maximum
    _sync_shield_icons()
    _apply_guard()


func reset() -> void:
    _apply_health(_hp_bar.max_value, _hp_bar.max_value)
    _current_guard = _max_guard
    _apply_guard()


func set_enabled(value: bool) -> void:
    visible = value

# == View Application ==


func _apply_health(current: float, maximum: float) -> void:
    var safe_maximum := maxf(maximum, 1.0)
    _hp_bar.max_value = safe_maximum
    _hp_bar.value = clampf(current, 0.0, safe_maximum)


func _apply_guard() -> void:
    for shield_index in _shield_icons.size():
        var points := clampi(_current_guard - shield_index * GUARD_POINTS_PER_SHIELD, 0, GUARD_POINTS_PER_SHIELD)
        _shield_icons[shield_index].set_points(points)
        _shield_icons[shield_index].position = _shield_position(shield_index, _shield_icons.size())


func _sync_shield_icons() -> void:
    var shield_count := ceili(float(_max_guard) / float(GUARD_POINTS_PER_SHIELD))
    while _shield_icons.size() > shield_count:
        var icon := _shield_icons.pop_back()
        icon.queue_free()

    if shield_scene == null:
        return

    while _shield_icons.size() < shield_count:
        var icon := shield_scene.instantiate() as ShieldStatusIcon
        if icon == null:
            ToastManager.show_dev_error("EnemyStatusBars: shield_scene must instantiate ShieldStatusIcon")
            return
        _shield_icons.append(icon)
        _shield_container.add_child(icon)


func _shield_position(shield_index: int, total_shields: int) -> Vector2:
    var safe_shields_per_row := maxi(shields_per_row, 1)
    var row := floori(float(shield_index) / float(safe_shields_per_row))
    var column := shield_index % safe_shields_per_row
    var row_count := _shield_count_for_row(row, total_shields)
    var row_width := row_count * shield_icon_size.x + maxf(0.0, float(row_count - 1)) * shield_gap.x
    var x := column * (shield_icon_size.x + shield_gap.x) - row_width * 0.5
    var y := -float(row + 1) * (shield_icon_size.y + shield_gap.y)
    return Vector2(x, y)


func _shield_count_for_row(row: int, total_shields: int) -> int:
    var safe_shields_per_row := maxi(shields_per_row, 1)
    var remaining := total_shields - row * safe_shields_per_row
    return clampi(remaining, 0, safe_shields_per_row)
