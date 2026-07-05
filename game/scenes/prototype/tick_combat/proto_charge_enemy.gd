# proto_charge_enemy.gd
# Tick-prototype charger: lines up with the player, telegraphs its full travel line and destination
# two ticks ahead, traverses on detonation, then recovers for two ticks (the flank window).
extends ProtoTickEnemy

# -- Constants --

const TELEGRAPH_TICKS := 2
const RECOVERY_TICKS := 2
const CHARGE_ALIGN_RANGE := 6
const CHARGE_LENGTH := 4
const CHARGE_TWEEN_SEC := 0.14


# == Lifecycle ==


func _init() -> void:
    max_guard = 48
    max_hp = 90.0
    attack_damage = 15.0
    body_color = Color(0.85, 0.55, 0.3)
    # Stays at baseline deliberately: the charger's threat is bursty and its behavior already carries
    # pauses (align, turn, two-tick telegraph, two-tick recovery), so slowing it would kill the bait tempo.
    speed = 100


# == Overridden custom methods ==


func _think() -> void:
    var player_cell: Vector2i = _ctx.player_cell()
    var delta := player_cell - cell
    var aligned := delta != Vector2i.ZERO and (delta.x == 0 or delta.y == 0)
    if aligned and absi(delta.x) + absi(delta.y) <= CHARGE_ALIGN_RANGE:
        var dir := Vector2i(signi(delta.x), signi(delta.y))
        if facing != dir:
            _turn_step_toward(dir)
            return
        var line := _build_charge_line(dir)
        if not line.is_empty():
            _attack_tiles = line
            _attack_ticks = TELEGRAPH_TICKS
            queue_redraw()
            return
    _step_align(player_cell)


func _detonate() -> void:
    if _ctx.player_cell() in _attack_tiles:
        _ctx.damage_player(attack_damage, self)
    _ctx.notify_detonation(_attack_tiles)

    var dest := cell
    for line_cell: Vector2i in _attack_tiles:
        if not _ctx.is_cell_open_for_enemy(line_cell, self):
            break
        dest = line_cell
    if dest != cell:
        _move_to(dest, CHARGE_TWEEN_SEC)
    _recovery_ticks = RECOVERY_TICKS


func get_danger() -> Dictionary:
    var danger := super.get_danger()
    if not danger.is_empty():
        danger["dest"] = _attack_tiles.back()
    return danger


# == Charge behavior ==


## Builds the telegraph line ahead of the charger: consecutive land cells up to the charge length.
func _build_charge_line(dir: Vector2i) -> Array[Vector2i]:
    var line: Array[Vector2i] = []
    var probe := cell + dir
    while line.size() < CHARGE_LENGTH and _grid.is_land(probe):
        line.append(probe)
        probe += dir
    return line


## Steps to line up a row or column with the player, preferring to zero the smaller axis first.
func _step_align(player_cell: Vector2i) -> void:
    var delta := player_cell - cell
    var step_x := Vector2i(signi(delta.x), 0)
    var step_y := Vector2i(0, signi(delta.y))
    var zero_x_first := delta.x != 0 and (delta.y == 0 or absi(delta.x) <= absi(delta.y))
    var ordered: Array[Vector2i] = []
    if zero_x_first:
        ordered = [step_x, step_y]
    else:
        ordered = [step_y, step_x]
    for dir in ordered:
        if dir == Vector2i.ZERO:
            continue
        if _try_step(dir):
            return
