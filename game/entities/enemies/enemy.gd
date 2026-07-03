# enemy.gd
# Base for health-backed combat enemies that participate in wave death handling.
class_name Enemy
extends Entity

signal died(entity: Entity)
signal health_changed(current: float, maximum: float)

# -- Exports ------------------------------------------------------------------
@export var health: Health

# == Lifecycle ================================================================


func _ready() -> void:
    super()
    if health != null:
        health.died.connect(_on_health_died)
        health.health_changed.connect(_on_health_changed)
        emit_health_snapshot()

# == Signal handlers ==========================================================


func _on_health_died() -> void:
    _on_death_effects()
    died.emit(self)


func _on_health_changed(current: float, maximum: float) -> void:
    health_changed.emit(current, maximum)

# == Common API ================================================================


func emit_health_snapshot() -> void:
    if health != null:
        health_changed.emit(health.current(), health.max_health)

# == Death =====================================================================


## Override point for the single shared death trigger. Combat damage reaching
## zero hp, Health.kill() (debug instant-kill), and force-death entry points
## all route through Health.died into this one hook, so subclasses implement
## their death sequence here exactly once. Base implementation is a no-op;
## state-machine-driven subclasses (e.g. GridEnemy) override it to request
## their dead state transition.
func _on_death_effects() -> void:
    pass
