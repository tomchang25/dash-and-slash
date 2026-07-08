# tile_direction_resolver.gd
# Static tile-space direction classifier for FRONT, SIDE, and BACK hit relationships.
class_name TileDirectionResolver

enum HitAngle {
    FRONT,
    SIDE,
    BACK,
    NONE,
}

# == Common API ==


## Classifies an attacker cell relative to a target cell and the target's cardinal facing direction.
## FRONT covers every tile in the target's forward half-plane, SIDE covers lateral and rear-diagonal tiles, and BACK covers only the exact rear line.
static func resolve(attacker_cell: Vector2i, target_cell: Vector2i, target_facing: Vector2i) -> HitAngle:
    var delta := attacker_cell - target_cell
    if delta == Vector2i.ZERO or target_facing == Vector2i.ZERO:
        return HitAngle.NONE

    var forward := _dot(delta, target_facing)
    if forward > 0:
        return HitAngle.FRONT

    var lateral_axis := Vector2i(-target_facing.y, target_facing.x)
    var lateral := _dot(delta, lateral_axis)
    if forward < 0 and lateral == 0:
        return HitAngle.BACK

    return HitAngle.SIDE

# == Tile Math ==


static func _dot(a: Vector2i, b: Vector2i) -> int:
    return a.x * b.x + a.y * b.y
