# wave_reward_choice_generator.gd
# Pure reward-choice picker that rolls distinct eligible artifacts of a requested kind.
class_name WaveRewardChoiceGenerator
extends RefCounted

## Which artifact pool an offer draws from. Kind is derived from Artifact data (rarity, is_curse),
## not stored on the artifact itself: Minor is common and not a curse, Major is legendary, curse is
## any artifact with is_curse set.
enum RewardKind {
    MINOR,
    MAJOR,
    CURSE,
}

## Exclusivity-group id shared by every mobility-slot payload replacement (Smash today, the future
## Chain Dash), since only one can be active at a time.
const SMASH_EXCLUSIVITY_GROUP := &"mobility_slot_replacement"

var _rng: RandomNumberGenerator
var _artifacts: Array[Artifact] = []

# == Lifecycle ==


func _init(rng: RandomNumberGenerator = null) -> void:
    _rng = rng if rng != null else RandomNumberGenerator.new()
    _rng.randomize()
    _artifacts = _make_default_artifacts()

# == Common API ==


## Returns up to count distinct, eligible artifacts of the given kind as offered choices at one
## stack each. Returns fewer than count if the eligible pool is smaller than count — callers must
## not assume a full offer.
func roll(kind: RewardKind, count: int, wave_number: int, context: WaveRewardContext) -> Array[WaveRewardChoice]:
    var pool := _eligible_artifacts(kind, wave_number, context)
    _shuffle(pool)
    var choices: Array[WaveRewardChoice] = []
    for artifact in pool.slice(0, count):
        choices.append(WaveRewardChoice.single(artifact, 1))
    return choices

# == Pool Filtering ==


func _eligible_artifacts(kind: RewardKind, wave_number: int, context: WaveRewardContext) -> Array[Artifact]:
    var eligible: Array[Artifact] = []
    for artifact in _artifacts:
        if _kind_of(artifact) != kind:
            continue
        if wave_number < artifact.min_wave:
            continue
        if not artifact.is_eligible(context):
            continue
        eligible.append(artifact)
    return eligible


func _kind_of(artifact: Artifact) -> RewardKind:
    if artifact.is_curse:
        return RewardKind.CURSE
    if artifact.rarity == Artifact.Rarity.LEGENDARY:
        return RewardKind.MAJOR
    return RewardKind.MINOR


func _shuffle(pool: Array[Artifact]) -> void:
    for i in range(pool.size() - 1, 0, -1):
        var j := _rng.randi_range(0, i)
        var swap := pool[i]
        pool[i] = pool[j]
        pool[j] = swap

# == Artifact Pool ==


func _make_default_artifacts() -> Array[Artifact]:
    return [
        Artifact.new(
            &"future_enemy",
            "Raise Pressure",
            "+%d future enemy",
            Artifact.Rarity.COMMON,
            4,
            &"",
            true,
            1,
            1.0,
            [ChannelArtifactEffect.new(RunBuild.CH_FUTURE_ENEMY_COUNT, 1.0)],
        ),
        Artifact.new(
            &"attack_up",
            "Sharpened Edge",
            "+%d normal attack damage",
            Artifact.Rarity.COMMON,
            3,
            &"",
            false,
            1,
            10.0,
            [ChannelArtifactEffect.new(RunBuild.CH_NORMAL_ATTACK_DAMAGE, 10.0)],
        ),
        Artifact.new(
            &"speed_up",
            "Fleet Step",
            "+%d Speed",
            Artifact.Rarity.COMMON,
            5,
            &"",
            false,
            1,
            1.0,
            [ChannelArtifactEffect.new(RunBuild.CH_SPEED, 1.0)],
        ),
        Artifact.new(
            &"dash_attack_up",
            "Impact Dash",
            "+%d dash attack damage",
            Artifact.Rarity.COMMON,
            3,
            &"",
            false,
            1,
            20.0,
            [ChannelArtifactEffect.new(RunBuild.CH_MOBILITY_ATTACK_DAMAGE, 20.0)],
        ),
        Artifact.new(
            &"mobility_cooldown_down",
            "Light Footwork",
            "-%d mobility cooldown (ticks)",
            Artifact.Rarity.COMMON,
            3,
            &"",
            false,
            1,
            1.0,
            [ChannelArtifactEffect.new(RunBuild.CH_MOBILITY_COOLDOWN, 1.0)],
        ),
        Artifact.new(
            &"attack_range_up",
            "Longer Reach",
            "+%d%% attack range",
            Artifact.Rarity.COMMON,
            3,
            &"",
            false,
            1,
            10.0,
            [ChannelArtifactEffect.new(RunBuild.CH_ATTACK_RANGE, 10.0)],
        ),
        Artifact.new(
            &"dash_range_up",
            "Longer Dash",
            "+%d%% dash range",
            Artifact.Rarity.COMMON,
            3,
            &"",
            false,
            1,
            10.0,
            [ChannelArtifactEffect.new(RunBuild.CH_MOBILITY_RANGE, 10.0)],
        ),
        Artifact.new(
            &"max_health_up",
            "Vital Spark",
            "+%d max health",
            Artifact.Rarity.COMMON,
            2,
            &"",
            false,
            1,
            20.0,
            [ChannelArtifactEffect.new(RunBuild.CH_MAX_HEALTH, 20.0)],
        ),
        Artifact.new(
            &"enemy_health_pressure",
            "Enemy Vitality",
            "+%d%% future enemy health",
            Artifact.Rarity.COMMON,
            3,
            &"",
            true,
            1,
            5.0,
            [ChannelArtifactEffect.new(RunBuild.CH_ENEMY_HEALTH_PRESSURE, 5.0, 0.01)],
        ),
        Artifact.new(
            &"enemy_damage_pressure",
            "Enemy Ferocity",
            "+%d%% future enemy damage",
            Artifact.Rarity.COMMON,
            3,
            &"",
            true,
            1,
            5.0,
            [ChannelArtifactEffect.new(RunBuild.CH_ENEMY_DAMAGE_PRESSURE, 5.0, 0.01)],
        ),
        Artifact.new(
            &"enemy_defense_pressure",
            "Enemy Armor",
            "+%d future enemy defense",
            Artifact.Rarity.COMMON,
            3,
            &"",
            true,
            1,
            3.0,
            [ChannelArtifactEffect.new(RunBuild.CH_ENEMY_DEFENSE_PRESSURE, 3.0)],
        ),
        Artifact.new(
            &"smash",
            "Smash",
            "Replace Dash with an area leap-and-slam (%d)",
            Artifact.Rarity.LEGENDARY,
            1,
            SMASH_EXCLUSIVITY_GROUP,
            false,
            2,
            1.0,
            [PayloadArtifactEffect.new(RunBuild.PAYLOAD_SMASH)],
        ),
        Artifact.new(
            &"guard_shredder",
            "Guard Shredder",
            "Back-angle dash hits break guard instantly (%d)",
            Artifact.Rarity.LEGENDARY,
            1,
            &"",
            false,
            2,
            1.0,
            [TriggerArtifactEffect.new(RunBuild.TRIGGER_GUARD_SHREDDER)],
        ),
        Artifact.new(
            &"execution",
            "Execution",
            "Dash hits on staggered targets kill instantly (%d)",
            Artifact.Rarity.LEGENDARY,
            1,
            &"",
            false,
            2,
            1.0,
            [TriggerArtifactEffect.new(RunBuild.TRIGGER_EXECUTION)],
        ),
        Artifact.new(
            &"mobility_free_action",
            "Flowing Strike",
            "Kill, guard-break, or back-angle mobility strikes skip world time (%d)",
            Artifact.Rarity.LEGENDARY,
            1,
            &"",
            false,
            2,
            1.0,
            [TriggerArtifactEffect.new(RunBuild.TRIGGER_MOBILITY_FREE_ACTION)],
        ),
    ]
