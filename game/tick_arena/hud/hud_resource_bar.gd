# hud_resource_bar.gd
# Reusable layered HUD resource bar with value text, delayed trail feedback, and ready/low states.
class_name HudResourceBar
extends VBoxContainer

enum BarMode {
    THREE_LAYER,
    TWO_LAYER,
}

# -- Exports --

@export var mode := BarMode.THREE_LAYER
@export var title_text := "HP"
@export var ready_text := "READY"
@export var fill_color := Color(0.86, 0.1, 0.12, 1.0)
@export var trail_color := Color(1.0, 0.55, 0.18, 1.0)
@export var low_fill_color := Color(1.0, 0.05, 0.05, 1.0)
@export var ready_color := Color(0.32, 0.88, 1.0, 1.0)
@export var low_threshold := 0.28
@export var fill_tween_duration := 0.15
@export var trail_delay := 0.24
@export var trail_tween_duration := 0.36
@export var heal_trail_tween_duration := 0.14

# -- State --

var _current_value := 0.0
var _maximum_value := 1.0
var _fill_value := 0.0
var _trail_value := 0.0
var _shows_ready_state := false
var _has_value := false

# -- Timer / tween handles --

var _fill_tween: Tween
var _trail_tween: Tween

# -- Node references --

@onready var _accent_swatch: ColorRect = %AccentSwatch
@onready var _title_label: Label = %TitleLabel
@onready var _value_label: Label = %ValueLabel
@onready var _ready_label: Label = %ReadyLabel
@onready var _bar_track: Control = %BarTrack
@onready var _trail_layer: ColorRect = %TrailLayer
@onready var _fill_layer: ColorRect = %FillLayer
@onready var _ready_overlay: ColorRect = %ReadyOverlay

# == Lifecycle ==


func _ready() -> void:
    _bar_track.resized.connect(_on_bar_track_resized)
    _apply_static_view()
    _sync_layers()


func _exit_tree() -> void:
    _stop_tweens()

# == Signal handlers ==


func _on_bar_track_resized() -> void:
    _sync_layers()

# == Common API ==


## Sets the displayed resource value. The widget owns only bar animation state; gameplay state stays
## with the caller that supplies the current snapshot.
func render_value(current: float, maximum: float, shows_ready_state := false, sync_immediately := false) -> void:
    var previous := _current_value
    _maximum_value = maxf(maximum, 1.0)
    _current_value = clampf(current, 0.0, _maximum_value)
    _shows_ready_state = shows_ready_state
    if sync_immediately or not _has_value:
        _has_value = true
        _force_sync()
        return
    _animate_from(previous)
    _apply_text_and_state()


## Immediately synchronizes every layer with the current value, used by parent scenes after resets.
func force_sync(current: float, maximum: float, shows_ready_state := false) -> void:
    render_value(current, maximum, shows_ready_state, true)

# == View ==


func _apply_static_view() -> void:
    _title_label.text = title_text
    _ready_label.text = ready_text
    _accent_swatch.color = fill_color
    _fill_layer.color = fill_color
    _trail_layer.color = trail_color
    _ready_label.add_theme_color_override("font_color", ready_color)
    _ready_overlay.color = Color(ready_color.r, ready_color.g, ready_color.b, 0.22)
    _apply_text_and_state()


func _apply_text_and_state() -> void:
    _value_label.text = "%d / %d" % [int(roundf(_current_value)), int(roundf(_maximum_value))]
    var ratio := _current_value / _maximum_value
    var low := mode == BarMode.THREE_LAYER and ratio <= low_threshold
    _fill_layer.color = low_fill_color if low else fill_color
    _accent_swatch.color = _fill_layer.color
    _ready_label.visible = _shows_ready_state
    _ready_overlay.visible = _shows_ready_state
    _trail_layer.visible = mode == BarMode.THREE_LAYER


func _animate_from(previous: float) -> void:
    if mode == BarMode.THREE_LAYER:
        _set_fill_value(_current_value)
        _animate_trail(previous)
    elif mode == BarMode.TWO_LAYER:
        _trail_value = _current_value
        _tween_fill_to(_current_value, fill_tween_duration)
    else:
        ToastManager.show_dev_error("HudResourceBar: unknown bar mode %d" % mode)
        _force_sync()


func _animate_trail(previous: float) -> void:
    _stop_trail_tween()
    if _current_value < previous:
        _trail_value = maxf(_trail_value, previous)
        _sync_layers()
        _trail_tween = create_tween()
        _trail_tween.tween_interval(maxf(trail_delay, 0.0))
        _trail_tween.tween_method(_set_trail_value, _trail_value, _current_value, maxf(trail_tween_duration, 0.0))
        return
    _trail_tween = create_tween()
    _trail_tween.tween_method(_set_trail_value, _trail_value, _current_value, maxf(heal_trail_tween_duration, 0.0))


func _force_sync() -> void:
    _stop_tweens()
    _fill_value = _current_value
    _trail_value = _current_value
    _apply_text_and_state()
    _sync_layers()


func _tween_fill_to(target: float, duration: float) -> void:
    if _fill_tween != null and _fill_tween.is_valid():
        _fill_tween.kill()
    _fill_tween = create_tween()
    _fill_tween.set_ease(Tween.EASE_OUT)
    _fill_tween.set_trans(Tween.TRANS_QUART)
    _fill_tween.tween_method(_set_fill_value, _fill_value, target, maxf(duration, 0.0))


func _set_fill_value(value: float) -> void:
    _fill_value = clampf(value, 0.0, _maximum_value)
    _sync_layers()


func _set_trail_value(value: float) -> void:
    _trail_value = clampf(value, 0.0, _maximum_value)
    _sync_layers()


func _sync_layers() -> void:
    if not is_node_ready():
        return
    _apply_text_and_state()
    _fill_layer.anchor_right = _fill_value / _maximum_value
    _trail_layer.anchor_right = _trail_value / _maximum_value


func _stop_tweens() -> void:
    if _fill_tween != null and _fill_tween.is_valid():
        _fill_tween.kill()
    _fill_tween = null
    _stop_trail_tween()


func _stop_trail_tween() -> void:
    if _trail_tween != null and _trail_tween.is_valid():
        _trail_tween.kill()
    _trail_tween = null
