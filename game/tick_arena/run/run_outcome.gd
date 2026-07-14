# run_outcome.gd
# Immutable terminal-run snapshot created exactly once per run identity, by either player death or a
# successful End Run. Scene-local value object owned by TickRunController; carries no Coin, save, or
# permanent-unlock data — those belong to the later Meta Progression plan.
class_name RunOutcome
extends RefCounted

enum Reason {
    DEATH,
    END_RUN,
}

var reason: Reason
var character_class: CharacterClassData
var highest_completed_wave: int
var demo_completed: bool

# == Lifecycle ==


func _init(init_reason: Reason, init_character_class: CharacterClassData, init_highest_completed_wave: int, init_demo_completed: bool) -> void:
    reason = init_reason
    character_class = init_character_class
    highest_completed_wave = init_highest_completed_wave
    demo_completed = init_demo_completed
