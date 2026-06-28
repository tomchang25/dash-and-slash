# puff_enemy_puff_state.gd
# Zone-denial puff state. The enemy stops, expands to match its puff hitbox,
# keeps the area active while the target stays in range, then shrinks back to IDLE.
extends EnemyState

const PUFF_EXPAND_SCALE := 3.0
const PUFF_EXPAND_DURATION := 0.12
const PUFF_SHRINK_DURATION := 0.18
const PUFF_COLOR := Color(1.0, 0.5, 0.5, 1.0)
const STAR_INNER_RADIUS_RATIO := 0.4
const STAR_POINTS := 21

var _minimum_timer: Timer
var _recheck_timer: Timer
var _puff_tween: Tween
var _shrink_tween: Tween
var _original_scale: Vector2
var _original_color: Color
var _original_polygon: PackedVector2Array
var _shrink_vfx_started: bool = false


func _init() -> void:
    state_id = EnemyStateId.PUFF


func _enter() -> void:
    var puff_enemy := enemy as PuffEnemy
    puff_enemy.begin_puff_action()
    _capture_original_body_state(puff_enemy)
    _shrink_vfx_started = false
    _ensure_timers(puff_enemy)
    _begin_puff(puff_enemy)


func _exit() -> void:
    var puff_enemy := enemy as PuffEnemy
    puff_enemy.enable_puff_hitbox(false)
    _kill_tweens()
    _stop_timers()
    _reset_body(puff_enemy)


func _capture_original_body_state(puff: PuffEnemy) -> void:
    var body: Polygon2D = puff.get_body()
    if body == null:
        _original_scale = Vector2.ONE
        _original_color = Color.WHITE
        _original_polygon = PackedVector2Array()
        return
    _original_scale = body.scale
    _original_color = body.color
    _original_polygon = body.polygon


func _ensure_timers(puff: PuffEnemy) -> void:
    if _minimum_timer == null:
        _minimum_timer = Timer.new()
        _minimum_timer.one_shot = true
        _minimum_timer.timeout.connect(_on_minimum_timeout)
        puff.add_child(_minimum_timer)

    if _recheck_timer == null:
        _recheck_timer = Timer.new()
        _recheck_timer.one_shot = true
        _recheck_timer.timeout.connect(_on_recheck_timeout)
        puff.add_child(_recheck_timer)


func _begin_puff(puff: PuffEnemy) -> void:
    _swap_to_star_polygon(puff)
    _play_expand_vfx(puff)
    _minimum_timer.start(puff.get_puff_minimum_duration())


func _on_minimum_timeout() -> void:
    _try_shrink_or_recheck()


func _on_recheck_timeout() -> void:
    _try_shrink_or_recheck()


func _try_shrink_or_recheck() -> void:
    var puff := enemy as PuffEnemy
    if not puff.has_target() or not puff.is_target_in_puff_range():
        _start_shrink_and_idle(puff)
        return
    _recheck_timer.start(puff.get_puff_recheck_interval())


func _start_shrink_and_idle(puff: PuffEnemy) -> void:
    if _shrink_vfx_started:
        return
    _shrink_vfx_started = true
    puff.enable_puff_hitbox(false)
    _play_shrink_vfx(puff)
    if _shrink_tween == null:
        change_state(EnemyStateId.IDLE)
        return
    _shrink_tween.finished.connect(_on_shrink_finished, CONNECT_ONE_SHOT)


func _on_shrink_finished() -> void:
    if _locked:
        return
    change_state(EnemyStateId.IDLE)


func _play_expand_vfx(puff: PuffEnemy) -> void:
    _kill_tweens()
    var body: Polygon2D = puff.get_body()
    if body == null:
        return

    _puff_tween = puff.create_tween()
    _puff_tween.set_parallel()
    _puff_tween.tween_property(body, "scale", _original_scale * PUFF_EXPAND_SCALE, PUFF_EXPAND_DURATION)
    _puff_tween.tween_property(body, "color", PUFF_COLOR, PUFF_EXPAND_DURATION)
    _puff_tween.finished.connect(_on_expand_finished, CONNECT_ONE_SHOT)


func _on_expand_finished() -> void:
    if _locked:
        return
    var puff := enemy as PuffEnemy
    puff.enable_puff_hitbox(true)


func _play_shrink_vfx(puff: PuffEnemy) -> void:
    var body: Polygon2D = puff.get_body()
    if body == null:
        return

    _shrink_tween = puff.create_tween()
    _shrink_tween.set_parallel()
    _shrink_tween.tween_property(body, "scale", _original_scale, PUFF_SHRINK_DURATION)
    _shrink_tween.tween_property(body, "color", _original_color, PUFF_SHRINK_DURATION)


func _swap_to_star_polygon(puff: PuffEnemy) -> void:
    var body: Polygon2D = puff.get_body()
    if body == null:
        return
    var outer_radius := puff.get_puff_hitbox_radius() / PUFF_EXPAND_SCALE
    var inner_radius := outer_radius * STAR_INNER_RADIUS_RATIO
    body.polygon = _generate_star_polygon(STAR_POINTS, outer_radius, inner_radius)


static func _generate_star_polygon(points: int, outer_radius: float, inner_radius: float) -> PackedVector2Array:
    var star: PackedVector2Array = []
    var total := points * 2
    for i in range(total):
        var angle := i * PI / points - PI / 2.0
        var r := outer_radius if i % 2 == 0 else inner_radius
        star.append(Vector2(cos(angle) * r, sin(angle) * r))
    return star


func _reset_body(puff: PuffEnemy) -> void:
    var body: Polygon2D = puff.get_body()
    if body == null:
        return
    body.scale = _original_scale
    body.color = _original_color
    body.polygon = _original_polygon


func _kill_tweens() -> void:
    if _puff_tween != null and is_instance_valid(_puff_tween):
        _puff_tween.kill()
    if _shrink_tween != null and is_instance_valid(_shrink_tween):
        _shrink_tween.kill()


func _stop_timers() -> void:
    if _minimum_timer != null:
        _minimum_timer.stop()
    if _recheck_timer != null:
        _recheck_timer.stop()
