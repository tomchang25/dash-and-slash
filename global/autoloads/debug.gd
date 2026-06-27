# debug.gd
# Unified debug gate: enabled only in debug-capable builds when the user preference is on.
extends Node

signal toggled(is_enabled: bool)

var enabled: bool = false

# == Lifecycle ================================================================


func _ready() -> void:
    SettingsStore.debug_mode_changed.connect(_on_source_changed)
    _refresh()

# == Signal handlers ===========================================================


func _on_source_changed(_value: bool) -> void:
    _refresh()

# == Common API ================================================================


## Sets and persists the user-facing debug preference.
func set_debug_mode(value: bool) -> void:
    SettingsStore.debug_mode = value
    SettingsStore.save_settings()

# == Internals =================================================================


func _refresh() -> void:
    var new_value := OS.is_debug_build() and SettingsStore.debug_mode
    if enabled == new_value:
        return
    enabled = new_value
    toggled.emit(enabled)
