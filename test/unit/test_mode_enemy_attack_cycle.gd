# test_mode_enemy_attack_cycle.gd
# Covers ModeEnemy's direct authored-attack selection and its reset/stagger reroll boundaries.
extends GutTest


func test_scene_uses_octopus_presenter_without_mode_change_state() -> void:
    var scene := load("res://game/entities/enemies/mode_enemy.tscn") as PackedScene
    assert_not_null(scene, "ModeEnemy scene should load")

    var enemy := scene.instantiate()
    # node-ref: allow - validates ModeEnemy's required presenter scene wiring
    assert_not_null(enemy.get_node_or_null("VisualPresenter"), "ModeEnemy should own a visual presenter")
    # node-ref: allow - validates the obsolete ModeChange scene node is absent
    assert_null(enemy.get_node_or_null("StateMachine/ModeChange"), "ModeEnemy should not retain a ModeChange state")
    enemy.free()


func test_select_next_attack_uses_the_only_authored_attack() -> void:
    var enemy := ModeEnemy.new()
    var data := EnemyData.new()
    var selected := EnemyAttackData.new()
    selected.attack_id = "only_attack"
    var attacks: Array[EnemyAttackData] = [selected]
    data.attacks = attacks
    enemy.enemy_data = data

    enemy._select_next_attack()

    assert_eq(enemy.get_current_attack_data(), selected, "selection should use the authored attack resource")
    enemy.free()


func test_stagger_end_replaces_the_interrupted_attack_selection() -> void:
    var enemy := ModeEnemy.new()
    var data := EnemyData.new()
    var interrupted := EnemyAttackData.new()
    interrupted.attack_id = "interrupted"
    var resumed := EnemyAttackData.new()
    resumed.attack_id = "resumed"
    var initial_attacks: Array[EnemyAttackData] = [interrupted]
    data.attacks = initial_attacks
    enemy.enemy_data = data
    enemy._select_next_attack()

    var resumed_attacks: Array[EnemyAttackData] = [resumed]
    data.attacks = resumed_attacks
    enemy._on_stagger_ended()

    assert_eq(enemy.get_current_attack_data(), resumed, "stagger end should select a fresh attack")
    enemy.free()
