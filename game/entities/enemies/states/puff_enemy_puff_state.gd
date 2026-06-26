# puff_enemy_puff_state.gd
# Zone-denial pulse state. The enemy stops, disables its contact hitbox,
# plays a puff expand VFX, enables a larger puff hitbox for a short window,
# then cools down. If the target is still within 3x3 grid range after the
# cooldown the puff repeats; otherwise the enemy returns to IDLE.
extends PuffEnemyState

const MINIMUM_PUFF_DURATION := 3.0
const RECHECK_INTERVAL := 1.0
const STAR_OUTER_RADIUS := 42.0
const STAR_INNER_RADIUS := 17.0
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
    state_id = PuffEnemyStateId.PUFF


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    enemy.clear_planned_action()
    _capture_original_body_state()
    _shrink_vfx_started = false
    _ensure_timers()
    _begin_puff()


func _exit() -> void:
    enemy.enable_puff_hitbox(false)
    enemy.set_contact_hitbox_enabled(true)
    _kill_tweens()
    _stop_timers()
    _reset_body()


func _capture_original_body_state() -> void:
    var body: Polygon2D = enemy.get_body()
    if body == null:
        _original_scale = Vector2.ONE
        _original_color = Color.WHITE
        _original_polygon = PackedVector2Array()
        return
    _original_scale = body.scale
    _original_color = body.color
    _original_polygon = body.polygon


func _ensure_timers() -> void:
    if _minimum_timer == null:
        _minimum_timer = Timer.new()
        _minimum_timer.one_shot = true
        _minimum_timer.timeout.connect(_on_minimum_timeout)
        enemy.add_child(_minimum_timer)

    if _recheck_timer == null:
        _recheck_timer = Timer.new()
        _recheck_timer.one_shot = true
        _recheck_timer.timeout.connect(_on_recheck_timeout)
        enemy.add_child(_recheck_timer)


func _begin_puff() -> void:
    enemy.set_contact_hitbox_enabled(false)
    _swap_to_star_polygon()
    _play_expand_vfx()
    _minimum_timer.start(MINIMUM_PUFF_DURATION)


func _on_minimum_timeout() -> void:
    _try_shrink_or_recheck()


func _on_recheck_timeout() -> void:
    _try_shrink_or_recheck()


func _try_shrink_or_recheck() -> void:
    if not enemy.has_target() or not enemy.is_target_in_puff_range():
        _start_shrink_and_idle()
        return
    _recheck_timer.start(RECHECK_INTERVAL)


func _start_shrink_and_idle() -> void:
    if _shrink_vfx_started:
        return
    _shrink_vfx_started = true
    enemy.enable_puff_hitbox(false)
    enemy.set_contact_hitbox_enabled(true)
    _play_shrink_vfx()
    if _shrink_tween == null:
        change_state(PuffEnemyStateId.IDLE)
        return
    _shrink_tween.finished.connect(_on_shrink_finished, CONNECT_ONE_SHOT)


func _on_shrink_finished() -> void:
    if _locked:
        return
    change_state(PuffEnemyStateId.IDLE)


func _play_expand_vfx() -> void:
    _kill_tweens()
    var body: Polygon2D = enemy.get_body()
    if body == null:
        return

    _puff_tween = enemy.create_tween()
    _puff_tween.set_parallel()
    _puff_tween.tween_property(body, "scale", _original_scale * 1.8, 0.12)
    _puff_tween.tween_property(body, "color", Color(1.0, 0.5, 0.5, 1.0), 0.12)
    _puff_tween.finished.connect(_on_expand_finished, CONNECT_ONE_SHOT)


func _on_expand_finished() -> void:
    if _locked:
        return
    enemy.enable_puff_hitbox(true)


func _play_shrink_vfx() -> void:
    var body: Polygon2D = enemy.get_body()
    if body == null:
        return

    _shrink_tween = enemy.create_tween()
    _shrink_tween.set_parallel()
    _shrink_tween.tween_property(body, "scale", _original_scale, 0.18)
    _shrink_tween.tween_property(body, "color", _original_color, 0.18)


func _swap_to_star_polygon() -> void:
    var body: Polygon2D = enemy.get_body()
    if body == null:
        return
    body.polygon = _generate_star_polygon(STAR_POINTS, STAR_OUTER_RADIUS, STAR_INNER_RADIUS)


static func _generate_star_polygon(points: int, outer_radius: float, inner_radius: float) -> PackedVector2Array:
    var star: PackedVector2Array = []
    var total := points * 2
    for i in range(total):
        var angle := i * PI / points - PI / 2.0
        var r := outer_radius if i % 2 == 0 else inner_radius
        star.append(Vector2(cos(angle) * r, sin(angle) * r))
    return star


func _reset_body() -> void:
    var body: Polygon2D = enemy.get_body()
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
