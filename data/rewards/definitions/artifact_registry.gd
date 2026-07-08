# artifact_registry.gd
# Resource-backed catalog of authored reward artifacts: the read-only content source
# WaveRewardChoiceGenerator rolls and filters against. Exposes the full artifact list and id
# lookup, and validates authored data for null entries, empty ids, and duplicate ids. Owns no run
# state, RNG, cadence, or picked artifacts — that stays in WaveRewardChoiceGenerator and RunBuild.
class_name ArtifactRegistry
extends Resource

@export var artifacts: Array[Artifact] = []

# == Common API ==


## Returns every authored artifact in this registry, in authored order.
func get_artifacts() -> Array[Artifact]:
    return artifacts.duplicate()


## Returns the artifact with the given id, or null when no artifact in this registry has it. When
## validate() has reported a duplicate id, this returns the first authored match.
func get_by_id(id: StringName) -> Artifact:
    for artifact in artifacts:
        if artifact != null and artifact.id == id:
            return artifact
    return null


## Validates authored content and reports each problem as a developer error: a null entry, an
## empty id, or a duplicate id. Returns true when every entry is a distinct, non-null artifact with
## a non-empty id.
func validate() -> bool:
    var ok := true
    var seen_ids: Dictionary = { }
    for i in artifacts.size():
        var artifact := artifacts[i]
        if artifact == null:
            ToastManager.show_dev_error("ArtifactRegistry: artifact at index %d is null" % i)
            ok = false
            continue
        if artifact.id == &"":
            ToastManager.show_dev_error("ArtifactRegistry: artifact at index %d has an empty id" % i)
            ok = false
            continue
        if seen_ids.has(artifact.id):
            ToastManager.show_dev_error("ArtifactRegistry: duplicate artifact id '%s'" % artifact.id)
            ok = false
            continue
        seen_ids[artifact.id] = true
    return ok
