# run_result_overlay.gd
# Full-screen overlay presenting one terminal RunOutcome (death or a successful End Run) and
# offering Restart / Main Menu intents. Presentation only — emits signals for TickRunController to
# act on; never resets the run, navigates, or pauses/unpauses the tree itself.
class_name RunResultOverlay
extends Control

signal restart_pressed
signal main_menu_pressed

# -- Node references --

@onready var _title_label: Label = %ResultTitleLabel
@onready var _summary_label: Label = %ResultSummaryLabel
@onready var _restart_button: Button = %RestartButton
@onready var _main_menu_button: Button = %MainMenuButton

# == Lifecycle ==


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _restart_button.pressed.connect(_on_restart_button_pressed)
    _main_menu_button.pressed.connect(_on_main_menu_button_pressed)
    hide_result()

# == Signal handlers ==


func _on_restart_button_pressed() -> void:
    restart_pressed.emit()


func _on_main_menu_button_pressed() -> void:
    main_menu_pressed.emit()

# == Common API ==


func show_result(outcome: RunOutcome) -> void:
    _title_label.text = _title_for(outcome)
    _summary_label.text = _summary_for(outcome)
    visible = true


func hide_result() -> void:
    visible = false

# == Formatting ==


func _title_for(outcome: RunOutcome) -> String:
    match outcome.reason:
        RunOutcome.Reason.DEATH:
            return "You Died"
        RunOutcome.Reason.END_RUN:
            return "Run Complete"
        _:
            ToastManager.show_dev_error("RunResultOverlay: unhandled RunOutcome.Reason %s" % outcome.reason)
            return ""


func _summary_for(outcome: RunOutcome) -> String:
    var character_name := outcome.character_class.display_name if outcome.character_class != null else "Unknown"
    return "%s — Highest Wave: %d" % [character_name, outcome.highest_completed_wave]
