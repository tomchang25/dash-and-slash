# wave_scaling.gd
# Stateless formulas for infinite-wave enemy count, population cap, and per-tier stat scaling.
# Support count and population cap are tuned for tick-paced combat: wave size can grow without
# bound, but concurrent-alive enemies stay in the low 3-6 range so the board stays readable.
class_name WaveScaling
extends RefCounted

const SUPPORT_BASE_COUNT := 3
const SUPPORT_COUNT_WAVE_DIVISOR := 2

const MILESTONE_INTERVAL := 5

const POP_CAP_BASE := 3
const POP_CAP_WAVE_DIVISOR := 5
const POP_CAP_MIN := 3
const POP_CAP_MAX := 6

# -- First-pass calibration constants: playtest and retune against the target curve
# (average run ends ~wave 20, wave 30 is the practical ceiling). --
const HP_MULTIPLIER_PER_TIER := 0.35
const DAMAGE_MULTIPLIER_PER_TIER := 0.20
const DEFENSE_PER_TIER := 6.0

const EXPAND_LAND_AMOUNT := 10

const WAVE_TERRAIN_MUTATION_RELOCATE_COUNT := 2
const WAVE_TERRAIN_MUTATION_REMOVE_COUNT := 1

# == Common API ==


## Returns the support enemy count for wave_number (uncapped; the population cap
## governs how many are concurrently alive, not how many the wave asks for).
static func get_support_count(wave_number: int) -> int:
    return SUPPORT_BASE_COUNT + int(floor(float(wave_number) / SUPPORT_COUNT_WAVE_DIVISOR))


## Returns the milestone tier for wave_number (0 for waves 1-4, 1 for 5-9, ...).
static func get_tier(wave_number: int) -> int:
    return int(floor(float(wave_number) / MILESTONE_INTERVAL))


## Returns true when wave_number is a 5-wave milestone (5, 10, 15, ...).
static func is_milestone_wave(wave_number: int) -> bool:
    return wave_number > 0 and wave_number % MILESTONE_INTERVAL == 0


## Returns the concurrent-alive-enemy cap for wave_number, clamped to the low tick-world range.
static func get_population_cap(wave_number: int) -> int:
    return clampi(POP_CAP_BASE + int(floor(float(wave_number) / POP_CAP_WAVE_DIVISOR)), POP_CAP_MIN, POP_CAP_MAX)


## Returns the max_health multiplier applied to spawned enemies for wave_number's tier.
static func get_hp_multiplier(wave_number: int) -> float:
    return 1.0 + get_tier(wave_number) * HP_MULTIPLIER_PER_TIER


## Returns the outgoing-damage multiplier applied to spawned enemies for wave_number's tier.
static func get_damage_multiplier(wave_number: int) -> float:
    return 1.0 + get_tier(wave_number) * DAMAGE_MULTIPLIER_PER_TIER


## Returns the flat defense value applied to spawned enemies for wave_number's tier.
## Defense reduces incoming hp damage per EnemyHitResolver.apply_defense(); guard never scales.
static func get_defense(wave_number: int) -> float:
    return get_tier(wave_number) * DEFENSE_PER_TIER
