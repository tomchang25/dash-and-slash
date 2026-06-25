# direction_resolver.gd
# Static utility: classifies an attack angle relative to the target's facing
# as FRONT, SIDE, or BACK. Uses attacker body center vs target body center
# and target facing — never the hitbox overlap point (per GDD §6.3).
class_name DirectionResolver

enum HitAngle { FRONT, SIDE, BACK, NONE }

const FRONT_THRESHOLD := 0.383 # cos(22.5°) — ±22.5° = front cone
const SIDE_THRESHOLD := -0.383 # cos(22.5°) — rest is back


static func resolve(attacker_pos: Vector2, target_pos: Vector2, target_facing: Vector2) -> HitAngle:
    if target_facing == Vector2.ZERO:
        return HitAngle.NONE

    var to_attacker := (attacker_pos - target_pos).normalized()
    var dot := to_attacker.dot(target_facing)

    if dot >= FRONT_THRESHOLD:
        return HitAngle.FRONT
    if dot >= SIDE_THRESHOLD:
        return HitAngle.SIDE
    return HitAngle.BACK


static func normal_guard_damage(angle: HitAngle) -> int:
    match angle:
        HitAngle.FRONT:
            return 1
        HitAngle.SIDE:
            return 2
        HitAngle.BACK:
            return 4
        _:
            return 0


static func dash_guard_damage(angle: HitAngle) -> int:
    match angle:
        HitAngle.FRONT:
            return 1
        HitAngle.SIDE:
            return 4
        HitAngle.BACK:
            return 8
        _:
            return 0
