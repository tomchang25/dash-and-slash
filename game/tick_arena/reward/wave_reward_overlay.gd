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
@onready var _cards: Array[WaveRewardCard] = [%RewardCard1, %RewardCard2, %RewardCard3]

# == Lifecycle ==


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for i in _cards.size():
        _cards[i].card_pressed.connect(_on_card_pressed.bind(i))
    hide_choices()

# == Signal handlers ==


func _on_card_pressed(index: int) -> void:
    if index < 0 or index >= _choices.size():
        return
    choice_selected.emit(_choices[index])

# == Common API ==


## Shows a multi-card reward offer: one enabled card per choice (up to the card count). Slots
## beyond the offered choices show a disabled empty-state card instead of fabricating a choice.
func show_offer(title: String, choices: Array[WaveRewardChoice]) -> void:
    _title_label.text = title
    _choices = choices.duplicate()
    for i in _cards.size():
        _cards[i].visible = true
        if i < _choices.size():
            _cards[i].setup(_choices[i], false)
        else:
            _cards[i].setup(WaveRewardChoice.empty(), true)
    visible = true


## Shows one forced confirmation card in the first slot and hides the rest; confirming applies it
## through the same choice_selected path a normal offer pick uses.
func show_confirmation(title: String, choice: WaveRewardChoice) -> void:
    _title_label.text = title
    _choices = [choice]
    _cards[0].visible = true
    _cards[0].setup(choice, false)
    for i in range(1, _cards.size()):
        _cards[i].visible = false
    visible = true


func hide_choices() -> void:
    visible = false
