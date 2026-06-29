# puff_enemy_charge_state.gd
# Puff windup state that gives the player a readable dodge window before expansion.
extends EnemyState

var _timer: Timer
var _return_to_idle := false


func _init() -> void:
    state_id = EnemyStateId.PUFF_CHARGE


func _enter() -> void:
    _return_to_idle = false
    var puff_enemy := enemy as PuffEnemy
    if not puff_enemy.begin_puff_charge_action():
        _return_to_idle = true
        return

    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_charge_done)
    # node-src: timer
    add_child(_timer)
    _timer.start(puff_enemy.get_puff_charge_duration())


func _exit() -> void:
    _return_to_idle = false
    var puff_enemy := enemy as PuffEnemy
    puff_enemy.end_puff_charge_action()
    if _timer != null and is_instance_valid(_timer):
        _timer.queue_free()
        _timer = null


func _physics_update(_delta: float) -> void:
    if _return_to_idle:
        change_state(EnemyStateId.IDLE)


func _on_charge_done() -> void:
    change_state(EnemyStateId.PUFF)
