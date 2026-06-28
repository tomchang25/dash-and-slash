# settings_overlay.gd
# Modal CanvasLayer for project-wide audio, display, and debug settings.
extends CanvasLayer

signal closed

const MAIN_MENU_PATH := "res://game/meta/main_menu/main_menu_scene.tscn"

# -- Node references ----------------------------------------------------------

@onready var _master_slider: HSlider = %MasterSlider
@onready var _master_value_label: Label = %MasterValueLabel
@onready var _sfx_slider: HSlider = %SfxSlider
@onready var _sfx_value_label: Label = %SfxValueLabel
@onready var _music_slider: HSlider = %MusicSlider
@onready var _music_value_label: Label = %MusicValueLabel
@onready var _fullscreen_check: CheckBox = %FullscreenCheck
@onready var _debug_check: CheckBox = %DebugCheck
@onready var _skip_tutorial_check: CheckBox = %SkipTutorialCheck
@onready var _close_btn: Button = %CloseButton
@onready var _main_menu_btn: Button = %MainMenuButton

# == Lifecycle ================================================================


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

    _master_slider.value_changed.connect(_on_master_changed)
    _sfx_slider.value_changed.connect(_on_sfx_changed)
    _music_slider.value_changed.connect(_on_music_changed)
    _fullscreen_check.toggled.connect(_on_fullscreen_toggled)
    _debug_check.toggled.connect(_on_debug_toggled)
    _skip_tutorial_check.toggled.connect(_on_skip_tutorial_toggled)
    _close_btn.pressed.connect(_on_close_pressed)
    _main_menu_btn.pressed.connect(_on_main_menu_pressed)

    _main_menu_btn.visible = get_tree().current_scene == null or get_tree().current_scene.scene_file_path != MAIN_MENU_PATH
    _apply()

# == Signal handlers ===========================================================


func _on_master_changed(value: float) -> void:
    SettingsStore.master_volume = value / 100.0
    _master_value_label.text = "%d%%" % int(value)
    SettingsStore.apply_audio()
    SettingsStore.save_settings()


func _on_sfx_changed(value: float) -> void:
    SettingsStore.sfx_volume = value / 100.0
    _sfx_value_label.text = "%d%%" % int(value)
    SettingsStore.apply_audio()
    SettingsStore.save_settings()


func _on_music_changed(value: float) -> void:
    SettingsStore.music_volume = value / 100.0
    _music_value_label.text = "%d%%" % int(value)
    SettingsStore.apply_audio()
    SettingsStore.save_settings()


func _on_fullscreen_toggled(pressed: bool) -> void:
    SettingsStore.fullscreen = pressed
    SettingsStore.apply_display()
    SettingsStore.save_settings()


func _on_debug_toggled(pressed: bool) -> void:
    Debug.set_debug_mode(pressed)


func _on_skip_tutorial_toggled(pressed: bool) -> void:
    SettingsStore.tutorial_skip_all = pressed
    SettingsStore.save_settings()


func _on_close_pressed() -> void:
    closed.emit()


func _on_main_menu_pressed() -> void:
    closed.emit()
    SceneRouter.go_to_main_menu()

# == View =====================================================================


func _apply() -> void:
    _master_slider.set_value_no_signal(SettingsStore.master_volume * 100.0)
    _master_value_label.text = "%d%%" % int(SettingsStore.master_volume * 100.0)
    _sfx_slider.set_value_no_signal(SettingsStore.sfx_volume * 100.0)
    _sfx_value_label.text = "%d%%" % int(SettingsStore.sfx_volume * 100.0)
    _music_slider.set_value_no_signal(SettingsStore.music_volume * 100.0)
    _music_value_label.text = "%d%%" % int(SettingsStore.music_volume * 100.0)
    _fullscreen_check.set_pressed_no_signal(SettingsStore.fullscreen)
    _debug_check.set_pressed_no_signal(SettingsStore.debug_mode)
    _skip_tutorial_check.set_pressed_no_signal(SettingsStore.tutorial_skip_all)
