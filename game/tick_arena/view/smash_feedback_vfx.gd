# smash_feedback_vfx.gd
# Temporary modular tween VFX helper for Smash windup and impact feedback. Owns the one-shot ephemeral
# tweens so the interim grey-box presentation can be replaced by real content later without chasing
# scattered one-off tweens elsewhere in the tick arena.
class_name SmashFeedbackVFX

const WINDUP_COLOR := Color(0.3, 0.9, 1.0, 0.85)
const IMPACT_COLOR := Color(0.85, 0.95, 1.0, 0.9)
const WINDUP_DURATION := 0.3
const IMPACT_DURATION := 0.35
const WINDUP_RADIUS := 20.0
const IMPACT_RADIUS := 30.0
const IMPACT_FRAGMENT_TRAVEL := 90.0
const IMPACT_FRAGMENT_COUNT := 8
const EFFECT_Z_INDEX := 40

# == Common API ==


## Pulsing ring at the player's position marking the start of the Smash windup.
static func play_windup(world_pos: Vector2, parent: Node) -> void:
    var effect_parent := _resolve_parent(parent)
    var ring := _make_ring(WINDUP_RADIUS, WINDUP_COLOR)
    ring.z_index = EFFECT_Z_INDEX
    # node-src: ephemeral
    effect_parent.add_child(ring)
    ring.global_position = world_pos

    var tw := ring.create_tween()
    tw.set_parallel()
    tw.tween_property(ring, "scale", Vector2(2.2, 2.2), WINDUP_DURATION).set_ease(Tween.EASE_OUT)
    tw.tween_property(ring, "modulate:a", 0.0, WINDUP_DURATION)
    tw.finished.connect(ring.queue_free, CONNECT_ONE_SHOT)


## Radial burst at the locked landing cell marking the Smash impact.
static func play_impact(world_pos: Vector2, parent: Node) -> void:
    var effect_parent := _resolve_parent(parent)
    var burst := _make_ring(IMPACT_RADIUS, IMPACT_COLOR)
    burst.z_index = EFFECT_Z_INDEX
    # node-src: ephemeral
    effect_parent.add_child(burst)
    burst.global_position = world_pos

    var tw := burst.create_tween()
    tw.set_parallel()
    tw.tween_property(burst, "scale", Vector2(3.0, 3.0), IMPACT_DURATION).set_ease(Tween.EASE_OUT)
    tw.tween_property(burst, "modulate:a", 0.0, IMPACT_DURATION)
    tw.finished.connect(burst.queue_free, CONNECT_ONE_SHOT)

    for i in range(IMPACT_FRAGMENT_COUNT):
        var frag := Line2D.new()
        frag.points = PackedVector2Array([Vector2.ZERO, Vector2(10.0, 0.0)])
        frag.width = 4.0
        frag.default_color = IMPACT_COLOR
        frag.z_index = EFFECT_Z_INDEX + 1
        var angle := TAU * float(i) / float(IMPACT_FRAGMENT_COUNT)
        frag.rotation = angle
        # node-src: ephemeral
        effect_parent.add_child(frag)
        frag.global_position = world_pos

        var ftw := frag.create_tween()
        ftw.set_parallel()
        ftw.tween_property(frag, "global_position", world_pos + Vector2.RIGHT.rotated(angle) * IMPACT_FRAGMENT_TRAVEL, IMPACT_DURATION)
        ftw.tween_property(frag, "modulate:a", 0.0, IMPACT_DURATION)
        ftw.finished.connect(frag.queue_free, CONNECT_ONE_SHOT)

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
