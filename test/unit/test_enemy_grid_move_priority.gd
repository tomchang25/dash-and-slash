# test_enemy_grid_move_priority.gd
# Tests deterministic priority resolution for contested grid movement.
extends GutTest

var _grid: GridArena
var _player_cell := Vector2i(4, 4)


func before_each() -> void:
    _grid = autofree(GridArena.new())
    _grid.grid_size = Vector2i(10, 10)
    _grid.starting_land_size = Vector2i(10, 10)
    _grid.generate_grid()
    _grid.set_player_cell(_grid.cell_center(_player_cell))
    # Register player occupancy so distance works correctly
    _grid.register_occupant(PlayerMock.new(), [_player_cell])


func after_each() -> void:
    _grid = null


## Helper: registers an entity at the given cell and assigns a registration index.
func _register_entity(entity: Object, cell: Vector2i) -> void:
    _grid.register_occupant(entity, [cell])
    _grid.register_enemy_entity(entity)


# == Ordinary vs Ordinary =======================================================


func test_ordinary_distance_decides_when_same_attack_intent() -> void:
    var closer := Node.new()
    var farther := Node.new()
    _register_entity(closer, Vector2i(4, 3))
    _register_entity(farther, Vector2i(4, 6))
    var target_cell := Vector2i(4, 5)

    var closer_ok := _grid.reserve_cells(closer, [target_cell], false)
    var farther_ok := _grid.reserve_cells(farther, [target_cell], false)

    assert_true(closer_ok, "closer enemy should win reservation")
    assert_false(farther_ok, "farther enemy should lose reservation")
    assert_true(_grid.is_reserved_by(target_cell, closer), "target cell should be owned by closer enemy")


func test_ordinary_tie_uses_registration_order() -> void:
    var first := Node.new()
    var second := Node.new()
    _register_entity(first, Vector2i(4, 5))
    _register_entity(second, Vector2i(4, 5))
    var target_cell := Vector2i(4, 6)

    var first_ok := _grid.reserve_cells(first, [target_cell], false)
    var second_ok := _grid.reserve_cells(second, [target_cell], false)

    assert_true(first_ok, "earlier-registered enemy should win tie")
    assert_false(second_ok, "later-registered enemy should lose tie")
    assert_true(_grid.is_reserved_by(target_cell, first), "target should be owned by first-registered enemy")


func test_ordinary_lower_registration_loses_when_equal_distance() -> void:
    var early := Node.new()
    var late := Node.new()
    _register_entity(early, Vector2i(3, 4))
    _register_entity(late, Vector2i(5, 4))
    var target := Vector2i(4, 4)

    # Both are distance 1 from player at (4,4)
    var early_ok := _grid.reserve_cells(early, [target], false)
    var late_ok := _grid.reserve_cells(late, [target], false)

    assert_true(early_ok, "earlier index should win at equal distance")
    assert_false(late_ok, "later index should lose at equal distance")


# == Attack vs Ordinary =========================================================


func test_attack_beats_ordinary_for_same_cell() -> void:
    var attacker := Node.new()
    var ordinary := Node.new()
    _register_entity(attacker, Vector2i(4, 3))
    _register_entity(ordinary, Vector2i(4, 5))
    var target_cell := Vector2i(4, 4)

    var ordinary_ok := _grid.reserve_cells(ordinary, [target_cell], false)
    var attack_ok := _grid.reserve_cells(attacker, [target_cell], true)

    assert_true(attack_ok, "attack-priority should replace ordinary reservation")
    assert_true(_grid.is_reserved_by(target_cell, attacker), "attacker should own cell after replacement")


func test_attack_replaces_existing_ordinary_reservation() -> void:
    var ordinary := Node.new()
    var attacker := Node.new()
    _register_entity(ordinary, Vector2i(4, 2))
    _register_entity(attacker, Vector2i(4, 6))
    var target := Vector2i(4, 5)

    # Ordinary reserves first
    assert_true(_grid.reserve_cells(ordinary, [target], false), "ordinary should reserve initially")

    # Higher-priority attack takes over - attacker is farther from player but has attack intent
    assert_true(_grid.reserve_cells(attacker, [target], true), "attack should win regardless of distance")

    assert_true(_grid.is_reserved_by(target, attacker), "attacker should own after takeover")
    assert_false(_grid.is_reserved_by(target, ordinary), "ordinary should lose ownership")


func test_ordinary_does_not_replace_attack_reservation() -> void:
    var attacker := Node.new()
    var ordinary := Node.new()
    _register_entity(attacker, Vector2i(4, 3))
    _register_entity(ordinary, Vector2i(4, 5))
    var target := Vector2i(4, 4)

    assert_true(_grid.reserve_cells(attacker, [target], true), "attack should reserve first")
    assert_false(_grid.reserve_cells(ordinary, [target], false), "ordinary should not replace attack")

    assert_true(_grid.is_reserved_by(target, attacker), "attacker should still own after ordinary attempt")


# == Signal emission ============================================================


func test_reservation_lost_emitted_when_replaced_by_higher_priority() -> void:
    var ordinary := Node.new()
    var attacker := Node.new()
    _register_entity(ordinary, Vector2i(4, 2))
    _register_entity(attacker, Vector2i(4, 6))
    var target := Vector2i(4, 5)

    assert_true(_grid.reserve_cells(ordinary, [target], false))

    var lost_entity: Object = null
    var signal_connected := _grid.reservation_lost.connect(func(entity: Object): lost_entity = entity)
    assert_eq(signal_connected, OK, "signal connection should succeed")

    assert_true(_grid.reserve_cells(attacker, [target], true))

    assert_eq(lost_entity, ordinary, "ordinary should receive reservation_lost signal")


func test_no_signal_when_lower_priority_loses() -> void:
    var first := Node.new()
    var second := Node.new()
    _register_entity(first, Vector2i(4, 5))
    _register_entity(second, Vector2i(4, 5))
    var target := Vector2i(4, 6)

    assert_true(_grid.reserve_cells(first, [target], false))

    var signal_fired := false
    _grid.reservation_lost.connect(func(_e: Object): signal_fired = true)

    assert_false(_grid.reserve_cells(second, [target], false))
    assert_false(signal_fired, "no signal when lower-priority claim is rejected")


# == Registration Index =========================================================


func test_registration_index_deterministic_across_cycles() -> void:
    var a := Node.new()
    var b := Node.new()
    _register_entity(a, Vector2i(3, 4))
    _register_entity(b, Vector2i(5, 4))
    var target := Vector2i(4, 4)

    # First cycle: a wins
    assert_true(_grid.reserve_cells(a, [target], false))
    assert_false(_grid.reserve_cells(b, [target], false))

    _grid.clear_reservation(a)
    _grid.clear_reservation(b)

    # Second cycle: a should still win (same registration order, same distance)
    assert_true(_grid.reserve_cells(a, [target], false))
    assert_false(_grid.reserve_cells(b, [target], false))

    assert_true(_grid.is_reserved_by(target, a), "deterministic: a should win both cycles")


# == Multiple cells =============================================================


func test_reservation_for_multiple_cells_all_or_nothing() -> void:
    var first := Node.new()
    var second := Node.new()
    _register_entity(first, Vector2i(2, 4))
    _register_entity(second, Vector2i(6, 4))
    var first_cells := [Vector2i(3, 4), Vector2i(4, 4)]

    # First reserves both cells
    assert_true(_grid.reserve_cells(first, first_cells, false))

    # Second tries to reserve a cell that conflicts
    var second_result := _grid.reserve_cells(second, [Vector2i(4, 4), Vector2i(5, 4)], false)
    assert_false(second_result, "second should fail when any cell is contested by higher-priority")

    # First's reservation should be intact
    assert_true(_grid.is_reserved_by(Vector2i(3, 4), first))
    assert_true(_grid.is_reserved_by(Vector2i(4, 4), first))


# == Player occupancy for reference =============================================


## Minimal object used only to occupy the player cell for distance computations.
class PlayerMock:
    extends RefCounted
