# run_build.gd
# Run-scoped reward store for channel contributions, owned artifacts, and class-specific Major triggers.
class_name RunBuild
extends RefCounted

const CH_NORMAL_ATTACK_DAMAGE := &"normal_attack_damage"
const CH_NORMAL_ATTACK_COOLDOWN := &"normal_attack_cooldown"
const CH_MOBILITY_ATTACK_DAMAGE := &"mobility_attack_damage"
const CH_DASH_COOLDOWN := &"dash_cooldown"
const CH_MOBILITY_RANGE := &"mobility_range"
const CH_MAX_HEALTH := &"max_health"
const CH_FUTURE_ENEMY_COUNT := &"future_enemy_count"
const CH_ENEMY_HEALTH_PRESSURE := &"enemy_health_pressure"
const CH_ENEMY_DAMAGE_PRESSURE := &"enemy_damage_pressure"
const CH_ENEMY_DEFENSE_PRESSURE := &"enemy_defense_pressure"
const CH_SPEED := &"speed"
const CH_MOBILITY_COOLDOWN := &"mobility_cooldown"

const TRIGGER_GUARD_SHREDDER := &"guard_shredder"
const TRIGGER_EXECUTION := &"execution"
const TRIGGER_CHAIN_DASH := &"chain_dash"

const LEGENDARY_CAP := 4

var _entries: Array[Dictionary] = []
var _owned_artifacts: Array[Dictionary] = []
var _mobility_triggers: Dictionary = { }

# == Common API ==


## Records a signed contribution on the given channel. Reductions pass a
## negative delta; the channel's total is the sum of every recorded delta.
func record(channel: StringName, delta: float) -> void:
    _entries.append({ "channel": channel, "delta": delta })


## Returns the summed delta recorded on the given channel, recomputed from
## the full entry list every call so a future replace-mode effect can
## supersede earlier entries without this API changing shape.
func total(channel: StringName) -> float:
    var sum := 0.0
    for entry in _entries:
        if entry["channel"] == channel:
            sum += entry["delta"]
    return sum


## Clears every recorded entry, the owned-artifact registry, and the Mobility-trigger set while
## preserving the active class, which belongs to TickArena rather than reward state.
func clear() -> void:
    _entries.clear()
    _owned_artifacts.clear()
    _mobility_triggers.clear()


## Registers an artifact pick in the owned-artifact registry: a fresh stackable pick is appended, a
## repeat stackable pick increments the existing entry's stacks, and a repeat unique pick is
## rejected. A fresh pick is also rejected when the legendary cap is full or its exclusivity group
## already has a member. This stays authoritative rather than trusting the caller's own pre-offer
## check, so a rejected acquire is observable instead of silently no-op'ing.
func acquire_artifact(artifact: Artifact, stacks: int = 1) -> bool:
    var index := _find_owned_index(artifact.id)
    if index != -1:
        if artifact.max_stacks <= 1:
            return false
        _owned_artifacts[index]["stacks"] += stacks
        return true
    if not can_acquire_artifact(artifact):
        return false
    _owned_artifacts.append({ "artifact": artifact, "stacks": stacks })
    return true


## Returns whether the given artifact could be freshly registered right now: no exclusivity
## conflict, and if it is legendary, the legendary cap has room. Does not check for an
## already-owned unique artifact of its own; callers that must reject re-offering an owned unique
## (such as Artifact.is_eligible()) pair this with has_artifact().
func can_acquire_artifact(artifact: Artifact) -> bool:
    if has_exclusivity_conflict(artifact.exclusivity_group):
        return false
    if artifact.rarity == Artifact.Rarity.LEGENDARY:
        return has_legendary_capacity()
    return true


## Returns whether the given artifact id is already registered in this run.
func has_artifact(id: StringName) -> bool:
    return _find_owned_index(id) != -1


## Returns whether the run-wide legendary cap still has room for another legendary artifact.
func has_legendary_capacity() -> bool:
    return legendary_count() < LEGENDARY_CAP


## Returns whether a non-empty exclusivity group already has a registered
## member. An empty group never conflicts.
func has_exclusivity_conflict(exclusivity_group: StringName) -> bool:
    if exclusivity_group == &"":
        return false
    for entry in _owned_artifacts:
        var owned: Artifact = entry["artifact"]
        if owned.exclusivity_group == exclusivity_group:
            return true
    return false


## Returns how many legendary-rarity artifacts are currently registered in this run.
func legendary_count() -> int:
    var count := 0
    for entry in _owned_artifacts:
        var owned: Artifact = entry["artifact"]
        if owned.rarity == Artifact.Rarity.LEGENDARY:
            count += 1
    return count


## Returns a copy of the owned-artifact registry, one `{ "artifact": Artifact, "stacks": int }`
## entry per distinct owned artifact. Read by the build inspection panel.
func get_owned_artifacts() -> Array[Dictionary]:
    return _owned_artifacts.duplicate()


## Returns whether the given class-Mobility artifact trigger is active for this run.
func has_mobility_trigger(trigger_id: StringName) -> bool:
    return bool(_mobility_triggers.get(trigger_id, false))


## Activates or deactivates one class-Mobility-triggered artifact effect by id. Real trigger effects
## call this from their own apply(); debug controls write through the same call so debug behavior
## stays representative of artifact behavior instead of a parallel scene-only flag.
func set_mobility_trigger(trigger_id: StringName, active: bool) -> void:
    if trigger_id != TRIGGER_GUARD_SHREDDER and trigger_id != TRIGGER_EXECUTION and trigger_id != TRIGGER_CHAIN_DASH:
        ToastManager.show_dev_error("RunBuild: unknown mobility trigger %s" % trigger_id)
        return
    _mobility_triggers[trigger_id] = active

# == Owned Artifacts ==


## Returns the registry index of the given artifact id, or -1 if it is not owned.
func _find_owned_index(id: StringName) -> int:
    for i in _owned_artifacts.size():
        var owned: Artifact = _owned_artifacts[i]["artifact"]
        if owned.id == id:
            return i
    return -1
