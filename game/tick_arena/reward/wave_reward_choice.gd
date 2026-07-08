# wave_reward_choice.gd
# Runtime owned-artifact value object representing one offered reward choice as a bundle of one or
# more artifact picks applied together: a single artifact for most cards, two distinct Minors for a
# `Minor x2` bundle, or zero entries for the no-eligible-curse fallback.
class_name WaveRewardChoice
extends RefCounted

## Bundle entries, one `{ "artifact": Artifact, "stacks": int }` dictionary per artifact this choice
## applies. Most choices hold exactly one entry; a `Minor x2` bundle holds two.
var entries: Array[Dictionary] = []

# == Lifecycle ==


func _init(init_entries: Array[Dictionary]) -> void:
    entries = init_entries.duplicate()

# == Common API ==


## Builds a single-artifact choice at the given stack count — the shape every normal Minor, Major,
## and curse offer uses.
static func single(artifact: Artifact, stacks: int = 1) -> WaveRewardChoice:
    var built: Array[Dictionary] = [{ "artifact": artifact, "stacks": max(stacks, 1) }]
    return WaveRewardChoice.new(built)


## Builds a bundle choice from one or more distinct artifacts, each applied at one stack — the
## `Minor x2` shape. Accepts fewer than two artifacts so a thin Minor pool degrades to a smaller
## bundle instead of fabricating a duplicate stack.
static func bundle(p_artifacts: Array[Artifact]) -> WaveRewardChoice:
    var built: Array[Dictionary] = []
    for artifact in p_artifacts:
        built.append({ "artifact": artifact, "stacks": 1 })
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


## Returns true when this choice has no artifact entries at all.
func is_empty() -> bool:
    return entries.is_empty()


## Registers each entry's artifact in the run build's owned-artifact registry, then applies its
## effect contributions. A rejected registration signals a programmer error, since is_eligible is
## the pre-offer filter that should have already excluded a conflicting or already-owned artifact
## one rejected entry does not stop the rest of the bundle from applying.
func apply(context: WaveRewardContext) -> void:
    for entry in entries:
        var artifact: Artifact = entry["artifact"]
        var stacks: int = entry["stacks"]
        if not context.run_build.acquire_artifact(artifact, stacks):
            ToastManager.show_dev_error("WaveRewardChoice: %s rejected by RunBuild after passing is_eligible" % artifact.id)
            continue
        artifact.apply(context, stacks)


## Display title for the reward card: the single artifact's own name, "Minor x2" for a two-artifact
## bundle, or a dev-visible fallback label when a roll found nothing to offer.
func title() -> String:
    if entries.is_empty():
        return "None available"
    if entries.size() == 1:
        var artifact: Artifact = entries[0]["artifact"]
        return artifact.display_name
    return "Minor x2"


## Multi-line description body: one formatted effect line per entry, prefixed with the artifact's
## name when the choice bundles more than one.
func description() -> String:
    if entries.is_empty():
        return "No eligible artifact could be rolled."
    if entries.size() == 1:
        return _format_effect(entries[0])
    var lines: Array[String] = []
    for entry in entries:
        var artifact: Artifact = entry["artifact"]
        lines.append("%s: %s" % [artifact.display_name, _format_effect(entry)])
    return "\n".join(lines)

# == Description ==


func _format_effect(entry: Dictionary) -> String:
    var artifact: Artifact = entry["artifact"]
    var stacks: int = entry["stacks"]
    var amount := artifact.magnitude * float(stacks)
    if is_equal_approx(amount, roundf(amount)):
        return artifact.description_template % int(amount)
    return artifact.description_template % amount
