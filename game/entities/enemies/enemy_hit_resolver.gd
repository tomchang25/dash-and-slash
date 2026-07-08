# enemy_hit_resolver.gd
# Compatibility adapter for legacy enemy hit math. Tick-grid hit prediction and commit use TickHitResolver
# real-time physics hits still enter here with a pre-resolved world-space angle.
class_name EnemyHitResolver
extends RefCounted

## Damage fraction that leaks through an intact guard.
const GUARDED_DAMAGE_MULTIPLIER := TickHitResolver.GUARDED_DAMAGE_MULTIPLIER

# == Common API ==


## Returns the zeroed outcome used when a hit cannot resolve (dead or missing target).
static func empty_outcome() -> TickHitOutcome:
    return TickHitResolver.empty_outcome()


## Computes the full outcome of one incoming hit from a pre-resolved hit angle and guard damage.
## Pure math over the target's current guard and health state; never mutates either component.
## Returns a TickHitOutcome with fields angle, staggered, guard_broken, killed, hp_damage, guard_damage.
static func resolve_outcome(
        angle: DirectionResolver.HitAngle,
        guard_damage: int,
        guard: Guard,
        health: Health,
        base_damage: float,
        defense: float,
        stagger_burst_multiplier := TickCombatRules.STAGGER_ATTACK_MULTIPLIER,
) -> TickHitOutcome:
    return TickHitResolver.resolve_precomputed(angle, guard_damage, _target_snapshot(guard, health, defense), base_damage, false, false, stagger_burst_multiplier)


## Reduces incoming hp damage by a flat defense value using effective = amount * (amount / (amount + defense)).
## No-op at defense 0.
static func apply_defense(amount: float, defense: float) -> float:
    return TickHitResolver.apply_defense(amount, defense)

# == Snapshot adapter ==


static func _target_snapshot(guard: Guard, health: Health, defense: float) -> Dictionary:
    return {
        "cell": Vector2i.ZERO,
        "facing": Vector2i.ZERO,
        "has_guard": guard != null,
        "guard_current": guard.current() if guard != null else 0,
        "guard_max": guard.max_guard if guard != null else 0,
        "staggered": guard.is_staggered() if guard != null else false,
        "hp": health.current() if health != null else 0.0,
        "hp_max": health.max_health if health != null else 0.0,
        "defense": defense,
        "alive": health == null or health.current() > 0.0,
    }
