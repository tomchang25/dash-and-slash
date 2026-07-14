# tick_hit_resolver.gd
# Pure grid-snapshot hit resolver for tick combat previews and committed player hits.
class_name TickHitResolver
extends RefCounted

const GUARDED_DAMAGE_MULTIPLIER := 0.2

# == Common API ==


## Returns a zeroed outcome for missing, dead, or otherwise unresolvable targets.
static func empty_outcome() -> TickHitOutcome:
    return TickHitOutcome.new()


## Resolves one tick-grid hit from immutable target state. Optional guard damage lets legacy enemy
## kinds keep their authored guard profile while using this resolver's math. guard_shredder_trigger
## and execution_trigger are Dash-triggered Major hooks: pass true only from an actual Dash whose
## run build has that trigger active, never from Smash or a normal attack.
## stagger_burst_multiplier lets Mobility attacks restore their authored 2.0x payoff against already-staggered targets.
## The caller's origin_cell already encodes which Mobility is striking (Dash: the cell the victim was
## hit from along its travel path; Smash: the locked landing cell) — this resolver derives the hit
## angle from whatever origin it is given and does not need to know which Mobility produced it.
static func resolve_hit(
        attacker_origin_cell: Vector2i,
        target_snapshot: Dictionary,
        base_damage: float,
        guard_damage_override := -1,
        guard_shredder_trigger := false,
        execution_trigger := false,
        stagger_burst_multiplier := TickCombatRules.STAGGER_ATTACK_MULTIPLIER,
) -> TickHitOutcome:
    if target_snapshot.is_empty() or not bool(target_snapshot.get("alive", true)):
        return empty_outcome()

    var target_cell: Vector2i = target_snapshot.get("cell", Vector2i.ZERO)
    var target_facing: Vector2i = target_snapshot.get("facing", Vector2i.ZERO)
    var angle := TickCombatRules.resolve_angle(attacker_origin_cell, target_cell, target_facing)
    var guard_damage := guard_damage_override if guard_damage_override >= 0 else TickCombatRules.guard_damage_for(angle)
    return resolve_precomputed(angle, guard_damage, target_snapshot, base_damage, guard_shredder_trigger, execution_trigger, stagger_burst_multiplier)


## Resolves one hit from a precomputed angle and guard damage. Legacy adapters use this to share the
## same outcome math as tick-grid hits. Execution takes priority over Guard Shredder because an
## already-staggered target has no guard left to shred.
static func resolve_precomputed(
        angle: TileDirectionResolver.HitAngle,
        guard_damage: int,
        target_snapshot: Dictionary,
        base_damage: float,
        guard_shredder_trigger := false,
        execution_trigger := false,
        stagger_burst_multiplier := TickCombatRules.STAGGER_ATTACK_MULTIPLIER,
) -> TickHitOutcome:
    if target_snapshot.is_empty() or not bool(target_snapshot.get("alive", true)):
        return empty_outcome()

    var guard_current := int(target_snapshot.get("guard_current", 0))
    var already_staggered := bool(target_snapshot.get("staggered", false))
    var has_guard := bool(target_snapshot.get("has_guard", false))
    var guard_protection_multiplier := float(target_snapshot.get("guard_protection_multiplier", 1.0))

    if execution_trigger and already_staggered:
        return _resolve_execution_kill(angle, target_snapshot)

    var guard_shredder_hit := (
        guard_shredder_trigger
        and has_guard
        and not already_staggered
        and guard_current > 0
        and angle == TileDirectionResolver.HitAngle.BACK
    )
    if guard_shredder_hit:
        # Zero Guard directly, bypassing ordinary post-Stagger protection.
        guard_damage = guard_current
    elif has_guard and not already_staggered:
        guard_damage = int(float(guard_damage) * guard_protection_multiplier)

    var will_break_guard := has_guard and not already_staggered and guard_current > 0 and guard_damage >= guard_current
    var full_damage := not has_guard or already_staggered or will_break_guard
    var hp_damage := base_damage if full_damage else base_damage * GUARDED_DAMAGE_MULTIPLIER
    if already_staggered:
        hp_damage *= stagger_burst_multiplier
    hp_damage = apply_defense(hp_damage, float(target_snapshot.get("defense", 0.0)))
    var hp_current := float(target_snapshot.get("hp", 0.0))
    var killed := hp_current - hp_damage <= 0.0

    var outcome := TickHitOutcome.new()
    outcome.angle = angle
    outcome.was_guarded = has_guard and not full_damage
    outcome.staggered = already_staggered
    outcome.guard_broken = will_break_guard
    outcome.stagger_burst = already_staggered
    outcome.killed = killed
    outcome.hp_damage = hp_damage
    outcome.guard_damage = guard_damage
    outcome.feedback_kind = _feedback_kind(killed, already_staggered, will_break_guard, has_guard, full_damage)
    outcome.major_trigger = TickHitOutcome.MajorTrigger.GUARD_SHREDDER if guard_shredder_hit and will_break_guard else TickHitOutcome.MajorTrigger.NONE
    return outcome


## Reduces incoming hp damage by a flat defense value using effective = amount * (amount / (amount + defense)). No-op at defense 0.
static func apply_defense(amount: float, defense: float) -> float:
    if defense <= 0.0:
        return amount
    return amount * (amount / (amount + defense))


## Returns whether any Dash hit outcome satisfies Chain Dash, folding multiple victims into one
## state application.
static func any_qualifies_for_chain_dash(outcomes: Array[TickHitOutcome]) -> bool:
    for outcome in outcomes:
        if qualifies_for_chain_dash(outcome):
            return true
    return false


## Returns whether one Dash hit qualifies through a kill, guard break, staggered target, or back angle.
static func qualifies_for_chain_dash(outcome: TickHitOutcome) -> bool:
    if outcome.killed or outcome.guard_broken or outcome.staggered:
        return true
    return outcome.angle == TileDirectionResolver.HitAngle.BACK

# == Resolution ==


## Execution's instant-kill outcome: a dash hit on an already-staggered target kills outright, replacing
## whatever stagger-burst damage the hit would otherwise deal.
static func _resolve_execution_kill(angle: TileDirectionResolver.HitAngle, target_snapshot: Dictionary) -> TickHitOutcome:
    var outcome := TickHitOutcome.new()
    outcome.angle = angle
    outcome.staggered = true
    outcome.stagger_burst = true
    outcome.killed = true
    outcome.hp_damage = float(target_snapshot.get("hp", 0.0))
    outcome.feedback_kind = TickHitOutcome.FeedbackKind.KILL
    outcome.major_trigger = TickHitOutcome.MajorTrigger.EXECUTION
    return outcome


static func _feedback_kind(killed: bool, already_staggered: bool, guard_broken: bool, has_guard: bool, full_damage: bool) -> TickHitOutcome.FeedbackKind:
    if killed:
        return TickHitOutcome.FeedbackKind.KILL
    if already_staggered:
        return TickHitOutcome.FeedbackKind.STAGGER_BURST
    if guard_broken:
        return TickHitOutcome.FeedbackKind.GUARD_BREAK
    if has_guard and not full_damage:
        return TickHitOutcome.FeedbackKind.BLOCKED
    return TickHitOutcome.FeedbackKind.DAMAGED
