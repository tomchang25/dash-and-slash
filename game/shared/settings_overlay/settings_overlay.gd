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
@onready var _dash_direction_option: OptionButton = %DashDirectionOption
@onready var _confirm_smash_cancel_check: CheckBox = %ConfirmSmashCancelCheck
@onready var _auto_attack_on_move_check: CheckBox = %AutoAttackOnMoveCheck
@onready var _debug_check: CheckBox = %DebugCheck
@onready var _close_btn: Button = %CloseButton
@onready var _main_menu_btn: Button = %MainMenuButton

# == Lifecycle ================================================================


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS

    _populate_dash_direction_options()
    _master_slider.value_changed.connect(_on_master_changed)
    _sfx_slider.value_changed.connect(_on_sfx_changed)
    _music_slider.value_changed.connect(_on_music_changed)
    _fullscreen_check.toggled.connect(_on_fullscreen_toggled)
    _dash_direction_option.item_selected.connect(_on_dash_direction_selected)
    _confirm_smash_cancel_check.toggled.connect(_on_confirm_smash_cancel_toggled)
    _auto_attack_on_move_check.toggled.connect(_on_auto_attack_on_move_toggled)
    _debug_check.toggled.connect(_on_debug_toggled)
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


func _on_dash_direction_selected(index: int) -> void:
    var metadata: Variant = _dash_direction_option.get_item_metadata(index)
    if metadata is String:
        SettingsStore.set_dash_direction_mode(str(metadata))
        SettingsStore.save_settings()


func _on_confirm_smash_cancel_toggled(pressed: bool) -> void:
    SettingsStore.confirm_smash_cancel = pressed
    SettingsStore.save_settings()


func _on_auto_attack_on_move_toggled(pressed: bool) -> void:
    SettingsStore.auto_attack_on_move = pressed
    SettingsStore.save_settings()


func _on_debug_toggled(pressed: bool) -> void:
    Debug.set_debug_mode(pressed)


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
    _select_dash_direction_option()
    _confirm_smash_cancel_check.set_pressed_no_signal(SettingsStore.confirm_smash_cancel)
    _auto_attack_on_move_check.set_pressed_no_signal(SettingsStore.auto_attack_on_move)
    _debug_check.set_pressed_no_signal(SettingsStore.debug_mode)


func _populate_dash_direction_options() -> void:
    _dash_direction_option.clear()
    _dash_direction_option.add_item("Mouse Aim")
    _dash_direction_option.set_item_metadata(0, SettingsStore.DASH_DIRECTION_MODE_MOUSE)
    _dash_direction_option.add_item("Movement Input")
    _dash_direction_option.set_item_metadata(1, SettingsStore.DASH_DIRECTION_MODE_MOVEMENT)


func _select_dash_direction_option() -> void:
    for item_index in range(_dash_direction_option.get_item_count()):
        if _dash_direction_option.get_item_metadata(item_index) == SettingsStore.dash_direction_mode:
            _dash_direction_option.select(item_index)
            return
    _dash_direction_option.select(0)
