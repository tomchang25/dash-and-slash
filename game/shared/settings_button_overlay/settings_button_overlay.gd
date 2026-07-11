# settings_button_overlay.gd
# Floating overlay button that opens the project settings menu.
extends CanvasLayer

# -- Node references --

@onready var _settings_button: Button = %SettingsButton

# == Lifecycle ==


func _ready() -> void:
    _settings_button.pressed.connect(_on_settings_pressed)

# == Signal handlers ==


func _on_settings_pressed() -> void:
    SettingsStore.toggle_overlay()
