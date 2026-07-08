# wave_reward_choice_generator.gd
# Pure reward-choice picker that rolls distinct eligible artifacts of a requested kind from an
# injected ArtifactRegistry catalog. Never authors artifact content itself.
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
var _registry: ArtifactRegistry

# == Lifecycle ==


## Constructs the generator against an injected content registry. A null registry is a
## developer-visible error: the generator falls back to an empty registry rather than hardcoded
## artifact content, so a missing catalog reads as "no eligible artifacts" instead of a crash.
func _init(registry: ArtifactRegistry, rng: RandomNumberGenerator = null) -> void:
    if registry == null:
        ToastManager.show_dev_error("WaveRewardChoiceGenerator: constructed with a null ArtifactRegistry")
        registry = ArtifactRegistry.new()
    _registry = registry
    _rng = rng if rng != null else RandomNumberGenerator.new()
    _rng.randomize()

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
    for artifact in _registry.get_artifacts():
        if artifact == null:
            continue
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
