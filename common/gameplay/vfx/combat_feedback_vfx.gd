# combat_feedback_vfx.gd
# Static utility for one-shot generated combat feedback effects (shielded hit, guard break, full damage, charge wind, dash streak).
class_name CombatFeedbackVFX

enum WindupStyle {
    CHARGE,
    TILE,
}

const SHIELD_COLOR := Color(0.25, 0.65, 1.0, 1.0)
const GUARD_BREAK_FLASH_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const GUARD_BREAK_FRAGMENT_COLOR := Color(0.4, 0.7, 1.0, 0.95)
const FULL_DAMAGE_COLOR := Color(1.0, 0.25, 0.08, 0.95)
const WIND_COLOR := Color(0.95, 1.0, 1.0, 0.95)
const STREAK_COLOR := Color(0.75, 0.9, 1.0, 0.85)
const CHARGE_CORE_COLOR := Color(1.0, 1.0, 1.0, 0.9)
const TILE_WINDUP_COLOR := Color(1.0, 0.85, 0.35, 0.82)

const SHIELDED_DURATION := 0.3
const GUARD_BREAK_DURATION := 0.5
const FULL_DAMAGE_DURATION := 0.4
const WIND_DURATION := 0.48
const STREAK_DURATION := 0.22
const WINDUP_PULSE_DURATION := 0.36
const WINDUP_PULSE_INTERVAL := 0.18

const SHIELDED_SIZE := 24.0
const GUARD_BREAK_SIZE := 34.0
const FULL_DAMAGE_SIZE := 20.0
const WIND_LENGTH := 82.0
const WIND_WIDTH := 46.0
const STREAK_LENGTH := 78.0
const WINDUP_LENGTH := 62.0
const WINDUP_WIDTH := 26.0
const EFFECT_Z_INDEX := 40

const WINDUP_STYLE_META := &"windup_style"
const WINDUP_FORWARD_META := &"windup_forward"


## Blue shield spark at the enemy position indicating a guarded hit.
static func play_shielded_hit(world_pos: Vector2, _angle_from_source: float, parent: Node) -> void:
    var effect_parent := _resolve_parent(parent)
    var vfx := Polygon2D.new()
    vfx.polygon = _make_diamond(SHIELDED_SIZE)
    vfx.color = SHIELD_COLOR
    vfx.z_index = EFFECT_Z_INDEX
    # node-src: ephemeral
    effect_parent.add_child(vfx)
    vfx.global_position = world_pos

    var tw := vfx.create_tween()
    tw.set_parallel()
    tw.tween_property(vfx, "scale", Vector2(1.5, 1.5), SHIELDED_DURATION).set_ease(Tween.EASE_OUT)
    tw.tween_property(vfx, "modulate:a", 0.0, SHIELDED_DURATION)
    tw.finished.connect(vfx.queue_free, CONNECT_ONE_SHOT)


## White flash burst with radiating blue fragments indicating guard break.
static func play_guard_break(world_pos: Vector2, parent: Node) -> void:
    var effect_parent := _resolve_parent(parent)

    var flash := Polygon2D.new()
    flash.polygon = _make_diamond(GUARD_BREAK_SIZE * 0.5)
    flash.color = GUARD_BREAK_FLASH_COLOR
    flash.z_index = EFFECT_Z_INDEX + 1
    # node-src: ephemeral
    effect_parent.add_child(flash)
    flash.global_position = world_pos

    var tw := flash.create_tween()
    tw.set_parallel()
    tw.tween_property(flash, "scale", Vector2(2.5, 2.5), GUARD_BREAK_DURATION).set_ease(Tween.EASE_OUT)
    tw.tween_property(flash, "modulate:a", 0.0, GUARD_BREAK_DURATION)
    tw.finished.connect(flash.queue_free, CONNECT_ONE_SHOT)

    for i in range(6):
        var frag := Line2D.new()
        frag.points = PackedVector2Array([Vector2.ZERO, Vector2(8.0, 0.0)])
        frag.width = 4.0
        frag.default_color = GUARD_BREAK_FRAGMENT_COLOR
        frag.z_index = EFFECT_Z_INDEX + 2
        var angle := TAU * float(i) / 6.0
        frag.rotation = angle
        # node-src: ephemeral
        effect_parent.add_child(frag)
        frag.global_position = world_pos

        var ftw := frag.create_tween()
        ftw.set_parallel()
        ftw.tween_property(frag, "global_position", world_pos + Vector2.RIGHT.rotated(angle) * 34.0, GUARD_BREAK_DURATION)
        ftw.tween_property(frag, "modulate:a", 0.0, GUARD_BREAK_DURATION)
        ftw.finished.connect(frag.queue_free, CONNECT_ONE_SHOT)


## Red burst with radiating fragments indicating full unguarded damage.
static func play_full_damage(world_pos: Vector2, parent: Node) -> void:
    var effect_parent := _resolve_parent(parent)

    var burst := Polygon2D.new()
    burst.polygon = _make_diamond(FULL_DAMAGE_SIZE)
    burst.color = FULL_DAMAGE_COLOR
    burst.z_index = EFFECT_Z_INDEX
    # node-src: ephemeral
    effect_parent.add_child(burst)
    burst.global_position = world_pos

    var tw := burst.create_tween()
    tw.set_parallel()
    tw.tween_property(burst, "scale", Vector2(2.0, 2.0), FULL_DAMAGE_DURATION).set_ease(Tween.EASE_OUT)
    tw.tween_property(burst, "modulate:a", 0.0, FULL_DAMAGE_DURATION)
    tw.finished.connect(burst.queue_free, CONNECT_ONE_SHOT)

    for i in range(4):
        var frag := Polygon2D.new()
        frag.polygon = PackedVector2Array([Vector2.ZERO, Vector2(4.0, -3.0), Vector2(8.0, 0.0), Vector2(4.0, 3.0)])
        frag.color = FULL_DAMAGE_COLOR
        frag.z_index = EFFECT_Z_INDEX + 1
        var angle := TAU * float(i) / 4.0 + randf_range(-0.3, 0.3)
        frag.rotation = angle
        # node-src: ephemeral
        effect_parent.add_child(frag)
        frag.global_position = world_pos

        var ftw := frag.create_tween()
        ftw.set_parallel()
        ftw.tween_property(frag, "global_position", world_pos + Vector2.RIGHT.rotated(angle) * 26.0, FULL_DAMAGE_DURATION)
        ftw.tween_property(frag, "modulate:a", 0.0, FULL_DAMAGE_DURATION)
        ftw.finished.connect(frag.queue_free, CONNECT_ONE_SHOT)


## Starts a reusable telegraph windup loop and returns the spawned handle.
static func start_attack_windup_loop(world_pos: Vector2, facing: Vector2, parent: Node, style: int = WindupStyle.TILE) -> Node2D:
    if facing == Vector2.ZERO:
        return null
    var effect_parent := _resolve_parent(parent)
    var loop := Node2D.new()
    loop.z_index = EFFECT_Z_INDEX - 2
    loop.set_meta(WINDUP_STYLE_META, style)
    loop.set_meta(WINDUP_FORWARD_META, facing.normalized())
    # node-src: ephemeral
    effect_parent.add_child(loop)
    loop.global_position = world_pos

    var timer := Timer.new()
    timer.wait_time = WINDUP_PULSE_INTERVAL
    timer.timeout.connect(_spawn_windup_pulse.bind(loop))
    # node-src: ephemeral
    loop.add_child(timer)
    timer.start()
    _spawn_windup_pulse(loop)
    return loop


## Stops a reusable telegraph windup loop returned by start_attack_windup_loop().
static func stop_loop(loop: Node) -> void:
    if loop != null and is_instance_valid(loop):
        loop.queue_free()


## Forward wind slash at the enemy front indicating charge start.
static func play_charge_start(world_pos: Vector2, facing: Vector2, parent: Node) -> void:
    if facing == Vector2.ZERO:
        return
    var effect_parent := _resolve_parent(parent)
    var forward := facing.normalized()
    var side := forward.orthogonal()

    var slash := Polygon2D.new()
    slash.polygon = PackedVector2Array(
        [
            Vector2(-WIND_LENGTH * 0.25, -WIND_WIDTH * 0.5),
            Vector2(WIND_LENGTH * 0.9, 0.0),
            Vector2(-WIND_LENGTH * 0.25, WIND_WIDTH * 0.5),
            Vector2(WIND_LENGTH * 0.1, 0.0),
        ],
    )
    slash.color = WIND_COLOR
    slash.z_index = EFFECT_Z_INDEX
    slash.scale = Vector2(0.65, 0.75)
    slash.rotation = forward.angle()
    # node-src: ephemeral
    effect_parent.add_child(slash)
    slash.global_position = world_pos + forward * 30.0

    var tw := slash.create_tween()
    tw.set_parallel()
    tw.tween_property(slash, "global_position", world_pos + forward * 70.0, WIND_DURATION).set_ease(Tween.EASE_OUT)
    tw.tween_property(slash, "scale", Vector2(1.25, 1.05), WIND_DURATION)
    tw.tween_property(slash, "modulate:a", 0.0, WIND_DURATION)
    tw.finished.connect(slash.queue_free, CONNECT_ONE_SHOT)

    for offset in [-18.0, 18.0]:
        var line := Line2D.new()
        line.width = 7.0
        line.default_color = WIND_COLOR
        line.z_index = EFFECT_Z_INDEX - 1
        line.points = PackedVector2Array(
            [
                -forward * 14.0 + side * offset,
                forward * 74.0 + side * offset * 0.45,
            ],
        )
        # node-src: ephemeral
        effect_parent.add_child(line)
        line.global_position = world_pos

        var ltw := line.create_tween()
        ltw.set_parallel()
        ltw.tween_property(line, "global_position", line.global_position + forward * 28.0, WIND_DURATION)
        ltw.tween_property(line, "modulate:a", 0.0, WIND_DURATION)
        ltw.finished.connect(line.queue_free, CONNECT_ONE_SHOT)


## Short dash streak at the current position indicating active charge movement.
static func play_charge_streak(world_pos: Vector2, direction: Vector2, parent: Node) -> void:
    if direction == Vector2.ZERO:
        return
    var effect_parent := _resolve_parent(parent)
    var forward := direction.normalized()
    var side := forward.orthogonal()

    for offset in [-14.0, 0.0, 14.0]:
        var streak := Line2D.new()
        streak.width = 8.0 if offset == 0.0 else 5.0
        streak.default_color = CHARGE_CORE_COLOR if offset == 0.0 else STREAK_COLOR
        streak.z_index = EFFECT_Z_INDEX - 1
        streak.points = PackedVector2Array(
            [
                -forward * 10.0 + side * offset,
                -forward * STREAK_LENGTH + side * offset * 1.25,
            ],
        )
        # node-src: ephemeral
        effect_parent.add_child(streak)
        streak.global_position = world_pos

        var tw := streak.create_tween()
        tw.set_parallel()
        tw.tween_property(streak, "width", 1.0, STREAK_DURATION)
        tw.tween_property(streak, "global_position", streak.global_position - forward * 28.0, STREAK_DURATION)
        tw.tween_property(streak, "modulate:a", 0.0, STREAK_DURATION)
        tw.finished.connect(streak.queue_free, CONNECT_ONE_SHOT)


## Returns the parent of the node, or the node itself as fallback.
static func _resolve_parent(node: Node) -> Node:
    var p := node.get_parent()
    if p != null:
        return p
    return node


## Spawns one pulse for an active windup loop according to the loop style metadata.
static func _spawn_windup_pulse(loop: Node2D) -> void:
    if loop == null or not is_instance_valid(loop):
        return
    var style := int(loop.get_meta(WINDUP_STYLE_META, WindupStyle.TILE))
    var forward: Vector2 = loop.get_meta(WINDUP_FORWARD_META, Vector2.RIGHT)
    _spawn_directional_windup_pulse(loop, forward.normalized(), style)


## Spawns a directional windup pulse for charge and tile telegraphs.
static func _spawn_directional_windup_pulse(loop: Node2D, forward: Vector2, style: int) -> void:
    if forward == Vector2.ZERO:
        return
    var side := forward.orthogonal()
    var color := WIND_COLOR if style == WindupStyle.CHARGE else TILE_WINDUP_COLOR
    var line_offsets := [-WINDUP_WIDTH * 0.5, 0.0, WINDUP_WIDTH * 0.5]

    for offset in line_offsets:
        var line := Line2D.new()
        line.width = 5.0 if offset == 0.0 else 3.0
        line.default_color = color
        line.z_index = EFFECT_Z_INDEX - 2
        line.points = PackedVector2Array(
            [
                -forward * WINDUP_LENGTH * 0.4 + side * offset,
                forward * WINDUP_LENGTH * 0.55 + side * offset * 0.45,
            ],
        )
        # node-src: ephemeral
        loop.add_child(line)

        var tween := line.create_tween()
        tween.set_parallel()
        tween.tween_property(line, "position", forward * 18.0, WINDUP_PULSE_DURATION)
        tween.tween_property(line, "modulate:a", 0.0, WINDUP_PULSE_DURATION)
        tween.finished.connect(line.queue_free, CONNECT_ONE_SHOT)


## Returns a diamond polygon centered at the origin with the given size.
static func _make_diamond(size: float) -> PackedVector2Array:
    var h := size * 0.5
    return PackedVector2Array(
        [
            Vector2(0.0, -h),
            Vector2(h, 0.0),
            Vector2(0.0, h),
            Vector2(-h, 0.0),
        ],
    )
