# wave_reward_overlay.gd
# Full-screen overlay that presents a wave reward offer (multiple enabled choice cards) or a single
# forced confirmation card (curse reveal, or the no-curse fallback), under a title set per request so
# normal rewards, milestone rewards, and curse reveals read as visibly distinct steps.
class_name WaveRewardOverlay
extends Control

signal choice_selected(choice: WaveRewardChoice)

# -- State --

var _choices: Array[WaveRewardChoice] = []

# -- Node references --

@onready var _title_label: Label = %TitleLabel
@onready var _choice_buttons: Array[Button] = [%ChoiceButton1, %ChoiceButton2, %ChoiceButton3]

# == Lifecycle ==


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for i in _choice_buttons.size():
        _choice_buttons[i].pressed.connect(_on_choice_button_pressed.bind(i))
    hide_choices()

# == Signal handlers ==


func _on_choice_button_pressed(index: int) -> void:
    if index < 0 or index >= _choices.size():
        return
    choice_selected.emit(_choices[index])

# == Common API ==


## Shows a multi-card reward offer: one enabled button per choice (up to the button count), each
## showing that choice's title and description. Slots beyond the offered choices show a disabled
## "No reward" card.
func show_offer(title: String, choices: Array[WaveRewardChoice]) -> void:
    _title_label.text = title
    _choices = choices.duplicate()
    for i in _choice_buttons.size():
        var button := _choice_buttons[i]
        button.visible = true
        if i < _choices.size():
            button.text = _format_choice(_choices[i])
            button.disabled = false
        else:
            button.text = "No reward"
            button.disabled = true
    visible = true


## Shows one forced confirmation card in the first button slot and hides the rest; confirming
## applies it through the same choice_selected path a normal offer pick uses.
func show_confirmation(title: String, choice: WaveRewardChoice) -> void:
    _title_label.text = title
    _choices = [choice]
    _choice_buttons[0].visible = true
    _choice_buttons[0].text = _format_choice(choice)
    _choice_buttons[0].disabled = false
    for i in range(1, _choice_buttons.size()):
        _choice_buttons[i].visible = false
    visible = true


func hide_choices() -> void:
    visible = false

# == Display ==


func _format_choice(choice: WaveRewardChoice) -> String:
    var lines := [choice.title(), "", choice.description()]
    return "\n".join(lines)
