# registry_audit.gd
# Static-only utility for project-wide audit checks.
# Per-registry validation is driven by RegistryCoordinator.run_validation().
class_name RegistryAudit
extends RefCounted

## Validates project-level scene route wiring during boot.
static func check_scene_registry(scene_registry: SceneRegistry) -> bool:
    if scene_registry == null:
        ToastManager.show_dev_error("RegistryAudit: SceneRouter.scenes is null")
        return false
    return scene_registry.validate()
