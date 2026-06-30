# wave_reward_choice_controller.gd
# Scene-scoped coordinator for rolling, showing, and applying wave reward choices.
class_name WaveRewardChoiceController
extends RefCounted

signal choice_applied

var _overlay: WaveRewardOverlay
var _generator: WaveRewardChoiceGenerator
var _applier: WaveRewardApplier
var _grid: GridArena
var _player: Player
var _current_offer: Array[WaveRewardChoice] = []
var _was_paused := false

# == Lifecycle ==


func _init(
        overlay: WaveRewardOverlay,
        generator: WaveRewardChoiceGenerator,
        applier: WaveRewardApplier,
        grid: GridArena,
        player: Player,
) -> void:
    _overlay = overlay
    _generator = generator
    _applier = applier
    _grid = grid
    _player = player
    _overlay.choice_selected.connect(_on_choice_selected)

# == Common API ==


func open_reward_choice(wave_number: int, target_points: float) -> void:
    var context := {
        "grid": _grid,
        "player": _player,
    }
    _current_offer = _generator.roll_choices(wave_number, target_points, context)
    _was_paused = _overlay.get_tree().paused
    _overlay.show_choices(_current_offer)
    _overlay.get_tree().paused = true

# == Signal handlers ==


func _on_choice_selected(choice: WaveRewardChoice) -> void:
    if not choice in _current_offer:
        return
    _applier.apply(choice)
    _current_offer.clear()
    _overlay.hide_choices()
    _overlay.get_tree().paused = _was_paused
    choice_applied.emit()
