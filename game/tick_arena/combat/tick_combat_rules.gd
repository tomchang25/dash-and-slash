# tick_combat_rules.gd
# Static combat rules for the tick arena: player combat base numbers, hit-angle resolution/display,
# and guard damage/HP bypass. Numbers mirror the design baseline (GDD v0.5 section 6); phase 3
# formalizes this into the shared hit resolver. Hit angle is DirectionResolver.HitAngle, the single
# production hit-angle vocabulary shared with the legacy physics path.
class_name TickCombatRules

const FRONT_GUARD_DAMAGE := 8
const SIDE_GUARD_FLOOR := 16
const BACK_GUARD_FLOOR := 32
const SIDE_HP_BYPASS := 0.1
const BACK_HP_BYPASS := 0.25

const PLAYER_ATTACK_DAMAGE := 20.0
const PLAYER_DASH_DAMAGE := 30.0
const PLAYER_SMASH_DAMAGE := 30.0
const DASH_RANGE := 5
const DASH_COOLDOWN_TICKS := 4
const SMASH_RANGE := 3
const SMASH_COOLDOWN_TICKS := 6
const MAX_MOBILITY_RANGE_BONUS_PERCENT := 200.0

# == Common API ==


## Classifies the attack angle from the attacker's origin cell relative to the target's facing.
## Perfectly diagonal or zero deltas resolve to SIDE.
static func resolve_angle(attacker_cell: Vector2i, target_cell: Vector2i, target_facing: Vector2i) -> DirectionResolver.HitAngle:
    var dir := dominant_direction(attacker_cell - target_cell)
    if dir == Vector2i.ZERO:
        return DirectionResolver.HitAngle.SIDE
    if dir == target_facing:
        return DirectionResolver.HitAngle.FRONT
    if dir == -target_facing:
        return DirectionResolver.HitAngle.BACK
    return DirectionResolver.HitAngle.SIDE


## Returns the guard damage for a hit at the given angle against a target with the given guard maximum.
static func guard_damage_for(angle: DirectionResolver.HitAngle, max_guard: int) -> int:
    match angle:
        DirectionResolver.HitAngle.FRONT:
            return FRONT_GUARD_DAMAGE
        DirectionResolver.HitAngle.SIDE:
            return maxi(int(max_guard / 4.0), SIDE_GUARD_FLOOR)
        DirectionResolver.HitAngle.BACK:
            return maxi(int(max_guard / 2.0), BACK_GUARD_FLOOR)
        _:
            ToastManager.show_dev_error("TickCombatRules: unexpected hit angle %d" % angle)
            return 0


## Returns the fraction of base damage that bypasses an unbroken guard at the given angle.
static func hp_bypass_for(angle: DirectionResolver.HitAngle) -> float:
    match angle:
        DirectionResolver.HitAngle.FRONT:
            return 0.0
        DirectionResolver.HitAngle.SIDE:
            return SIDE_HP_BYPASS
        DirectionResolver.HitAngle.BACK:
            return BACK_HP_BYPASS
        _:
            ToastManager.show_dev_error("TickCombatRules: unexpected hit angle %d" % angle)
            return 0.0


## Returns the dominant orthogonal direction of a cell delta, or ZERO when the delta is zero or perfectly diagonal.
static func dominant_direction(delta: Vector2i) -> Vector2i:
    if delta == Vector2i.ZERO or absi(delta.x) == absi(delta.y):
        return Vector2i.ZERO
    if absi(delta.x) > absi(delta.y):
        return Vector2i(signi(delta.x), 0)
    return Vector2i(0, signi(delta.y))


## Renders a resolved hit angle as the display label used in HUD feedback messages and preview
## badges. Handles NONE for empty outcomes as well as the three real hit angles.
static func angle_name(angle: DirectionResolver.HitAngle) -> String:
    match angle:
        DirectionResolver.HitAngle.FRONT:
            return "Front"
        DirectionResolver.HitAngle.SIDE:
            return "Side"
        DirectionResolver.HitAngle.BACK:
            return "BACK"
        DirectionResolver.HitAngle.NONE:
            return "NONE"
        _:
            ToastManager.show_dev_error("TickCombatRules: unexpected hit angle %d" % angle)
            return "?"


## Projects a mobility-slot payload's base cooldown (Dash or Smash) through the run's Mobility
## Cooldown reduction stacks, floored at 1 tick so the mobility slot is never truly free through this Minor.
static func mobility_cooldown_ticks(base_ticks: int, reduction_stacks: int) -> int:
    return maxi(base_ticks - reduction_stacks, 1)


## Projects a mobility-slot payload's base range (in cells, Dash or Smash) through the run's Mobility
## Range percent bonus, capped at the given max bonus percent and floored at 1 cell so a reward can
## never collapse the mobility slot's reach to nothing.
static func mobility_range_cells(base_range: int, bonus_percent: float, max_bonus_percent: float) -> int:
    var capped_percent := minf(bonus_percent, max_bonus_percent)
    return maxi(int(round(float(base_range) * (1.0 + capped_percent / 100.0))), 1)


## Projects normal attack's base damage through the run's Normal Attack Damage bonus total.
static func normal_attack_damage(bonus_total: float) -> float:
    return PLAYER_ATTACK_DAMAGE + bonus_total


## Projects a mobility-slot payload's base damage (Dash or Smash) through the run's Mobility Attack
## Damage bonus total.
static func mobility_attack_damage(base_damage: float, bonus_total: float) -> float:
    return base_damage + bonus_total
