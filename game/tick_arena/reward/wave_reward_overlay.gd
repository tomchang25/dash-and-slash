# wave_reward_overlay.gd
# Full-screen overlay that presents three generated wave reward choices.
class_name WaveRewardOverlay
extends Control

signal choice_selected(choice: WaveRewardChoice)

# -- State --

var _choices: Array[WaveRewardChoice] = []

# -- Node references --

@onready var _choice_buttons: Array[Button] = [%ChoiceButton1, %ChoiceButton2, %ChoiceButton3]
## Absent in the tick arena's overlay instance by design (Phase 6e freezes terrain mutation), so this
## looks the node up tolerantly instead of the strict %-shorthand, which would log a missing-node
## error every time this overlay enters the tree there.
# node-ref: allow - optional node absent by design in the tick arena instance; strict %-shorthand would error there
@onready var _terrain_mutation_note_label: Label = get_node_or_null(^"%TerrainMutationNoteLabel")

# == Lifecycle ==


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for i in _choice_buttons.size():
        _choice_buttons[i].pressed.connect(_on_choice_button_pressed.bind(i))
    hide_choices()

# == Common API ==


## Shows the rolled choices. terrain_mutation_kind (a WaveRewardChoiceController.TerrainMutationKind)
## adds a note describing the fixed terrain shift that will be applied once a reward is picked.
func show_choices(choices: Array[WaveRewardChoice], terrain_mutation_kind: int) -> void:
    _choices = choices.duplicate()
    for i in _choice_buttons.size():
        var button := _choice_buttons[i]
        if i < _choices.size():
            button.text = _format_choice(_choices[i])
            button.disabled = false
        else:
            button.text = "No reward"
            button.disabled = true
    if _terrain_mutation_note_label != null:
        _terrain_mutation_note_label.visible = true
        _terrain_mutation_note_label.text = _format_terrain_mutation_note(terrain_mutation_kind)
    visible = true


func hide_choices() -> void:
    visible = false

# == Signal handlers ==


func _on_choice_button_pressed(index: int) -> void:
    if index < 0 or index >= _choices.size():
        return
    choice_selected.emit(_choices[index])

# == Display ==


func _format_choice(choice: WaveRewardChoice) -> String:
    var lines := [choice.artifact.display_name, "", choice.description()]
    return "\n".join(lines)


func _format_terrain_mutation_note(terrain_mutation_kind: int) -> String:
    match terrain_mutation_kind:
        WaveRewardChoiceController.TerrainMutationKind.ADD_LAND:
            return "Terrain Shift: %d land tile(s) will be added" % WaveScaling.EXPAND_LAND_AMOUNT
        WaveRewardChoiceController.TerrainMutationKind.MOVE_LAND:
            return "Terrain Shift: %d land tile(s) will relocate" % WaveScaling.WAVE_TERRAIN_MUTATION_RELOCATE_COUNT
        WaveRewardChoiceController.TerrainMutationKind.REMOVE_LAND:
            return "Terrain Shift: %d land tile(s) will be removed" % WaveScaling.WAVE_TERRAIN_MUTATION_REMOVE_COUNT
        _:
            ToastManager.show_dev_error("WaveRewardOverlay: unknown terrain mutation kind %s" % terrain_mutation_kind)
            return ""
