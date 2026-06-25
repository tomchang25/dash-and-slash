# event_bus.gd
# Project-wide signal hub. Autoloaded first so other autoloads can connect.
extends Node

@warning_ignore_start("unused_signal")

## Emitted by tutorial-aware gameplay after a semantic milestone commits.
signal tutorial_event(event_id: StringName, payload: Dictionary)

## Emitted after SaveManager resets live providers for a new, loaded, or test slot.
signal save_runtime_reset

## Reference slice signal emitted after ExampleSystem commits an entity purchase.
signal example_entity_collected(entity_id: String)
