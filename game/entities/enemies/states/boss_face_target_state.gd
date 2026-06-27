# boss_face_target_state.gd
# FaceTarget state snaps boss facing toward the target before telegraphing.
extends BossState

func _init() -> void:
    state_id = BossStateId.FACE_TARGET


func _enter() -> void:
    enemy.velocity = Vector2.ZERO
    enemy.face_target_position()

func _physics_update(_delta: float) -> void:
    change_state(BossStateId.TELEGRAPH)
