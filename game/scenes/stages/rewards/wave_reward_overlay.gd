# wave_reward_overlay.gd
# Full-screen overlay that presents three generated wave reward choices.
class_name WaveRewardOverlay
extends Control

signal choice_selected(choice: WaveRewardChoice)

# -- State --

var _choices: Array[WaveRewardChoice] = []

# -- Node references --

@onready var _choice_buttons: Array[Button] = [%ChoiceButton1, %ChoiceButton2, %ChoiceButton3]

# == Lifecycle ==


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for i in _choice_buttons.size():
        _choice_buttons[i].pressed.connect(_on_choice_button_pressed.bind(i))
    hide_choices()

# == Common API ==


func show_choices(choices: Array[WaveRewardChoice]) -> void:
    _choices = choices.duplicate()
    for i in _choice_buttons.size():
        var button := _choice_buttons[i]
        if i < _choices.size():
            button.text = _format_choice(_choices[i])
            button.disabled = false
        else:
            button.text = "No reward"
            button.disabled = true
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
    var lines := [choice.display_name]
    lines.append("Points: %s / %s" % [_format_points(choice.total_points()), _format_points(choice.target_points)])
    lines.append("")
    lines.append_array(choice.description_lines())
    return "\n".join(lines)


func _format_points(points: float) -> String:
    if is_equal_approx(points, roundf(points)):
        return "%d" % int(roundf(points))
    return "%.1f" % points
