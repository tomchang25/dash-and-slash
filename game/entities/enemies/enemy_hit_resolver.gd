# enemy_hit_resolver.gd
# Stateless hit-outcome math shared by hit prediction, tick hit resolution, and the physics hit path,
# so a preview, a tick commit, and a real-time overlap can never disagree on guard, damage, or lethality.
class_name EnemyHitResolver
extends RefCounted

## Damage fraction that leaks through an intact guard.
const GUARDED_DAMAGE_MULTIPLIER := 0.2

# == Common API ================================================================


## Returns the zeroed outcome dictionary used when a hit cannot resolve (dead or missing target).
static func empty_outcome() -> Dictionary:
    return {
        "angle": DirectionResolver.HitAngle.NONE,
        "staggered": false,
        "guard_broken": false,
        "killed": false,
        "hp_damage": 0.0,
        "guard_damage": 0,
    }


## Computes the full outcome of one incoming hit from a pre-resolved hit angle and guard damage.
## Pure math over the target's current guard and health state; never mutates either component.
## Returns keys angle, staggered, guard_broken, killed, hp_damage, guard_damage.
static func resolve_outcome(angle: int, guard_damage: int, guard: Guard, health: Health, base_damage: float, defense: float) -> Dictionary:
    var outcome := empty_outcome()
    var already_staggered := guard != null and guard.is_staggered()
    var will_break_guard := guard != null and not already_staggered and guard.current() > 0 and guard_damage >= guard.current()
    var full_damage := guard == null or already_staggered or will_break_guard
    var hp_damage := base_damage if full_damage else base_damage * GUARDED_DAMAGE_MULTIPLIER
    hp_damage = apply_defense(hp_damage, defense)

    outcome["angle"] = angle
    outcome["staggered"] = already_staggered
    outcome["guard_broken"] = will_break_guard
    outcome["hp_damage"] = hp_damage
    outcome["guard_damage"] = guard_damage
    var remaining := (health.current() - hp_damage) if health != null else 0.0
    outcome["killed"] = remaining <= 0.0
    return outcome


## Reduces incoming hp damage by a flat defense value using effective = amount * (amount / (amount + defense)).
## No-op at defense 0.
static func apply_defense(amount: float, defense: float) -> float:
    if defense <= 0.0:
        return amount
    return amount * (amount / (amount + defense))
