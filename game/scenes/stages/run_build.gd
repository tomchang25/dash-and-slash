# run_build.gd
# Run-scoped store of applied reward-effect contributions. Pure data: holds a
# signed-entry list per channel and projects each channel's total on read.
# Consumers (Player, WaveController) own their own base values and clamps
# this store owns no base values and applies no clamps of its own.
class_name RunBuild
extends RefCounted

const CH_NORMAL_ATTACK_DAMAGE := &"normal_attack_damage"
const CH_NORMAL_ATTACK_COOLDOWN := &"normal_attack_cooldown"
const CH_DASH_ATTACK_DAMAGE := &"dash_attack_damage"
const CH_DASH_COOLDOWN := &"dash_cooldown"
const CH_ATTACK_RANGE := &"attack_range"
const CH_DASH_RANGE := &"dash_range"
const CH_FUTURE_ENEMY_COUNT := &"future_enemy_count"

var _entries: Array[Dictionary] = []

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


## Clears every recorded entry. Not used on the production restart path
## (a fresh RunBuild is built per run) — provided for tests and in-place reset.
func clear() -> void:
    _entries.clear()
