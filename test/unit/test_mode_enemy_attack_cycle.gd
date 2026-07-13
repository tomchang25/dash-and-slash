# test_mode_enemy_attack_cycle.gd
# Covers ModeEnemy's direct authored-attack selection and its reset/stagger reroll boundaries.
extends GutTest

## Minimal tick-engine double exposing only player_cell(), which _can_attack_with_current_selection()
## and plan_next_action() read through GridEnemy.get_target_cell() for the AREA-kind checks below.
class FakeTickEngine:
    extends RefCounted

    signal world_advanced(tick_count: int)

    var _target_cell: Vector2i


    func _init(target_cell: Vector2i) -> void:
        _target_cell = target_cell


    func player_cell() -> Vector2i:
        return _target_cell


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


## The AREA attack kind must still drive Mode's selection, commit-check, and planning match
## statements, with no fall-through to the unsupported-kind fallback.
func test_area_kind_selection_survives_commit_check_and_planning() -> void:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(5, 5)
    grid.starting_land_size = Vector2i(5, 5)
    grid.generate_grid()

    var enemy := ModeEnemy.new()
    var data := EnemyData.new()
    var area_attack := EnemyAttackData.new()
    area_attack.attack_kind = EnemyAttackData.AttackKind.AREA
    area_attack.cell_shape = EnemyAttackData.CellShape.SQUARE
    area_attack.radius = 1
    var attacks: Array[EnemyAttackData] = [area_attack]
    data.attacks = attacks
    enemy.enemy_data = data
    enemy._grid = grid
    enemy._grid_pos = Vector2i(2, 2)
    var target: Node2D = autofree(Node2D.new())
    target.global_position = grid.cell_center(Vector2i(2, 2))
    enemy._target = target
    enemy.bind_tick_engine(FakeTickEngine.new(Vector2i(2, 2)))

    enemy._select_next_attack()

    assert_eq(enemy.get_current_attack_data().attack_kind, EnemyAttackData.AttackKind.AREA)
    assert_true(enemy._can_attack_with_current_selection(), "an in-range AREA attack must be selectable without a facing check")
    assert_true(enemy.plan_next_action(), "AREA planning should fall back to ordinary approach movement")
    assert_push_error_count(0, "AREA-kind selection must never hit the unsupported-attack-kind fallback")
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
