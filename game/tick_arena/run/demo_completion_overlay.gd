# demo_completion_overlay.gd
# Full-screen overlay presenting the wave-10 demo-completion choice: End Run or Continue Endless.
# Presentation only — emits intents for TickRunController to act on; never navigates, resets the
# run, or pauses/unpauses the tree itself.
class_name DemoCompletionOverlay
extends Control

signal end_run_pressed
signal continue_endless_pressed

# -- Node references --

@onready var _end_run_button: Button = %EndRunButton
@onready var _continue_endless_button: Button = %ContinueEndlessButton

# == Lifecycle ==


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _end_run_button.pressed.connect(_on_end_run_button_pressed)
    _continue_endless_button.pressed.connect(_on_continue_endless_button_pressed)
    hide_choice()

# == Signal handlers ==


func _on_end_run_button_pressed() -> void:
    end_run_pressed.emit()


func _on_continue_endless_button_pressed() -> void:
    continue_endless_pressed.emit()

# == Common API ==


func show_choice() -> void:
    visible = true


func hide_choice() -> void:
    visible = false
