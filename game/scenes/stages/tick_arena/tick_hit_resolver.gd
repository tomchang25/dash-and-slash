# tick_hit_resolver.gd
# Pure grid-snapshot hit resolver for tick combat previews and committed player hits.
class_name TickHitResolver
extends RefCounted

enum HitKind {
    NORMAL,
    DASH,
    SMASH,
}

const GUARDED_DAMAGE_MULTIPLIER := 0.2
const FEEDBACK_WHIFF := &"whiff"
const FEEDBACK_BLOCKED := &"blocked"
const FEEDBACK_DAMAGED := &"damaged"
const FEEDBACK_GUARD_BREAK := &"guard_break"
const FEEDBACK_STAGGER_BURST := &"stagger_burst"
const FEEDBACK_KILL := &"kill"

# == Common API ==


## Returns a zeroed outcome for missing, dead, or otherwise unresolvable targets.
static func empty_outcome() -> Dictionary:
    return {
        "angle": DirectionResolver.HitAngle.NONE,
        "was_guarded": false,
        "staggered": false,
        "guard_broken": false,
        "stagger_burst": false,
        "killed": false,
        "hp_damage": 0.0,
        "guard_damage": 0,
        "feedback_kind": FEEDBACK_WHIFF,
    }


## Resolves one tick-grid hit from immutable target state. Optional guard damage lets legacy enemy kinds keep their authored guard profile while using this resolver's math.
static func resolve_hit(attacker_origin_cell: Vector2i, target_snapshot: Dictionary, base_damage: float, hit_kind: int, guard_damage_override := -1) -> Dictionary:
    if target_snapshot.is_empty() or not bool(target_snapshot.get("alive", true)):
        return empty_outcome()

    var target_cell: Vector2i = target_snapshot.get("cell", Vector2i.ZERO)
    var target_facing: Vector2i = target_snapshot.get("facing", Vector2i.ZERO)
    var angle := _to_direction_angle(TickCombatRules.resolve_angle(attacker_origin_cell, target_cell, target_facing))
    var guard_max := int(target_snapshot.get("guard_max", 0))
    var guard_damage := guard_damage_override if guard_damage_override >= 0 else _guard_damage_for(hit_kind, angle, guard_max)
    return resolve_precomputed(angle, guard_damage, target_snapshot, base_damage)


## Resolves one hit from a precomputed angle and guard damage. Legacy adapters use this to share the same outcome math as tick-grid hits.
static func resolve_precomputed(angle: int, guard_damage: int, target_snapshot: Dictionary, base_damage: float) -> Dictionary:
    if target_snapshot.is_empty() or not bool(target_snapshot.get("alive", true)):
        return empty_outcome()

    var guard_current := int(target_snapshot.get("guard_current", 0))
    var already_staggered := bool(target_snapshot.get("staggered", false))
    var has_guard := bool(target_snapshot.get("has_guard", false))
    var will_break_guard := has_guard and not already_staggered and guard_current > 0 and guard_damage >= guard_current
    var full_damage := not has_guard or already_staggered or will_break_guard
    var hp_damage := base_damage if full_damage else base_damage * GUARDED_DAMAGE_MULTIPLIER
    hp_damage = apply_defense(hp_damage, float(target_snapshot.get("defense", 0.0)))
    var hp_current := float(target_snapshot.get("hp", 0.0))
    var killed := hp_current - hp_damage <= 0.0

    return {
        "angle": angle,
        "was_guarded": has_guard and not full_damage,
        "staggered": already_staggered,
        "guard_broken": will_break_guard,
        "stagger_burst": already_staggered,
        "killed": killed,
        "hp_damage": hp_damage,
        "guard_damage": guard_damage,
        "feedback_kind": _feedback_kind(killed, already_staggered, will_break_guard, has_guard, full_damage),
    }


## Reduces incoming hp damage by a flat defense value using effective = amount * (amount / (amount + defense)). No-op at defense 0.
static func apply_defense(amount: float, defense: float) -> float:
    if defense <= 0.0:
        return amount
    return amount * (amount / (amount + defense))

# == Resolution ==


static func _guard_damage_for(hit_kind: int, angle: int, guard_max: int) -> int:
    match hit_kind:
        HitKind.NORMAL:
            return TickCombatRules.guard_damage_for(_to_tick_angle(angle), guard_max)
        HitKind.DASH:
            return TickCombatRules.guard_damage_for(_to_tick_angle(angle), guard_max)
        HitKind.SMASH:
            return TickCombatRules.guard_damage_for(_to_tick_angle(angle), guard_max)
        _:
            ToastManager.show_dev_error("TickHitResolver: unexpected hit kind %d" % hit_kind)
            return 0


static func _feedback_kind(killed: bool, already_staggered: bool, guard_broken: bool, has_guard: bool, full_damage: bool) -> StringName:
    if killed:
        return FEEDBACK_KILL
    if already_staggered:
        return FEEDBACK_STAGGER_BURST
    if guard_broken:
        return FEEDBACK_GUARD_BREAK
    if has_guard and not full_damage:
        return FEEDBACK_BLOCKED
    return FEEDBACK_DAMAGED


static func _to_direction_angle(angle: int) -> int:
    match angle:
        TickCombatRules.HitAngle.FRONT:
            return DirectionResolver.HitAngle.FRONT
        TickCombatRules.HitAngle.SIDE:
            return DirectionResolver.HitAngle.SIDE
        TickCombatRules.HitAngle.BACK:
            return DirectionResolver.HitAngle.BACK
        _:
            ToastManager.show_dev_error("TickHitResolver: unexpected tick hit angle %d" % angle)
            return DirectionResolver.HitAngle.NONE


static func _to_tick_angle(angle: int) -> int:
    match angle:
        DirectionResolver.HitAngle.FRONT:
            return TickCombatRules.HitAngle.FRONT
        DirectionResolver.HitAngle.SIDE:
            return TickCombatRules.HitAngle.SIDE
        DirectionResolver.HitAngle.BACK:
            return TickCombatRules.HitAngle.BACK
        DirectionResolver.HitAngle.NONE:
            return TickCombatRules.HitAngle.SIDE
        _:
            ToastManager.show_dev_error("TickHitResolver: unexpected direction hit angle %d" % angle)
            return TickCombatRules.HitAngle.SIDE
