# proto_combat_rules.gd
# Static combat rules for the tick prototype: hit-angle resolution, guard damage, HP bypass, and stagger multipliers.
# Numbers mirror the production baseline (GDD v0.5 section 6) so the prototype's payoff matches the real game's identity.
class_name ProtoCombatRules

enum HitAngle {
    FRONT,
    SIDE,
    BACK,
}

const FRONT_GUARD_DAMAGE := 8
const SIDE_GUARD_FLOOR := 16
const BACK_GUARD_FLOOR := 32
const SIDE_HP_BYPASS := 0.1
const BACK_HP_BYPASS := 0.25
const STAGGER_ATTACK_MULTIPLIER := 1.0
const STAGGER_DASH_MULTIPLIER := 2.0


# == Common API ==


## Classifies the attack angle from the attacker's origin cell relative to the target's facing.
## Perfectly diagonal or zero deltas resolve to SIDE.
static func resolve_angle(attacker_cell: Vector2i, target_cell: Vector2i, target_facing: Vector2i) -> HitAngle:
    var dir := dominant_direction(attacker_cell - target_cell)
    if dir == Vector2i.ZERO:
        return HitAngle.SIDE
    if dir == target_facing:
        return HitAngle.FRONT
    if dir == -target_facing:
        return HitAngle.BACK
    return HitAngle.SIDE


## Returns the guard damage for a hit at the given angle against a target with the given guard maximum.
static func guard_damage_for(angle: HitAngle, max_guard: int) -> int:
    match angle:
        HitAngle.FRONT:
            return FRONT_GUARD_DAMAGE
        HitAngle.SIDE:
            return maxi(int(max_guard / 4.0), SIDE_GUARD_FLOOR)
        HitAngle.BACK:
            return maxi(int(max_guard / 2.0), BACK_GUARD_FLOOR)
        _:
            ToastManager.show_dev_error("ProtoCombatRules: unexpected hit angle %d" % angle)
            return 0


## Returns the fraction of base damage that bypasses an unbroken guard at the given angle.
static func hp_bypass_for(angle: HitAngle) -> float:
    match angle:
        HitAngle.FRONT:
            return 0.0
        HitAngle.SIDE:
            return SIDE_HP_BYPASS
        HitAngle.BACK:
            return BACK_HP_BYPASS
        _:
            ToastManager.show_dev_error("ProtoCombatRules: unexpected hit angle %d" % angle)
            return 0.0


## Returns the dominant orthogonal direction of a cell delta, or ZERO when the delta is zero or perfectly diagonal.
static func dominant_direction(delta: Vector2i) -> Vector2i:
    if delta == Vector2i.ZERO or absi(delta.x) == absi(delta.y):
        return Vector2i.ZERO
    if absi(delta.x) > absi(delta.y):
        return Vector2i(signi(delta.x), 0)
    return Vector2i(0, signi(delta.y))
