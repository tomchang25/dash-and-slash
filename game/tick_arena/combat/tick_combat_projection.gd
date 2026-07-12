# tick_combat_projection.gd
# Static RunBuild projection helpers for tick combat damage, range, cooldown, and mobility triggers.
class_name TickCombatProjection
extends RefCounted

# == Common API ==

## Projects normal attack's base damage through the run's Normal Attack Damage bonus total.
static func normal_attack_damage(run_build: RunBuild) -> float:
    return TickCombatRules.normal_attack_damage(run_build.total(RunBuild.CH_NORMAL_ATTACK_DAMAGE))


## Projects a class Mobility's base damage (Dash or Smash) through the run's Mobility Attack Damage bonus total.
static func mobility_attack_damage(run_build: RunBuild, base_damage: float) -> float:
    return TickCombatRules.mobility_attack_damage(base_damage, run_build.total(RunBuild.CH_MOBILITY_ATTACK_DAMAGE))


## Projects a class Mobility's base range (in cells, Dash or Smash) through the run's flat Mobility Range cell bonus.
static func mobility_range_cells(run_build: RunBuild, base_range: int) -> int:
    return TickCombatRules.mobility_range_cells(base_range, run_build.total(RunBuild.CH_MOBILITY_RANGE))


## Projects a class Mobility's base cooldown through the run's Mobility Cooldown reduction, floored at 1 tick.
static func mobility_cooldown_ticks(run_build: RunBuild, base_ticks: int) -> int:
    return TickCombatRules.mobility_cooldown_ticks(base_ticks, int(run_build.total(RunBuild.CH_MOBILITY_COOLDOWN)))


## Returns whether Dash should trigger Guard Shredder.
static func has_dash_guard_shredder(run_build: RunBuild) -> bool:
    return run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER)


## Returns whether Dash should trigger Execution.
static func has_dash_execution(run_build: RunBuild) -> bool:
    return run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION)


## Returns whether Chain Dash is active for this run: a qualifying Dash hit clears Dash cooldown and
## prepares the Speed meter as a ready follow-up free action.
static func has_chain_dash(run_build: RunBuild) -> bool:
    return run_build.has_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH)


## Returns the stagger-burst multiplier shared by committed and previewed class-Mobility strikes.
static func mobility_stagger_burst_multiplier() -> float:
    return TickCombatRules.STAGGER_MOBILITY_MULTIPLIER
