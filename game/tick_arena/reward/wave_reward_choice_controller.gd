# wave_reward_choice_controller.gd
# Scene-scoped coordinator for rolling, showing, and applying wave reward choices.
class_name WaveRewardChoiceController
extends RefCounted

signal choice_applied

## Which GridArena tile operation the pending automatic per-wave terrain mutation will apply.
## ADD_LAND is used on milestone waves; MOVE_LAND/REMOVE_LAND are rolled 50/50 on normal waves.
enum TerrainMutationKind {
    ADD_LAND,
    MOVE_LAND,
    REMOVE_LAND,
}

var _overlay: WaveRewardOverlay
var _generator: WaveRewardChoiceGenerator
var _context: WaveRewardContext
var _current_offer: Array[WaveRewardChoice] = []
var _was_paused := false

# == Lifecycle ==


func _init(
        overlay: WaveRewardOverlay,
        generator: WaveRewardChoiceGenerator,
        context: WaveRewardContext,
) -> void:
    _overlay = overlay
    _generator = generator
    _context = context
    _overlay.choice_selected.connect(_on_choice_selected)

# == Common API ==


func open_reward_choice(wave_number: int, terrain_mutation_kind: int) -> void:
    _current_offer = _generator.roll(WaveRewardChoiceGenerator.RewardKind.MINOR, 3, wave_number, _context)
    _was_paused = _overlay.get_tree().paused
    _overlay.show_choices(_current_offer, terrain_mutation_kind)
    _overlay.get_tree().paused = true

# == Signal handlers ==


func _on_choice_selected(choice: WaveRewardChoice) -> void:
    if not choice in _current_offer:
        return
    choice.apply(_context)
    _current_offer.clear()
    _overlay.hide_choices()
    _overlay.get_tree().paused = _was_paused
    choice_applied.emit()
