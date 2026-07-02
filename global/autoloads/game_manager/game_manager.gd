# game_manager.gd
# Boot orchestration autoload. Scene transitions live in SceneRouter.
# Supports --test-unit (skip normal boot, route to unit tests).
extends Node

@warning_ignore("return_value_discarded")

func _ready() -> void:
    var args := OS.get_cmdline_args()

    if "--test-unit" in args:
        _boot_for_tests()
        return

    _boot_normal()


func _boot_normal() -> void:
    SaveManager.load()
    SaveManager.run_validation()
    RegistryAudit.check_scene_registry(SceneRouter.scenes)


func _boot_for_tests() -> void:
    # Autoloads have already initialized. Skip save loading and validation.
    if not SceneRouter.go_to_test_runner():
        ToastManager.show_error("GameManager: test runner route failed; falling back to normal boot")
        _boot_normal()
