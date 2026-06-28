# main_menu_scene.gd
# Main menu with Play, Settings, and Quit actions.
extends Control

# -- Node references ----------------------------------------------------------

@onready var _play_btn: Button = %PlayButton
@onready var _settings_btn: Button = %SettingsButton
@onready var _quit_btn: Button = %QuitButton

# == Lifecycle ================================================================


func _ready() -> void:
    _play_btn.pressed.connect(_on_play_pressed)
    _settings_btn.pressed.connect(_on_settings_pressed)
    _quit_btn.pressed.connect(_on_quit_pressed)

# == Signal handlers ===========================================================


func _on_play_pressed() -> void:
    SceneRouter.go_to_arena()


func _on_settings_pressed() -> void:
    SettingsStore.toggle_overlay()


func _on_quit_pressed() -> void:
    get_tree().quit()
