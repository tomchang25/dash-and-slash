# chase_enemy.gd
# Entity subclass — enemy. Local behaviour: steer toward an assigned target each
# frame. Its ContactHitbox (always on) damages whatever Hurtbox it overlaps; its own
# Health/Hurtbox take damage from the player's attack. Death is relayed via the
# Entity.died signal, which the arena driver listens to for pooled release.
extends Entity

# ── Constants ─────────────────────────────────────────────────────────────────

const SPEED := 90.0

# ── State ─────────────────────────────────────────────────────────────────────

var _target: Node2D = null


# ══ Lifecycle ═════════════════════════════════════════════════════════════════

func _physics_process(_delta: float) -> void:
    if not is_instance_valid(_target):
        velocity = Vector2.ZERO
        return
    velocity = global_position.direction_to(_target.global_position) * SPEED
    move_and_slide()


# ══ Common API ════════════════════════════════════════════════════════════════

## Assigns the chase target (the player). Called by the arena driver on spawn.
func set_target(target: Node2D) -> void:
    _target = target


func reset() -> void:
    super()
    _target = null
