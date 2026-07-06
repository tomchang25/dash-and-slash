# major_trigger_feedback_vfx.gd
# Temporary modular tween VFX helper for the mobility-slot-triggered Majors (Guard Shredder, Execution),
# fired from either Dash or Smash. Owns the one-shot ephemeral tweens so the interim grey-box
# presentation can be replaced by real content later without chasing scattered one-off tweens elsewhere
# in the tick arena.
class_name MajorTriggerFeedbackVFX

const SHREDDER_COLOR := Color(1.0, 0.85, 0.2, 0.9)
const SHREDDER_DURATION := 0.3
const SHREDDER_RADIUS := 26.0
const SHREDDER_SHARD_COUNT := 6
const SHREDDER_SHARD_TRAVEL := 60.0

const EXECUTION_COLOR := Color(0.85, 0.05, 0.15, 0.95)
const EXECUTION_DURATION := 0.4
const EXECUTION_RADIUS := 34.0

const EFFECT_Z_INDEX := 41

# == Common API ==


## Jagged shard burst marking Guard Shredder's instant guard break on a back-angle dash hit.
static func play_guard_shredder(world_pos: Vector2, parent: Node) -> void:
    var effect_parent := _resolve_parent(parent)
    var ring := _make_ring(SHREDDER_RADIUS, SHREDDER_COLOR)
    ring.z_index = EFFECT_Z_INDEX
    # node-src: ephemeral
    effect_parent.add_child(ring)
    ring.global_position = world_pos

    var tw := ring.create_tween()
    tw.set_parallel()
    tw.tween_property(ring, "scale", Vector2(2.4, 2.4), SHREDDER_DURATION).set_ease(Tween.EASE_OUT)
    tw.tween_property(ring, "modulate:a", 0.0, SHREDDER_DURATION)
    tw.finished.connect(ring.queue_free, CONNECT_ONE_SHOT)

    for i in range(SHREDDER_SHARD_COUNT):
        var shard := Line2D.new()
        shard.points = PackedVector2Array([Vector2.ZERO, Vector2(8.0, 0.0)])
        shard.width = 5.0
        shard.default_color = SHREDDER_COLOR
        shard.z_index = EFFECT_Z_INDEX + 1
        var angle := TAU * float(i) / float(SHREDDER_SHARD_COUNT)
        shard.rotation = angle
        # node-src: ephemeral
        effect_parent.add_child(shard)
        shard.global_position = world_pos

        var stw := shard.create_tween()
        stw.set_parallel()
        stw.tween_property(shard, "global_position", world_pos + Vector2.RIGHT.rotated(angle) * SHREDDER_SHARD_TRAVEL, SHREDDER_DURATION)
        stw.tween_property(shard, "modulate:a", 0.0, SHREDDER_DURATION)
        stw.finished.connect(shard.queue_free, CONNECT_ONE_SHOT)


## Collapsing dark burst marking Execution's instant kill on an already-staggered dash hit.
static func play_execution(world_pos: Vector2, parent: Node) -> void:
    var effect_parent := _resolve_parent(parent)
    var burst := _make_ring(EXECUTION_RADIUS, EXECUTION_COLOR)
    burst.z_index = EFFECT_Z_INDEX
    burst.scale = Vector2(1.6, 1.6)
    # node-src: ephemeral
    effect_parent.add_child(burst)
    burst.global_position = world_pos

    var tw := burst.create_tween()
    tw.set_parallel()
    tw.tween_property(burst, "scale", Vector2(0.1, 0.1), EXECUTION_DURATION).set_ease(Tween.EASE_IN)
    tw.tween_property(burst, "modulate:a", 0.0, EXECUTION_DURATION).set_delay(EXECUTION_DURATION * 0.6)
    tw.finished.connect(burst.queue_free, CONNECT_ONE_SHOT)

# == Internals ==


static func _make_ring(radius: float, color: Color) -> Polygon2D:
    var ring := Polygon2D.new()
    var points := PackedVector2Array()
    for i in range(16):
        var angle := TAU * float(i) / 16.0
        points.append(Vector2.RIGHT.rotated(angle) * radius)
    ring.polygon = points
    ring.color = color
    return ring


## Returns the parent of the node, or the node itself as fallback.
static func _resolve_parent(node: Node) -> Node:
    var p := node.get_parent()
    if p != null:
        return p
    return node
