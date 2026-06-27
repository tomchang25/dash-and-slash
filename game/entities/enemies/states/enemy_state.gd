# enemy_state.gd
# Shared State base for GridEnemy states with typed owner access.
class_name EnemyState
extends State

var enemy: GridEnemy


func _ready() -> void:
    await owner.ready
    enemy = owner as GridEnemy
