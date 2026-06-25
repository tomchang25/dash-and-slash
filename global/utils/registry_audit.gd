# registry_audit.gd
# Static-only utility for project-wide audit checks.
# Per-registry validation is driven by RegistryCoordinator.run_validation().
class_name RegistryAudit
extends RefCounted


## Placeholder — scene wiring audit removed; GameManager now owns its scene
## table as a const Dictionary. Called from GameManager._ready() for API compat.
static func check_scene_registry(_unused: Variant) -> bool:
	return true
