# debug_panel.gd
# Reusable debug-only action panel: a bounded, scrollable, sectioned button list.
# Self-gates visibility from Debug.enabled and reacts to Debug.toggled (dev/standards/debug_standard.md §4a/§5).
# Carries no game-specific logic: the owning scene registers buttons via add_action().
class_name DebugPanel
extends PanelContainer

# -- Constants --

const ACTIVE_ACTION_COLOR := Color(0.45, 0.95, 0.55, 1.0)

# -- State --

## Section label -> the VBoxContainer holding that section's action buttons.
var _sections: Dictionary = { }

# -- Node references --

@onready var _title_label: Label = %DebugPanelTitle
@onready var _section_list: VBoxContainer = %DebugPanelSectionList

# == Lifecycle ================================================================


func _ready() -> void:
    visible = Debug.enabled
    Debug.toggled.connect(_on_debug_toggled)

# == Common API ================================================================


## Registers one debug action button under the given section, creating the section's header and
## button list on first use. An empty section groups the button under no header, preserving the
## original flat add_action(label, callback) call shape for existing callers.
## The callback only runs while Debug.enabled is true, so a hidden-but-still-in-tree panel can never fire an action.
## Returns the created Button so callers may keep a reference (e.g. to update its text or active state).
func add_action(label: String, callback: Callable, section: String = "") -> Button:
    var button := Button.new()
    button.text = label
    button.pressed.connect(_on_action_pressed.bind(callback))
    var action_list := _get_or_create_section(section)
    # node-src: debug
    action_list.add_child(button)
    return button


## Sets the panel title (defaults to "DEBUG").
func set_title(text: String) -> void:
    _title_label.text = text


## Removes every registered action button and section.
func clear_actions() -> void:
    for child in _section_list.get_children():
        child.queue_free()
    _sections.clear()


## Generic active/inactive styling for a registered action button, so callers such as tick_arena.gd
## can reflect mutually-exclusive or toggled debug state without encoding style details themselves.
func set_action_active(button: Button, active: bool) -> void:
    if active:
        button.add_theme_color_override("font_color", ACTIVE_ACTION_COLOR)
    else:
        button.remove_theme_color_override("font_color")

# == Signal handlers ===========================================================


func _on_debug_toggled(is_enabled: bool) -> void:
    visible = is_enabled


func _on_action_pressed(callback: Callable) -> void:
    if not Debug.enabled:
        return
    if callback.is_valid():
        callback.call()

# == Sections ==================================================================


## Returns the button list for the given section, creating the section (and its header label, when
## the section is non-empty) the first time it is requested. Section identity/count is data-driven
## by whatever the owning scene registers, so both are built at runtime rather than pre-placed.
func _get_or_create_section(section: String) -> VBoxContainer:
    if _sections.has(section):
        return _sections[section]
    var wrapper := VBoxContainer.new()
    wrapper.add_theme_constant_override("separation", 4)
    if not section.is_empty():
        var header := Label.new()
        header.text = section
        header.theme_type_variation = "MicroLabel"
        # node-src: debug
        wrapper.add_child(header)
    var action_list := VBoxContainer.new()
    action_list.add_theme_constant_override("separation", 4)
    # node-src: debug
    wrapper.add_child(action_list)
    # node-src: debug
    _section_list.add_child(wrapper)
    _sections[section] = action_list
    return action_list
