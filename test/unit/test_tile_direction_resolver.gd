# test_tile_direction_resolver.gd
# Tests the shared tile-space hit-angle classifier used by tick combat.
extends GutTest


func test_forward_half_plane_resolves_front() -> void:
    assert_eq(TileDirectionResolver.resolve(Vector2i(5, 4), Vector2i(4, 4), Vector2i.RIGHT), TileDirectionResolver.HitAngle.FRONT)
    assert_eq(TileDirectionResolver.resolve(Vector2i(5, 3), Vector2i(4, 4), Vector2i.RIGHT), TileDirectionResolver.HitAngle.FRONT)


func test_lateral_and_rear_diagonals_resolve_side() -> void:
    assert_eq(TileDirectionResolver.resolve(Vector2i(4, 3), Vector2i(4, 4), Vector2i.RIGHT), TileDirectionResolver.HitAngle.SIDE)
    assert_eq(TileDirectionResolver.resolve(Vector2i(3, 3), Vector2i(4, 4), Vector2i.RIGHT), TileDirectionResolver.HitAngle.SIDE)


func test_exact_rear_line_resolves_back() -> void:
    assert_eq(TileDirectionResolver.resolve(Vector2i(3, 4), Vector2i(4, 4), Vector2i.RIGHT), TileDirectionResolver.HitAngle.BACK)
    assert_eq(TileDirectionResolver.resolve(Vector2i(2, 4), Vector2i(4, 4), Vector2i.RIGHT), TileDirectionResolver.HitAngle.BACK)


func test_same_cell_or_missing_facing_resolves_none() -> void:
    assert_eq(TileDirectionResolver.resolve(Vector2i(4, 4), Vector2i(4, 4), Vector2i.RIGHT), TileDirectionResolver.HitAngle.NONE)
    assert_eq(TileDirectionResolver.resolve(Vector2i(5, 4), Vector2i(4, 4), Vector2i.ZERO), TileDirectionResolver.HitAngle.NONE)
