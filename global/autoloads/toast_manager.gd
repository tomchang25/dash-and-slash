# toast_manager.gd
# Passive notification facade. Projects can replace these no-op methods with UI.
extends Node


## Shows a user-visible warning message.
func show_warning(_message: String) -> void:
	pass


## Shows a user-visible error message.
func show_error(_message: String) -> void:
	pass


## Shows a debug/info message. Template default is intentionally silent.
func show_info(_message: String) -> void:
	pass


## Shows a developer-facing error message. Kept separate from user errors.
func show_dev_error(_message: String) -> void:
	pass
