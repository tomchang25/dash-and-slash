# wave_reward_choice_controller.gd
# Scene-scoped coordinator for showing, pausing around, and applying one prepared wave reward offer
# or forced confirmation. Cadence (normal vs. milestone vs. curse) and artifact rolling belong to
# TickRunController; this controller only knows how to display a prepared WaveRewardChoice set and
# apply whichever one gets picked or confirmed.
class_name WaveRewardChoiceController
extends RefCounted

signal choice_applied

var _overlay: WaveRewardOverlay
var _context: WaveRewardContext
var _current_offer: Array[WaveRewardChoice] = []
var _was_paused := false

# == Lifecycle ==


func _init(overlay: WaveRewardOverlay, context: WaveRewardContext) -> void:
    _overlay = overlay
    _context = context
    _overlay.choice_selected.connect(_on_choice_selected)

# == Signal handlers ==


func _on_choice_selected(choice: WaveRewardChoice) -> void:
    if not choice in _current_offer:
        return
    choice.apply(_context)
    _current_offer.clear()
    _overlay.hide_choices()
    _overlay.get_tree().paused = _was_paused
    choice_applied.emit()

# == Common API ==


## Shows a multi-card reward offer (normal Minor three-choice or milestone three-choice) under the
## given title. Picking any card applies it and emits choice_applied.
func show_offer(title: String, choices: Array[WaveRewardChoice]) -> void:
    _current_offer = choices
    _pause_tree()
    _overlay.show_offer(title, choices)


## Shows one forced confirmation card (curse reveal or the no-curse fallback) under the given title.
## Confirming applies it and emits choice_applied.
func show_confirmation(title: String, choice: WaveRewardChoice) -> void:
    _current_offer = [choice]
    _pause_tree()
    _overlay.show_confirmation(title, choice)


## Hides any open offer/confirmation and drops pending choice state without applying anything.
## Restart and death cleanup call this so a stale offer or confirmation can never reopen or apply
## after the run resets; restoring the tree's paused state is the caller's own cleanup responsibility.
func cancel() -> void:
    _current_offer.clear()
    _overlay.hide_choices()

# == Pause scope ==


func _pause_tree() -> void:
    _was_paused = _overlay.get_tree().paused
    _overlay.get_tree().paused = true
