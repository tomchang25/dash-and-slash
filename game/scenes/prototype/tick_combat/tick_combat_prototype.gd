# tick_combat_prototype.gd
# Grey-box tick-combat prototype scene controller (debug-only; never routed from production — run the scene directly).
# Owns the verb input layer (mouse aims for free, any executed verb advances the world exactly one tick),
# the three-stage tick resolution, enemy spawning, preview computation, and the HUD.
extends Node2D

enum MobilityMode {
    DASH,
    SMASH,
}

# -- Constants --

const MeleeEnemyScene := preload("res://game/scenes/prototype/tick_combat/proto_melee_enemy.tscn")
const ChargeEnemyScene := preload("res://game/scenes/prototype/tick_combat/proto_charge_enemy.tscn")

const PLAYER_ATTACK_DAMAGE := 20.0
const PLAYER_DASH_DAMAGE := 30.0
const PLAYER_SMASH_DAMAGE := 30.0
const DASH_RANGE := 5
const DASH_COOLDOWN_TICKS := 4
const SMASH_RANGE := 3
const HOLD_REPEAT_SEC := 0.14
const MESSAGE_SEC := 1.6
const MELEE_SPAWN_COUNT := 2
const CHARGER_SPAWN_COUNT := 1
const SPAWN_MIN_PLAYER_DISTANCE := 4
const BACKGROUND_COLOR := Color(0.09, 0.1, 0.12)

const MOVE_ACTIONS := {
    "move_up": Vector2i.UP,
    "move_down": Vector2i.DOWN,
    "move_left": Vector2i.LEFT,
    "move_right": Vector2i.RIGHT,
}

# -- State --

var _tick_count := 0
var _mobility_mode := MobilityMode.DASH
var _repeat_timer := 0.0
var _rmb_was_pressed := false
var _space_was_pressed := false
var _last_aim := Vector2i.RIGHT
var _enemies: Array[ProtoTickEnemy] = []
var _player_died := false
var _message := ""
var _message_time := 0.0
var _rng := RandomNumberGenerator.new()

# -- Node references --

@onready var _grid: GridArena = %GridArena
@onready var _view: ProtoGridView = %GridView
@onready var _player: ProtoPlayer = %Player
@onready var _enemy_container: Node2D = %Enemies
@onready var _stats_label: Label = %StatsLabel
@onready var _controls_label: Label = %ControlsLabel


# == Lifecycle ==


func _ready() -> void:
    _rng.randomize()
    RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
    _player.setup(_grid, _grid.grid_size / 2)
    _spawn_enemies()
    _controls_label.text = "WASD step · LMB attack · RMB dash/smash · Space wait · T toggle dash/smash · R reset"
    _refresh_world_view()
    _refresh_hud()


func _process(delta: float) -> void:
    _poll_input(delta)
    _update_preview()
    _update_message(delta)


func _unhandled_input(event: InputEvent) -> void:
    # Prototype-only shortcuts; the whole scene is a debug artifact that production never routes to.
    if event is InputEventKey and event.pressed and not event.echo:
        match event.physical_keycode:
            KEY_T:
                _toggle_mobility_mode()
            KEY_R:
                _reset_run("Run reset.")


# == Common API (tick context for enemies) ==


## Returns the player's current grid cell.
func player_cell() -> Vector2i:
    return _player.cell


## Applies enemy damage to the player; death is deferred to the end of the current tick resolution.
func damage_player(amount: float, _source: Node) -> void:
    if _player.take_damage(amount):
        _player_died = true


## Returns true when an enemy may stand on the cell: in-bounds land, not the player, not another living enemy.
func is_cell_open_for_enemy(target_cell: Vector2i, asking: ProtoTickEnemy) -> bool:
    if not _grid.is_land(target_cell) or target_cell == _player.cell:
        return false
    for enemy in _enemies:
        if enemy != asking and enemy.is_alive() and enemy.cell == target_cell:
            return false
    return true


## Flashes the detonation color over an enemy attack's tiles.
func notify_detonation(cells: Array[Vector2i]) -> void:
    _view.flash_detonation(cells)


# == Input layer ==


## Polls the verb input each frame: edge presses fire immediately, held verbs repeat on the shared timer.
func _poll_input(delta: float) -> void:
    var rmb_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
    var space_pressed := Input.is_physical_key_pressed(KEY_SPACE)

    var verb := _edge_verb(rmb_pressed, space_pressed)
    if not verb.is_empty():
        _try_execute_verb(verb)
        _repeat_timer = HOLD_REPEAT_SEC
    else:
        var held := _held_verb(rmb_pressed, space_pressed)
        if held.is_empty():
            _repeat_timer = 0.0
        else:
            _repeat_timer -= delta
            if _repeat_timer <= 0.0:
                _try_execute_verb(held)
                _repeat_timer = HOLD_REPEAT_SEC

    _rmb_was_pressed = rmb_pressed
    _space_was_pressed = space_pressed


func _edge_verb(rmb_pressed: bool, space_pressed: bool) -> Dictionary:
    for action: String in MOVE_ACTIONS:
        if Input.is_action_just_pressed(action):
            return { "type": "move", "dir": MOVE_ACTIONS[action] }
    if Input.is_action_just_pressed("attack"):
        return { "type": "attack" }
    if rmb_pressed and not _rmb_was_pressed:
        return { "type": "mobility" }
    if space_pressed and not _space_was_pressed:
        return { "type": "wait" }
    return { }


func _held_verb(rmb_pressed: bool, space_pressed: bool) -> Dictionary:
    for action: String in MOVE_ACTIONS:
        if Input.is_action_pressed(action):
            return { "type": "move", "dir": MOVE_ACTIONS[action] }
    if Input.is_action_pressed("attack"):
        return { "type": "attack" }
    if rmb_pressed:
        return { "type": "mobility" }
    if space_pressed:
        return { "type": "wait" }
    return { }


func _try_execute_verb(verb: Dictionary) -> void:
    var consumed := false
    match String(verb.get("type", "")):
        "move":
            consumed = _verb_move(verb["dir"])
        "attack":
            consumed = _verb_attack()
        "mobility":
            consumed = _verb_mobility()
        "wait":
            consumed = _verb_wait()
        _:
            ToastManager.show_dev_error("TickCombatPrototype: unknown verb %s" % str(verb))
    if consumed:
        _advance_world()


# == Player verbs (tick resolution stage 1) ==


func _verb_move(dir: Vector2i) -> bool:
    _cancel_smash_windup()
    var target := _player.cell + dir
    if not _is_cell_open_for_player(target):
        _view.flash_deny(target)
        return false
    _player.move_to(target)
    return true


## Swings at the mouse-aimed adjacent cell; a whiff still consumes the tick, only illegal inputs are free.
func _verb_attack() -> bool:
    _cancel_smash_windup()
    var aim := _aim_direction()
    _last_aim = aim
    var target := _player.cell + aim
    _view.flash_swing([target])
    var enemy := _enemy_at(target)
    if enemy != null:
        _apply_player_hit(enemy, _player.cell, PLAYER_ATTACK_DAMAGE, false)
    return true


func _verb_mobility() -> bool:
    if _mobility_mode == MobilityMode.DASH:
        return _verb_dash()
    return _verb_smash()


func _verb_dash() -> bool:
    if _player.dash_cooldown > 0:
        _set_message("Dash on cooldown (%d)." % _player.dash_cooldown)
        return false
    var plan := _compute_dash_plan()
    if not bool(plan["legal"]):
        _view.flash_deny(_player.cell + plan["dir"] * DASH_RANGE)
        return false
    var dir: Vector2i = plan["dir"]
    for victim: ProtoTickEnemy in plan["victims"]:
        _apply_player_hit(victim, victim.cell - dir, PLAYER_DASH_DAMAGE, true)
    _view.flash_swing(plan["path"])
    _player.move_to(plan["landing"], true)
    _player.dash_cooldown = DASH_COOLDOWN_TICKS
    return true


## First press arms the windup on a locked landing cell; the next mobility press releases the leap and 3x3 hit.
func _verb_smash() -> bool:
    if not _player.is_smash_armed():
        var target := _clamped_smash_target()
        if not _is_cell_open_for_player(target):
            _view.flash_deny(target)
            return false
        _player.arm_smash(target)
        _set_message("Smash windup...")
        return true

    var landing := _player.smash_target
    if not _is_cell_open_for_player(landing):
        _view.flash_deny(landing)
        return false
    var area: Array[Vector2i] = []
    for ox in range(-1, 2):
        for oy in range(-1, 2):
            area.append(landing + Vector2i(ox, oy))
    _view.flash_swing(area)
    for enemy in _enemies.duplicate():
        if enemy.is_alive() and _chebyshev(enemy.cell - landing) <= 1:
            _apply_player_hit(enemy, landing, PLAYER_SMASH_DAMAGE, true)
    _player.move_to(landing, true)
    _player.disarm_smash()
    return true


func _verb_wait() -> bool:
    _cancel_smash_windup()
    return true


## Cancels an armed smash when another verb executes; the windup tick already spent is not refunded.
func _cancel_smash_windup() -> void:
    if _player.is_smash_armed():
        _player.disarm_smash()
        _set_message("Windup cancelled.")


# == Tick resolution ==


## Advances the world one tick after a consumed player verb (stage 1 already resolved):
## stage 2 detonates zero-countdown enemy attacks against the player's new cell, stage 3 lets enemies act.
func _advance_world() -> void:
    _tick_count += 1
    for enemy in _enemies.duplicate():
        if enemy.is_alive():
            enemy.resolve_detonation()
    for enemy in _enemies.duplicate():
        if enemy.is_alive():
            enemy.advance_tick()
    _player.tick_cooldowns()
    if _player_died:
        _player_died = false
        _reset_run("You died — run reset.")
        return
    _refresh_world_view()
    _refresh_hud()


func _apply_player_hit(enemy: ProtoTickEnemy, origin_cell: Vector2i, damage: float, is_dash: bool) -> void:
    var result := enemy.take_hit(origin_cell, damage, is_dash)
    if bool(result["killed"]):
        _set_message("Enemy destroyed!")
        _remove_enemy(enemy)
    elif bool(result["guard_broken"]):
        _set_message("%s hit — GUARD BREAK!" % _angle_name(result["angle"]))
    else:
        _set_message("%s hit." % _angle_name(result["angle"]))


func _remove_enemy(enemy: ProtoTickEnemy) -> void:
    _enemies.erase(enemy)
    enemy.queue_free()
    if _enemies.is_empty():
        _set_message("All enemies down — R to respawn.")


# == Aiming and plans ==


func _mouse_cell() -> Vector2i:
    return _grid.world_to_grid(get_global_mouse_position())


func _aim_direction() -> Vector2i:
    var dir := ProtoCombatRules.dominant_direction(_mouse_cell() - _player.cell)
    if dir == Vector2i.ZERO:
        return _last_aim
    return dir


## Computes the dash plan shared by the preview and the verb: direction and wanted length from the cursor,
## landing on the farthest open cell at or before it, victims collected along the traveled path.
func _compute_dash_plan() -> Dictionary:
    var delta := _mouse_cell() - _player.cell
    var dir := ProtoCombatRules.dominant_direction(delta)
    if dir == Vector2i.ZERO:
        dir = _last_aim
    var wanted := clampi(absi(delta.x * dir.x + delta.y * dir.y), 1, DASH_RANGE)

    var probe_path: Array[Vector2i] = []
    var landing_index := -1
    for i in range(1, wanted + 1):
        var step_cell := _player.cell + dir * i
        probe_path.append(step_cell)
        if _is_cell_open_for_player(step_cell):
            landing_index = i - 1
    if landing_index < 0:
        return { "legal": false, "dir": dir, "path": probe_path }

    var travel := probe_path.slice(0, landing_index + 1)
    var victims: Array[ProtoTickEnemy] = []
    for travel_cell: Vector2i in travel:
        var enemy := _enemy_at(travel_cell)
        if enemy != null:
            victims.append(enemy)
    return {
        "legal": true,
        "dir": dir,
        "path": travel,
        "landing": travel[landing_index],
        "victims": victims,
    }


func _clamped_smash_target() -> Vector2i:
    var delta := _mouse_cell() - _player.cell
    delta.x = clampi(delta.x, -SMASH_RANGE, SMASH_RANGE)
    delta.y = clampi(delta.y, -SMASH_RANGE, SMASH_RANGE)
    return _player.cell + delta


func _is_cell_open_for_player(target_cell: Vector2i) -> bool:
    return _grid.is_land(target_cell) and _enemy_at(target_cell) == null


func _enemy_at(target_cell: Vector2i) -> ProtoTickEnemy:
    for enemy in _enemies:
        if enemy.is_alive() and enemy.cell == target_cell:
            return enemy
    return null


func _chebyshev(delta: Vector2i) -> int:
    return maxi(absi(delta.x), absi(delta.y))


# == Spawning ==


func _spawn_enemies() -> void:
    for i in MELEE_SPAWN_COUNT:
        _spawn_enemy(MeleeEnemyScene)
    for i in CHARGER_SPAWN_COUNT:
        _spawn_enemy(ChargeEnemyScene)


func _spawn_enemy(scene: PackedScene) -> void:
    var enemy: ProtoTickEnemy = scene.instantiate()
    enemy.setup(self, _grid, _pick_spawn_cell())
    _enemy_container.add_child(enemy)
    _enemies.append(enemy)


func _pick_spawn_cell() -> Vector2i:
    var candidates: Array[Vector2i] = []
    var fallback: Array[Vector2i] = []
    for land_cell: Vector2i in _grid.get_land_cells():
        if land_cell == _player.cell or _enemy_at(land_cell) != null:
            continue
        fallback.append(land_cell)
        var delta := land_cell - _player.cell
        if absi(delta.x) + absi(delta.y) >= SPAWN_MIN_PLAYER_DISTANCE:
            candidates.append(land_cell)
    if candidates.is_empty():
        candidates = fallback
    if candidates.is_empty():
        ToastManager.show_dev_error("TickCombatPrototype: no free land cell to spawn an enemy.")
        return _player.cell
    return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _reset_run(reason: String) -> void:
    for enemy in _enemies:
        enemy.queue_free()
    _enemies.clear()
    _player.reset(_grid.grid_size / 2)
    _spawn_enemies()
    _refresh_world_view()
    _refresh_hud()
    _set_message(reason)


func _toggle_mobility_mode() -> void:
    _cancel_smash_windup()
    _mobility_mode = MobilityMode.SMASH if _mobility_mode == MobilityMode.DASH else MobilityMode.DASH
    _set_message("Mobility slot: %s" % _mobility_mode_name())
    _refresh_hud()


# == View and HUD ==


## Pushes the enemies' pending attacks to the view; called after every tick and after hits that cancel telegraphs.
func _refresh_world_view() -> void:
    var danger: Array[Dictionary] = []
    for enemy in _enemies:
        var enemy_danger := enemy.get_danger()
        if not enemy_danger.is_empty():
            danger.append(enemy_danger)
    _view.set_danger(danger)


## Recomputes the free aiming previews every frame; aiming never consumes a tick.
func _update_preview() -> void:
    var preview := { "aim_cell": _player.cell + _aim_direction() }
    if _mobility_mode == MobilityMode.DASH:
        if _player.dash_cooldown <= 0:
            var plan := _compute_dash_plan()
            preview["dash_path"] = plan["path"]
            preview["dash_legal"] = plan["legal"]
            if bool(plan["legal"]):
                preview["dash_landing"] = plan["landing"]
    elif _player.is_smash_armed():
        preview["smash_armed_center"] = _player.smash_target
    else:
        var target := _clamped_smash_target()
        preview["smash_center"] = target
        preview["smash_legal"] = _is_cell_open_for_player(target)
    _view.set_preview(preview)


func _refresh_hud() -> void:
    _stats_label.text = "HP %d/%d    Dash CD %d    Mobility: %s    Tick %d\n%s" % [
        int(_player.hp),
        int(ProtoPlayer.MAX_HP),
        _player.dash_cooldown,
        _mobility_mode_name(),
        _tick_count,
        _message,
    ]


func _set_message(text: String) -> void:
    _message = text
    _message_time = MESSAGE_SEC
    _refresh_hud()


func _update_message(delta: float) -> void:
    if _message_time <= 0.0:
        return
    _message_time -= delta
    if _message_time <= 0.0:
        _message = ""
        _refresh_hud()


func _mobility_mode_name() -> String:
    return "DASH" if _mobility_mode == MobilityMode.DASH else "SMASH"


func _angle_name(angle: int) -> String:
    match angle:
        ProtoCombatRules.HitAngle.FRONT:
            return "Front"
        ProtoCombatRules.HitAngle.SIDE:
            return "Side"
        ProtoCombatRules.HitAngle.BACK:
            return "BACK"
        _:
            ToastManager.show_dev_error("TickCombatPrototype: unexpected hit angle %d" % angle)
            return "?"
