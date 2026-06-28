# settings_store.gd
# Project-wide persistent settings and settings-overlay lifecycle owner.
extends Node

signal debug_mode_changed(value: bool)
signal settings_changed

const SETTINGS_PATH := "user://settings.json"
const SettingsOverlayScene := preload("res://game/shared/settings_overlay/settings_overlay.tscn")

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0
var fullscreen: bool = false
var debug_mode: bool = false:
    set(value):
        if debug_mode == value:
            return
        debug_mode = value
        debug_mode_changed.emit(value)
        settings_changed.emit()

var tutorial_skip_all: bool = false
var _overlay_instance: CanvasLayer = null
var _was_paused := false

# == Lifecycle ================================================================


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    load_settings()
    apply_audio()
    apply_display()


func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_settings"):
        toggle_overlay()
        get_viewport().set_input_as_handled()

# == Common API ================================================================


## Writes project-wide settings to user://settings.json.
func save_settings() -> void:
    var data := {
        "master_volume": master_volume,
        "sfx_volume": sfx_volume,
        "music_volume": music_volume,
        "fullscreen": fullscreen,
        "debug_mode": debug_mode,
        "tutorial_skip_all": tutorial_skip_all,
    }
    var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
    if file == null:
        push_error("SettingsStore: cannot write %s" % SETTINGS_PATH)
        return
    file.store_string(JSON.stringify(data, "\t"))


## Reads project-wide settings from user://settings.json when present.
func load_settings() -> void:
    if not FileAccess.file_exists(SETTINGS_PATH):
        return
    var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
    if file == null:
        push_error("SettingsStore: cannot read %s" % SETTINGS_PATH)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed == null or not parsed is Dictionary:
        push_error("SettingsStore: invalid settings data")
        return
    var data: Dictionary = parsed
    master_volume = float(data.get("master_volume", master_volume))
    sfx_volume = float(data.get("sfx_volume", sfx_volume))
    music_volume = float(data.get("music_volume", music_volume))
    fullscreen = bool(data.get("fullscreen", fullscreen))
    debug_mode = bool(data.get("debug_mode", debug_mode))
    tutorial_skip_all = bool(data.get("tutorial_skip_all", tutorial_skip_all))


## Applies persisted linear volume values to the project audio buses.
func apply_audio() -> void:
    _set_bus_volume("Master", master_volume)
    _set_bus_volume("SFX", sfx_volume)
    _set_bus_volume("Music", music_volume)


## Applies persisted display settings.
func apply_display() -> void:
    if fullscreen:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
    else:
        DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## Opens the settings overlay when closed, or closes it when open.
func toggle_overlay() -> void:
    if _overlay_instance != null:
        _close_overlay()
    else:
        _open_overlay()

# == Overlay lifecycle =========================================================


func _open_overlay() -> void:
    if _overlay_instance != null:
        return
    _was_paused = get_tree().paused
    _overlay_instance = SettingsOverlayScene.instantiate()
    _overlay_instance.closed.connect(_close_overlay)
    get_tree().root.add_child(_overlay_instance)
    get_tree().paused = true


func _close_overlay() -> void:
    if _overlay_instance == null:
        return
    _overlay_instance.queue_free()
    _overlay_instance = null
    get_tree().paused = _was_paused

# == Internals =================================================================


func _set_bus_volume(bus_name: String, linear: float) -> void:
    var idx := AudioServer.get_bus_index(bus_name)
    if idx == -1:
        push_warning("SettingsStore: bus '%s' not found" % bus_name)
        return
    AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0, 1.0)))
    AudioServer.set_bus_mute(idx, linear <= 0.0)
