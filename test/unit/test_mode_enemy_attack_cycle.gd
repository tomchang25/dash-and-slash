# test_mode_enemy_attack_cycle.gd
# Covers ModeEnemy's authored selection and ten-tick post-Stagger retaliation window.
extends GutTest

const ModeEnemyScene := preload("res://game/entities/enemies/mode_enemy.tscn")


## Minimal tick-engine double exposing player_cell() for the AREA-kind checks below, plus the
## damage_player()/notify_detonation()/clear_energy() hooks the retaliation lifecycle tests drive
## through resolve_detonation() and the real Guard-break flow.
class FakeTickEngine:
    extends RefCounted
    ## Declared so bind_tick_engine()'s debug-label connection has something to attach to; this
    ## double never needs to fire it.
    signal world_advanced(tick_count: int)

    var _target_cell: Vector2i
    var last_damage_amount := -1.0
    var detonation_notified := false


    func _init(target_cell: Vector2i) -> void:
        _target_cell = target_cell


    func player_cell() -> Vector2i:
        return _target_cell


    func damage_player(amount: float, _source: Node) -> void:
        last_damage_amount = amount


    func notify_detonation(_cells: Array[Vector2i]) -> void:
        detonation_notified = true


    func clear_energy(_actor) -> void:
        pass


## A future encounter-specific Boss can omit Mode's default post-Stagger policy without branching
## shared recovery behavior.
class NoRetaliationModeEnemy:
    extends ModeEnemy

    ## Intentionally omits the default retaliation response for this encounter-specific policy.
    func apply_post_stagger_retaliation_policy() -> void:
        pass


func test_scene_uses_octopus_presenter_without_mode_change_state() -> void:
    var scene := ModeEnemyScene
    assert_not_null(scene, "ModeEnemy scene should load")

    var enemy := scene.instantiate()
    # node-ref: allow - validates ModeEnemy's required presenter scene wiring
    assert_not_null(enemy.get_node_or_null("VisualPresenter"), "ModeEnemy should own a visual presenter")
    # node-ref: allow - validates the obsolete ModeChange scene node is absent
    assert_null(enemy.get_node_or_null("StateMachine/ModeChange"), "ModeEnemy should not retain a ModeChange state")
    enemy.free()


func test_select_next_attack_uses_the_only_authored_attack() -> void:
    var enemy := ModeEnemyScene.instantiate() as ModeEnemy
    var data := EnemyData.new()
    var selected := EnemyAttackData.new()
    selected.attack_id = "only_attack"
    var attacks: Array[EnemyAttackData] = [selected]
    data.attacks = attacks
    enemy.enemy_data = data

    add_child_autofree(enemy)

    assert_eq(enemy.get_current_attack_data(), selected, "selection should use the authored attack resource")


## The AREA attack kind must still drive Mode's selection and commit checks, with no fall-through
## to the unsupported-kind fallback.
func test_area_kind_selection_survives_commit_check() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var area_attack := _make_area_attack(10.0, 3)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), area_attack, engine)

    assert_eq(enemy.get_current_attack_data().attack_kind, EnemyAttackData.AttackKind.AREA)
    assert_true(enemy.try_commit_attack(), "an in-range AREA attack must commit without a facing check")
    assert_push_error_count(0, "AREA-kind selection must never hit the unsupported-attack-kind fallback")


func test_stagger_end_replaces_the_interrupted_attack_selection() -> void:
    var interrupted := EnemyAttackData.new()
    interrupted.attack_id = "interrupted"
    var resumed := EnemyAttackData.new()
    resumed.attack_id = "resumed"
    var grid := _make_grid(Vector2i(5, 5))
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), interrupted, engine)

    var resumed_attacks: Array[EnemyAttackData] = [resumed]
    enemy.enemy_data.attacks = resumed_attacks
    _recover_from_stagger(enemy)

    assert_eq(enemy.get_current_attack_data(), resumed, "stagger end should select a fresh attack")

# == Elite retaliation ==


func _make_grid(size: Vector2i) -> GridArena:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = size
    grid.starting_land_size = size
    grid.generate_grid()
    return grid


## A single-radius AREA attack: is_target_within_grid_range() and the SQUARE footprint both cover
## any adjacent target regardless of facing, so commit outcomes stay deterministic in these tests.
func _make_area_attack(damage: float, warning_ticks: int) -> EnemyAttackData:
    var attack := EnemyAttackData.new()
    attack.attack_kind = EnemyAttackData.AttackKind.AREA
    attack.cell_shape = EnemyAttackData.CellShape.SQUARE
    attack.radius = 1
    attack.damage = damage
    attack.warning_duration = warning_ticks
    attack.recovery_duration = 0
    return attack


## Loads the real ModeEnemy scene (Guard, StateMachine, TileAttackExecutor, VisualPresenter all wired)
## so the shared commit flow, retaliation snapshot, and Aura presentation can be exercised end to end.
func _make_ready_enemy(grid: GridArena, start_cell: Vector2i, target_cell: Vector2i, attack: EnemyAttackData, engine: FakeTickEngine) -> ModeEnemy:
    var enemy := ModeEnemyScene.instantiate() as ModeEnemy

    var data := EnemyData.new()
    data.enemy_id = "test_mode_retaliation"
    data.max_health = 100.0
    var guard_profile := GuardProfile.new()
    guard_profile.base_guard = 1000
    data.guard_profile = guard_profile
    var attacks: Array[EnemyAttackData] = [attack]
    data.attacks = attacks
    enemy.enemy_data = data
    enemy.global_position = grid.cell_center(start_cell)

    add_child_autofree(enemy)

    var target: Node2D = autofree(Node2D.new())
    target.global_position = grid.cell_center(target_cell)
    enemy.bind_tick_engine(engine)
    enemy.setup(grid, target)

    return enemy


func _retaliation_presenter(enemy: ModeEnemy) -> ModeEnemyVisualPresenter:
    # node-ref: allow - validates the presenter's own RetaliationAura scene wiring
    return enemy.get_node_or_null("VisualPresenter") as ModeEnemyVisualPresenter


## Drives Guard through its actual break and one-tick Stagger recovery so Mode receives the public
## recovery signal without tests invoking private lifecycle callbacks directly.
func _recover_from_stagger(enemy: ModeEnemy) -> void:
    var guard := enemy.get_guard()
    guard.initialize(1, 1, 5, 0.5)
    guard.take_guard_damage(1)
    enemy.advance_status()


func test_stagger_end_starts_ten_tick_retaliation_by_default() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 3)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)

    _recover_from_stagger(enemy)

    assert_true(enemy.has_active_retaliation())
    assert_eq(enemy.retaliation_ticks_remaining(), 10)


func test_active_retaliation_visibly_shows_the_aura_before_any_commit() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 3)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)
    var presenter := _retaliation_presenter(enemy)
    # node-ref: allow - validates the presenter's own RetaliationAura scene wiring
    var aura := presenter.get_node_or_null("RetaliationAura") as Sprite2D
    assert_false(aura.visible, "the Aura must stay hidden outside an active retaliation")

    _recover_from_stagger(enemy)

    assert_true(aura.visible, "starting retaliation must show the persistent Aura cue")


func test_active_retaliation_snapshots_reduced_warning_and_boosted_damage_at_commit() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 3)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)
    _recover_from_stagger(enemy)

    assert_true(enemy.try_commit_attack())

    assert_true(enemy.has_active_retaliation(), "committing an attack must not end the timed window")
    assert_eq(enemy.retaliation_ticks_remaining(), 10)
    assert_eq(enemy.get_danger()["ticks"], 2, "the empowered warning should be one fewer tick")
    assert_eq(enemy.get_committed_attack_damage(), 12.5, "the empowered damage should snapshot at 1.25x")


func test_authored_warning_of_one_tick_stays_at_one_tick_while_retaliating() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 1)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)
    _recover_from_stagger(enemy)

    assert_true(enemy.try_commit_attack())

    assert_eq(enemy.get_danger()["ticks"], 1, "the one-tick floor must never reach zero")


func test_failed_preparation_leaves_retaliation_active_and_visible() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 3)
    var engine := FakeTickEngine.new(Vector2i(4, 4))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(4, 4), attack, engine)
    _recover_from_stagger(enemy)

    assert_false(enemy.try_commit_attack(), "an out-of-range target must fail the shared cell-footprint commit")

    assert_true(enemy.has_active_retaliation(), "a failed preparation must never consume the retaliation window")
    assert_eq(enemy.retaliation_ticks_remaining(), 10)
    var presenter := _retaliation_presenter(enemy)
    # node-ref: allow - validates the presenter's own RetaliationAura scene wiring
    var aura := presenter.get_node_or_null("RetaliationAura") as Sprite2D
    assert_true(aura.visible)


func test_resolution_preserves_retaliation_for_another_empowered_attack() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 1)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)
    _recover_from_stagger(enemy)
    assert_true(enemy.try_commit_attack())

    enemy.resolve_detonation()

    assert_eq(engine.last_damage_amount, 12.5, "the resolved hit must use the committed empowered damage")
    assert_true(enemy.has_active_retaliation(), "attack resolution must not clear the timed retaliation")
    var presenter := _retaliation_presenter(enemy)
    # node-ref: allow - validates the presenter's own RetaliationAura scene wiring
    var aura := presenter.get_node_or_null("RetaliationAura") as Sprite2D
    assert_true(aura.visible)

    assert_true(enemy.advance_status(), "the resolved attack's recovery tick should stay disabled")
    assert_eq(enemy.retaliation_ticks_remaining(), 9)
    assert_true(enemy.try_commit_attack())
    assert_eq(enemy.get_committed_attack_damage(), 12.5, "a later attack inside the window must also be empowered")


func test_committed_damage_survives_a_later_edit_to_the_authored_attack_data() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 3)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)
    _recover_from_stagger(enemy)
    assert_true(enemy.try_commit_attack())
    var committed_damage := enemy.get_committed_attack_damage()

    attack.damage = 999.0

    assert_eq(enemy.get_committed_attack_damage(), committed_damage, "a later authored-data edit must never change an already-committed snapshot")


func test_guard_break_clears_the_active_retaliation_before_stagger() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 3)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)
    _recover_from_stagger(enemy)
    assert_true(enemy.has_active_retaliation())

    enemy.get_guard().take_guard_damage(1)

    assert_false(enemy.has_active_retaliation(), "an old retaliation must clear before the fresh Stagger")


func test_repeated_recoveries_restart_duration_without_stacking_the_multiplier() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 3)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)

    _recover_from_stagger(enemy)
    for tick in 3:
        enemy.advance_status()
    assert_eq(enemy.retaliation_ticks_remaining(), 7)

    _recover_from_stagger(enemy)

    assert_eq(enemy.retaliation_ticks_remaining(), 10, "a fresh recovery restarts rather than stacks the window")
    assert_true(enemy.try_commit_attack())
    assert_eq(enemy.get_committed_attack_damage(), 12.5, "a repeated arm must never compound the multiplier")


func test_death_clears_active_retaliation() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 3)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)
    _recover_from_stagger(enemy)
    assert_true(enemy.has_active_retaliation())

    enemy.begin_death()

    assert_false(enemy.has_active_retaliation(), "death must clear an active retaliation without detonating")
    assert_false(engine.detonation_notified)


func test_reset_clears_active_retaliation() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 3)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)
    _recover_from_stagger(enemy)
    assert_true(enemy.has_active_retaliation())

    enemy.reset()

    assert_false(enemy.has_active_retaliation(), "a pooled reset must never carry a retaliation into the next spawn")


func test_boss_override_can_omit_the_default_retaliation_policy() -> void:
    var enemy: NoRetaliationModeEnemy = autofree(NoRetaliationModeEnemy.new())

    enemy.apply_post_stagger_retaliation_policy()

    assert_false(enemy.has_active_retaliation(), "an overriding Boss policy must be able to omit retaliation entirely")


func test_debug_status_reflects_retaliation_ticks_before_and_after_commit() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 3)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)
    assert_eq(enemy.get_debug_status_text().find("[Retaliation:"), -1, "no retaliation tag before Stagger recovers")

    _recover_from_stagger(enemy)
    assert_true(enemy.get_debug_status_text().ends_with("[Retaliation:10]"))

    enemy.advance_status()
    assert_true(enemy.get_debug_status_text().ends_with("[Retaliation:9]"))

    assert_true(enemy.try_commit_attack())
    assert_true(enemy.get_debug_status_text().ends_with("[Retaliation:9]"), "commit must not replace the window countdown")


func test_retaliation_has_five_ticks_left_when_guard_protection_ends() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 3)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)
    var guard := enemy.get_guard()
    guard.initialize(1, 1, 5, 0.5)
    guard.take_guard_damage(1)

    assert_true(enemy.advance_status(), "the Stagger-ending tick remains disabled")
    assert_true(guard.is_protected())
    assert_eq(enemy.retaliation_ticks_remaining(), 10, "the Stagger-ending tick must not consume retaliation")

    for tick in 5:
        enemy.advance_status()

    assert_false(guard.is_protected())
    assert_true(enemy.has_active_retaliation())
    assert_eq(enemy.retaliation_ticks_remaining(), 5)

    for tick in 5:
        enemy.advance_status()

    assert_false(enemy.has_active_retaliation())
    assert_eq(enemy.retaliation_ticks_remaining(), 0)
    var presenter := _retaliation_presenter(enemy)
    # node-ref: allow - validates the presenter's own RetaliationAura scene wiring
    var aura := presenter.get_node_or_null("RetaliationAura") as Sprite2D
    assert_false(aura.visible, "the Aura must clear when the ten-tick window expires")


func test_attack_committed_before_expiry_keeps_empowered_snapshot_after_window_ends() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 1)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)
    _recover_from_stagger(enemy)
    assert_true(enemy.try_commit_attack())

    for tick in 10:
        enemy.advance_status()

    assert_false(enemy.has_active_retaliation())
    assert_eq(enemy.get_committed_attack_damage(), 12.5, "expiry must not rewrite a committed snapshot")

    enemy.resolve_detonation()

    assert_eq(engine.last_damage_amount, 12.5, "the post-expiry detonation must retain empowered damage")


func test_attack_committed_after_expiry_uses_ordinary_values() -> void:
    var grid := _make_grid(Vector2i(5, 5))
    var attack := _make_area_attack(10.0, 3)
    var engine := FakeTickEngine.new(Vector2i(3, 2))
    var enemy := _make_ready_enemy(grid, Vector2i(2, 2), Vector2i(3, 2), attack, engine)
    _recover_from_stagger(enemy)
    for tick in 10:
        enemy.advance_status()

    assert_true(enemy.try_commit_attack())

    assert_eq(enemy.get_danger()["ticks"], 3)
    assert_eq(enemy.get_committed_attack_damage(), 10.0)
