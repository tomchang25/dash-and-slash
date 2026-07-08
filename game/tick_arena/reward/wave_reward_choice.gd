# wave_reward_choice.gd
# Runtime owned-artifact value object representing one offered reward choice as at most one
# artifact pick applied at a given stack count: a single artifact at one stack for a normal Minor,
# Major, or curse offer, the same artifact at two stacks for a milestone `Minor x2` slot, or zero
# entries for the no-eligible-curse fallback.
class_name WaveRewardChoice
extends RefCounted

## Entries, one `{ "artifact": Artifact, "stacks": int }` dictionary per artifact this choice
## applies. Every production choice holds at most one entry; `entries` stays an array so a future
## multi-artifact choice shape does not require a value-object rewrite.
var entries: Array[Dictionary] = []

# == Lifecycle ==


func _init(init_entries: Array[Dictionary]) -> void:
    entries = init_entries.duplicate()

# == Common API ==


## Builds a single-artifact choice at the given stack count — the shape every normal Minor, Major,
## curse, and milestone `Minor x2` offer uses.
static func single(picked_artifact: Artifact, stacks: int = 1) -> WaveRewardChoice:
    var built: Array[Dictionary] = [{ "artifact": picked_artifact, "stacks": max(stacks, 1) }]
    return WaveRewardChoice.new(built)


## Builds a choice with no entries — the no-eligible-curse fallback shown as an explicit,
## still-confirmable card instead of silently skipping the milestone cost.
static func empty() -> WaveRewardChoice:
    var built: Array[Dictionary] = []
    return WaveRewardChoice.new(built)


## Returns the artifacts held by this choice's entries, in order.
func artifacts() -> Array[Artifact]:
    var result: Array[Artifact] = []
    for entry in entries:
        result.append(entry["artifact"])
    return result


## Returns this choice's single artifact, or null for the no-eligible-curse fallback. Card UI reads
## this instead of indexing into entries directly.
func artifact() -> Artifact:
    if entries.is_empty():
        return null
    return entries[0]["artifact"]


## Returns this choice's stack count, or 0 for the no-eligible-curse fallback.
func stack_count() -> int:
    if entries.is_empty():
        return 0
    return entries[0]["stacks"]


## Returns true when this choice has no artifact entries at all.
func is_empty() -> bool:
    return entries.is_empty()


## Registers each entry's artifact in the run build's owned-artifact registry, then applies its
## effect contributions. A rejected registration signals a programmer error, since is_eligible is
## the pre-offer filter that should have already excluded a conflicting or already-owned artifact.
func apply(context: WaveRewardContext) -> void:
    for entry in entries:
        var picked_artifact: Artifact = entry["artifact"]
        var stacks: int = entry["stacks"]
        if not context.run_build.acquire_artifact(picked_artifact, stacks):
            ToastManager.show_dev_error("WaveRewardChoice: %s rejected by RunBuild after passing is_eligible" % picked_artifact.id)
            continue
        picked_artifact.apply(context, stacks)


## Display title for the reward card: the single artifact's own name, or a dev-visible fallback
## label when a roll found nothing to offer. A milestone `Minor x2` choice keeps the same artifact
## title as its one-stack form; the stack count is communicated by the card's stack badge, not a
## second pseudo-artifact name.
func title() -> String:
    if entries.is_empty():
        return "None available"
    return entries[0]["artifact"].display_name


## Description body: the entry's stack-scaled effect line.
func description() -> String:
    if entries.is_empty():
        return "No eligible artifact could be rolled."
    var entry := entries[0]
    var picked_artifact: Artifact = entry["artifact"]
    var stacks: int = entry["stacks"]
    return picked_artifact.format_description(stacks)
