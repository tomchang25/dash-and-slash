# tick_arena_hud.gd
# Read-only tick-arena HUD presenter: renders a plain-data state snapshot built by TickArena into
# four stable zones: top-left player combat state, top-right settings, bottom-left build access, and
# a left/mid bottom run-context strip that deliberately avoids the bottom-right debug panel. Never
# mutates player HP, cooldowns, Speed meter, run build artifacts, wave state, debug toggles, or
# settings values; it only emits build_pressed/settings_pressed so the arena root can route those
# presses to their real owners.
class_name TickArenaHud
extends Control

signal build_pressed
signal settings_pressed

# -- Constants --

const ArtifactStripItemScene: PackedScene = preload("res://game/tick_arena/hud/artifact_strip_item.tscn")

const READY_TEXT := "READY"
const COOLDOWN_TEXT := "%dT"
const READY_TEXT_COLOR := Color(0.57, 0.98, 0.86, 1.0)
const COOLDOWN_TEXT_COLOR := Color(1.0, 0.76, 0.42, 1.0)

# -- Node references --

@onready var _hp_bar: HudResourceBar = %HPResourceBar
@onready var _speed_bar: HudResourceBar = %SpeedResourceBar
@onready var _dash_chip: Control = %DashChip
@onready var _dash_cooldown_label: Label = %DashCooldownLabel
@onready var _smash_chip: Control = %SmashChip
@onready var _smash_cooldown_label: Label = %SmashCooldownLabel
@onready var _class_label: Label = %ClassLabel
@onready var _tick_count_label: Label = %TickCountLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _artifact_strip: HBoxContainer = %ArtifactStrip
@onready var _artifact_empty_label: Label = %ArtifactEmptyLabel
@onready var _build_button: Button = %BuildButton
@onready var _settings_button: Button = %SettingsButton

# == Lifecycle ==


func _ready() -> void:
    _build_button.pressed.connect(_on_build_button_pressed)
    _settings_button.pressed.connect(_on_settings_button_pressed)

# == Signal handlers ==


func _on_build_button_pressed() -> void:
    build_pressed.emit()


func _on_settings_button_pressed() -> void:
    settings_pressed.emit()

# == Common API ==


## Renders the full HUD from a plain-data snapshot the arena root builds every refresh. Expected
## keys: hp, max_hp, class_name, mobility_id, dash_cooldown, smash_cooldown, speed_meter, speed_meter_max,
## speed_meter_ready, tick_count, wave_display_text, artifact_rows
## (BuildInspectionFormatter.build_artifact_rows() shape).
func render(snapshot: Dictionary) -> void:
    _apply_combat_state(snapshot)
    _apply_run_context(snapshot)

# == Combat State ==


func _apply_combat_state(snapshot: Dictionary) -> void:
    var hp: float = snapshot.get("hp", 0.0)
    var max_hp: float = snapshot.get("max_hp", 1.0)
    _hp_bar.render_value(hp, max_hp)

    var speed_meter: int = snapshot.get("speed_meter", 0)
    var speed_meter_max: int = snapshot.get("speed_meter_max", 100)
    var speed_ready: bool = snapshot.get("speed_meter_ready", false)
    _speed_bar.render_value(speed_meter, speed_meter_max, speed_ready)

    _apply_mobility_chip(snapshot)
    _class_label.text = String(snapshot.get("class_name", "Unknown"))
    _tick_count_label.text = "Tick %d" % int(snapshot.get("tick_count", 0))


func _apply_mobility_chip(snapshot: Dictionary) -> void:
    var mobility_id: StringName = snapshot.get("mobility_id", CharacterClassData.MOBILITY_DASH)
    _dash_chip.visible = mobility_id == CharacterClassData.MOBILITY_DASH
    _smash_chip.visible = mobility_id == CharacterClassData.MOBILITY_SMASH
    if mobility_id == CharacterClassData.MOBILITY_DASH:
        _set_cooldown_label(_dash_cooldown_label, "Dash", int(snapshot.get("dash_cooldown", 0)))
    elif mobility_id == CharacterClassData.MOBILITY_SMASH:
        _set_cooldown_label(_smash_cooldown_label, "Smash", int(snapshot.get("smash_cooldown", 0)))
    else:
        ToastManager.show_dev_error("TickArenaHud: unknown class Mobility %s" % mobility_id)


func _set_cooldown_label(target_label: Label, label_text: String, cooldown: int) -> void:
    if cooldown <= 0:
        target_label.text = "%s %s" % [label_text, READY_TEXT]
        target_label.add_theme_color_override("font_color", READY_TEXT_COLOR)
        return
    target_label.text = "%s %s" % [label_text, COOLDOWN_TEXT % cooldown]
    target_label.add_theme_color_override("font_color", COOLDOWN_TEXT_COLOR)

# == Run Context ==


func _apply_run_context(snapshot: Dictionary) -> void:
    _wave_label.text = String(snapshot.get("wave_display_text", ""))
    _rebuild_artifact_strip(snapshot.get("artifact_rows", []))


## Rebuilds the compact artifact strip from BuildInspectionFormatter.build_artifact_rows() data
## an empty run keeps an unobtrusive empty-state label instead of empty icon cells.
func _rebuild_artifact_strip(rows: Array) -> void:
    _clear_children(_artifact_strip)
    _artifact_empty_label.visible = rows.is_empty()
    for row_data in rows:
        var item: ArtifactStripItem = ArtifactStripItemScene.instantiate()
        item.setup(row_data)
        _artifact_strip.add_child(item)


## Frees every current child immediately rather than via queue_free(), so a rebuild never renders
## both the outgoing and incoming cells in the same frame.
func _clear_children(container: Node) -> void:
    for child in container.get_children():
        child.free()
