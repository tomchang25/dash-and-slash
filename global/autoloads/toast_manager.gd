# toast_manager.gd
# Scene-independent passive notification overlay.
extends Node

# -- Constants --

const _WARNING_DURATION := 6.0
const _INFO_DURATION := 4.0
const _ERROR_DURATION := 8.0
const _FADE_DURATION := 0.4

const _MAX_VISIBLE_TOASTS := 5
const _TOAST_WIDTH := 400.0
const _TOAST_MARGIN := 16.0

const _WARNING_COLOR := Color(0.95, 0.75, 0.3, 1.0)
const _INFO_COLOR := Color(0.88, 0.88, 0.92, 1.0)
const _ERROR_COLOR := Color(0.95, 0.35, 0.3, 1.0)

const _BACKGROUND_COLOR := Color(0.15, 0.15, 0.18, 1.0)
const _BORDER_COLOR := Color(0.3, 0.3, 0.35, 1.0)

const _CHANNEL_WARNING := "warning"
const _CHANNEL_INFO := "info"
const _CHANNEL_ERROR := "error"
const _CHANNEL_DEV_ERROR := "dev_error"

# -- State --

var _canvas: CanvasLayer
var _stack: VBoxContainer
var _toasted_messages: Dictionary = { }

# == Lifecycle ==


func _ready() -> void:
    _ensure_overlay()

# == Common API ==


## Shows a user-visible warning message.
func show_warning(message: String) -> void:
    _push_toast(message, _WARNING_COLOR, _WARNING_DURATION, _CHANNEL_WARNING, false)


## Shows a user-visible error message.
func show_error(message: String) -> void:
    push_error(message)
    _push_toast(message, _ERROR_COLOR, _ERROR_DURATION, _CHANNEL_ERROR, false)


## Shows a debug/info message when the debug gate is enabled.
func show_info(message: String) -> void:
    if not Debug.enabled:
        return
    _push_toast(message, _INFO_COLOR, _INFO_DURATION, _CHANNEL_INFO, false)
    print("INFO: %s" % message)


## Logs a developer-facing error and shows it only when the debug gate is enabled.
func show_dev_error(message: String) -> void:
    push_error("[DEV] " + message)
    if not Debug.enabled:
        return
    _push_toast(message, _ERROR_COLOR, _ERROR_DURATION, _CHANNEL_DEV_ERROR, true)

# == Toast overlay ==


func _ensure_overlay() -> void:
    if is_instance_valid(_canvas) and is_instance_valid(_stack):
        return

    _canvas = CanvasLayer.new()
    _canvas.layer = 128
    # node-src: ephemeral - global toast overlay shell
    add_child(_canvas)

    _stack = VBoxContainer.new()
    _stack.set_anchors_preset(Control.PRESET_TOP_WIDE)
    _stack.offset_left = _TOAST_MARGIN
    _stack.offset_top = _TOAST_MARGIN
    _stack.offset_right = -_TOAST_MARGIN
    _stack.offset_bottom = _TOAST_MARGIN
    _stack.add_theme_constant_override("separation", 6)
    # node-src: ephemeral - global toast stack
    _canvas.add_child(_stack)


func _push_toast(message: String, color: Color, duration: float, channel: String, dedupe: bool) -> void:
    if message.is_empty():
        return

    if dedupe:
        var toast_key := "%s:%s" % [channel, message]
        if _toasted_messages.has(toast_key):
            return
        _toasted_messages[toast_key] = true

    _ensure_overlay()
    _trim_visible_toasts()

    var panel := PanelContainer.new()
    panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    panel.modulate.a = 0.0

    var stylebox := StyleBoxFlat.new()
    stylebox.bg_color = _BACKGROUND_COLOR
    stylebox.border_color = _BORDER_COLOR
    stylebox.set_border_width_all(1)
    stylebox.set_corner_radius_all(4)
    stylebox.content_margin_left = 12.0
    stylebox.content_margin_right = 12.0
    stylebox.content_margin_top = 8.0
    stylebox.content_margin_bottom = 8.0
    panel.add_theme_stylebox_override("panel", stylebox)

    var label := Label.new()
    label.text = message
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.custom_minimum_size = Vector2(_get_toast_width(), 0.0)
    label.add_theme_color_override("font_color", color)
    # node-src: ephemeral - toast label
    panel.add_child(label)

    # node-src: ephemeral - toast instance
    _stack.add_child(panel)

    var tween := create_tween()
    tween.set_parallel(false)
    tween.tween_property(panel, "modulate:a", 1.0, _FADE_DURATION)
    tween.tween_interval(duration)
    tween.tween_property(panel, "modulate:a", 0.0, _FADE_DURATION)
    tween.tween_callback(panel.queue_free)


func _trim_visible_toasts() -> void:
    while _stack.get_child_count() >= _MAX_VISIBLE_TOASTS:
        var oldest := _stack.get_child(0)
        _stack.remove_child(oldest)
        oldest.queue_free()


func _get_toast_width() -> float:
    var viewport_width := get_viewport().get_visible_rect().size.x
    return minf(_TOAST_WIDTH, maxf(160.0, viewport_width - (_TOAST_MARGIN * 2.0)))
