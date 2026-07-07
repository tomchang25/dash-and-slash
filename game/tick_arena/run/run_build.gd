# run_build.gd
# Run-scoped store of applied reward-effect contributions. Pure data: holds a
# signed-entry list per channel and projects each channel's total on read, plus
# a separate Major-effect record list enforcing the run-wide Major cap and
# per-group exclusivity, and a mobility-slot-triggered-effect flag set (Guard
# Shredder, Execution, Mobility Free Action) that the active mobility strike's
# resolution queries directly, regardless of whether the slot payload is Dash
# or Smash. Consumers (Player, TickPlayer, TickArena, WaveController) own their
# own base values and clamps; this store owns no base values and applies no
# clamps of its own.
class_name RunBuild
extends RefCounted

const CH_NORMAL_ATTACK_DAMAGE := &"normal_attack_damage"
const CH_NORMAL_ATTACK_COOLDOWN := &"normal_attack_cooldown"
const CH_MOBILITY_ATTACK_DAMAGE := &"mobility_attack_damage"
const CH_DASH_COOLDOWN := &"dash_cooldown"
const CH_ATTACK_RANGE := &"attack_range"
const CH_MOBILITY_RANGE := &"mobility_range"
const CH_MAX_HEALTH := &"max_health"
const CH_FUTURE_ENEMY_COUNT := &"future_enemy_count"
const CH_ENEMY_HEALTH_PRESSURE := &"enemy_health_pressure"
const CH_ENEMY_DAMAGE_PRESSURE := &"enemy_damage_pressure"
const CH_ENEMY_DEFENSE_PRESSURE := &"enemy_defense_pressure"
const CH_SPEED := &"speed"
const CH_MOBILITY_COOLDOWN := &"mobility_cooldown"

const PAYLOAD_DASH := &"dash"
const PAYLOAD_SMASH := &"smash"
const PAYLOAD_DEBUG_STUB := &"debug_stub"

const TRIGGER_GUARD_SHREDDER := &"guard_shredder"
const TRIGGER_EXECUTION := &"execution"
const TRIGGER_MOBILITY_FREE_ACTION := &"mobility_free_action"

const MAJOR_CAP := 4

var _entries: Array[Dictionary] = []
var _major_entries: Array[Dictionary] = []
var _mobility_payload_override := PAYLOAD_DASH
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


## Clears every recorded entry, the Major-effect record list, the mobility payload override (back
## to the Dash default), and the mobility-trigger set. This is the sole production restart path:
## the arena root constructs one RunBuild per arena scene and TickRunController.reset_run() clears
## it in place, so every collaborator keeps its original injected reference for the scene's lifetime.
func clear() -> void:
    _entries.clear()
    _major_entries.clear()
    _mobility_payload_override = PAYLOAD_DASH
    _mobility_triggers.clear()


## Returns the active mobility-slot payload. Dash is the default when no Major has replaced the slot.
func get_mobility_payload() -> StringName:
    return _mobility_payload_override


## Debug/prototype seam for Major payload replacement; production rewards should call this through their effect application path.
func set_mobility_payload_override(payload: StringName) -> void:
    if payload != PAYLOAD_DASH and payload != PAYLOAD_SMASH and payload != PAYLOAD_DEBUG_STUB:
        ToastManager.show_dev_error("RunBuild: unknown mobility payload %s" % payload)
        return
    _mobility_payload_override = payload


## Registers a Major effect if the store has capacity, the same effect id is not already
## registered, and there is no exclusivity-group conflict; returns false without registering
## otherwise. This stays authoritative rather than trusting the caller's own pre-offer check, so a
## rejected add is observable instead of silently no-op'ing.
func add_major(effect_id: String, exclusivity_group: String) -> bool:
    if has_major(effect_id) or not can_add_major(exclusivity_group):
        return false
    _major_entries.append({ "effect_id": effect_id, "exclusivity_group": exclusivity_group })
    return true


## Returns whether another Major could be registered right now: the cap has
## room and, if the group is non-empty, no existing member shares it. Does not check for an
## already-registered effect id of its own; callers that must reject re-offering the same effect
## (such as MajorEffect.is_applicable()) pair this with has_major().
func can_add_major(exclusivity_group: String) -> bool:
    return has_major_capacity() and not has_major_conflict(exclusivity_group)


## Returns whether the given Major effect id is already registered in this run. A Major with an
## empty exclusivity group (Guard Shredder, Execution) has no group conflict to fall back on, so
## this is the only guard against the same effect being offered or applied a second time.
func has_major(effect_id: String) -> bool:
    for entry in _major_entries:
        if entry["effect_id"] == effect_id:
            return true
    return false


## Returns whether the run-wide Major cap still has room for another entry.
func has_major_capacity() -> bool:
    return major_count() < MAJOR_CAP


## Returns whether a non-empty exclusivity group already has a registered
## member. An empty group never conflicts.
func has_major_conflict(exclusivity_group: String) -> bool:
    if exclusivity_group == "":
        return false
    for entry in _major_entries:
        if entry["exclusivity_group"] == exclusivity_group:
            return true
    return false


## Returns how many Major effects are currently registered in this run.
func major_count() -> int:
    return _major_entries.size()


## Returns whether the given mobility-slot-triggered Major effect (Guard Shredder, Execution,
## Mobility Free Action) is currently active. The active mobility strike's resolution reads this
## directly instead of forking per-effect code paths per payload, so the same trigger fires whether
## the slot payload is Dash or Smash.
func has_mobility_trigger(trigger_id: StringName) -> bool:
    return bool(_mobility_triggers.get(trigger_id, false))


## Activates or deactivates one mobility-slot-triggered Major effect by id. Real Major effects call
## this from their own apply(); debug controls write through the same call so debug behavior stays
## representative of perk behavior instead of a parallel scene-only flag.
func set_mobility_trigger(trigger_id: StringName, active: bool) -> void:
    if trigger_id != TRIGGER_GUARD_SHREDDER and trigger_id != TRIGGER_EXECUTION and trigger_id != TRIGGER_MOBILITY_FREE_ACTION:
        ToastManager.show_dev_error("RunBuild: unknown mobility trigger %s" % trigger_id)
        return
    _mobility_triggers[trigger_id] = active
