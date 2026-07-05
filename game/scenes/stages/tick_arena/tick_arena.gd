# tick_arena.gd
# Tick arena scene root (debug-only until cutover; run the scene directly). Validates and executes
# player verbs (tick resolution stage 1), then hands world advancement to the TickEngine; also owns
# spawning, previews with resolved outcomes, HUD, and prototype-parity debug shortcuts.
extends Node2D

enum MobilityMode {
    DASH,
    SMASH,
}

# -- Constants --

const MeleeEnemyScene := preload("res://game/scenes/stages/tick_arena/tick_melee_enemy.tscn")
const ChargeEnemyScene := preload("res://game/scenes/stages/tick_arena/tick_charge_enemy.tscn")

const PLAYER_ATTACK_DAMAGE := 20.0
const PLAYER_DASH_DAMAGE := 30.0
const PLAYER_SMASH_DAMAGE := 30.0
const DASH_RANGE := 5
const DASH_COOLDOWN_TICKS := 4
const SMASH_RANGE := 3
const MESSAGE_SEC := 1.6
const MELEE_SPAWN_COUNT := 2
const CHARGER_SPAWN_COUNT := 1
const SPAWN_MIN_PLAYER_DISTANCE := 4
const BACKGROUND_COLOR := Color(0.09, 0.1, 0.12)

# -- State --

var _mobility_mode := MobilityMode.DASH
var _last_aim := Vector2i.RIGHT
var _message := ""
var _message_time := 0.0
var _rng := RandomNumberGenerator.new()

# -- Node references --

@onready var _grid: GridArena = %GridArena
@onready var _view: TickGridView = %GridView
@onready var _engine: TickEngine = %TickEngine
@onready var _input: TickInput = %TickInput
@onready var _player: TickPlayer = %Player
@onready var _enemy_container: Node2D = %Enemies
@onready var _stats_label: Label = %StatsLabel
@onready var _controls_label: Label = %ControlsLabel

# == Lifecycle ==


func _ready() -> void:
    _input.verb_requested.connect(_on_verb_requested)
    _engine.world_advanced.connect(_on_world_advanced)
    _engine.attack_detonated.connect(_on_attack_detonated)
    _engine.player_died.connect(_on_player_died)

    _rng.randomize()
    RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
    _player.setup(_grid, _grid.grid_size / 2)
    _spawn_enemies()
    _controls_label.text = "WASD step · LMB attack · RMB dash/smash · Space wait · T toggle dash/smash · R reset"
    _refresh_danger()
    _refresh_hud()


func _process(delta: float) -> void:
    _update_preview()
    _update_message(delta)


func _unhandled_input(event: InputEvent) -> void:
    # Debug-only arena shortcuts; production never routes here until cutover replaces them.
    if event is InputEventKey and event.pressed and not event.echo:
        match event.physical_keycode:
            KEY_T:
                _toggle_mobility_mode()
            KEY_R:
                _reset_run("Run reset.")

# == Signal handlers ==


func _on_verb_requested(verb: Dictionary) -> void:
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
            ToastManager.show_dev_error("TickArena: unknown verb %s" % str(verb))
    if consumed:
        _engine.advance_world()


func _on_world_advanced(_tick_count: int) -> void:
    _refresh_danger()
    _refresh_hud()


func _on_attack_detonated(cells: Array[Vector2i]) -> void:
    _view.flash_detonation(cells)


func _on_player_died() -> void:
    _reset_run("You died — run reset.")

# == Player verbs (tick resolution stage 1) ==


func _verb_move(dir: Vector2i) -> bool:
    _cancel_smash_windup()
    var target := _player.cell + dir
    if not _engine.is_cell_open_for_player(target):
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
    var enemy := _engine.enemy_at(target)
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
    for victim: TickEnemy in plan["victims"]:
        _apply_player_hit(victim, victim.cell - dir, PLAYER_DASH_DAMAGE, true)
    _view.flash_swing(plan["path"])
    _player.move_to(plan["landing"], true)
    _player.dash_cooldown = DASH_COOLDOWN_TICKS
    return true


## First press arms the windup on a locked landing cell; the next mobility press releases the leap and 3x3 hit.
func _verb_smash() -> bool:
    if not _player.is_smash_armed():
        var target := _clamped_smash_target()
        if not _engine.is_cell_open_for_player(target):
            _view.flash_deny(target)
            return false
        _player.arm_smash(target)
        _set_message("Smash windup...")
        return true

    var landing := _player.smash_target
    if not _engine.is_cell_open_for_player(landing):
        _view.flash_deny(landing)
        return false
    var area: Array[Vector2i] = []
    for ox in range(-1, 2):
        for oy in range(-1, 2):
            area.append(landing + Vector2i(ox, oy))
    _view.flash_swing(area)
    for enemy in _engine.actors():
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


func _apply_player_hit(enemy: TickEnemy, origin_cell: Vector2i, damage: float, is_dash: bool) -> void:
    var result := enemy.take_hit(origin_cell, damage, is_dash)
    if bool(result["killed"]):
        _set_message("Enemy destroyed!")
        _remove_enemy(enemy)
    elif bool(result["guard_broken"]):
        _set_message("%s hit — GUARD BREAK!" % _angle_name(result["angle"]))
    else:
        _set_message("%s hit." % _angle_name(result["angle"]))


func _remove_enemy(enemy: TickEnemy) -> void:
    _engine.unregister_actor(enemy)
    enemy.queue_free()
    if _engine.actors().is_empty():
        _set_message("All enemies down — R to respawn.")

# == Aiming and plans ==


func _mouse_cell() -> Vector2i:
    return _grid.world_to_grid(get_global_mouse_position())


func _aim_direction() -> Vector2i:
    var dir := TickCombatRules.dominant_direction(_mouse_cell() - _player.cell)
    if dir == Vector2i.ZERO:
        return _last_aim
    return dir


## Computes the dash plan shared by the preview and the verb: direction and wanted length from the cursor,
## landing on the farthest open cell at or before it, victims collected along the traveled path.
func _compute_dash_plan() -> Dictionary:
    var delta := _mouse_cell() - _player.cell
    var dir := TickCombatRules.dominant_direction(delta)
    if dir == Vector2i.ZERO:
        dir = _last_aim
    var wanted := clampi(absi(delta.x * dir.x + delta.y * dir.y), 1, DASH_RANGE)

    var probe_path: Array[Vector2i] = []
    var landing_index := -1
    for i in range(1, wanted + 1):
        var step_cell := _player.cell + dir * i
        probe_path.append(step_cell)
        if _engine.is_cell_open_for_player(step_cell):
            landing_index = i - 1
    if landing_index < 0:
        return { "legal": false, "dir": dir, "path": probe_path }

    var travel := probe_path.slice(0, landing_index + 1)
    var victims: Array[TickEnemy] = []
    for travel_cell: Vector2i in travel:
        var enemy := _engine.enemy_at(travel_cell)
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


func _chebyshev(delta: Vector2i) -> int:
    return maxi(absi(delta.x), absi(delta.y))

# == Spawning ==


func _spawn_enemies() -> void:
    for i in MELEE_SPAWN_COUNT:
        _spawn_enemy(MeleeEnemyScene)
    for i in CHARGER_SPAWN_COUNT:
        _spawn_enemy(ChargeEnemyScene)


func _spawn_enemy(scene: PackedScene) -> void:
    var enemy: TickEnemy = scene.instantiate()
    enemy.setup(_engine, _grid, _pick_spawn_cell())
    _enemy_container.add_child(enemy)
    _engine.register_actor(enemy)


func _pick_spawn_cell() -> Vector2i:
    var candidates: Array[Vector2i] = []
    var fallback: Array[Vector2i] = []
    for land_cell: Vector2i in _grid.get_land_cells():
        if land_cell == _player.cell or _engine.enemy_at(land_cell) != null:
            continue
        fallback.append(land_cell)
        var delta := land_cell - _player.cell
        if absi(delta.x) + absi(delta.y) >= SPAWN_MIN_PLAYER_DISTANCE:
            candidates.append(land_cell)
    if candidates.is_empty():
        candidates = fallback
    if candidates.is_empty():
        ToastManager.show_dev_error("TickArena: no free land cell to spawn an enemy.")
        return _player.cell
    return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _reset_run(reason: String) -> void:
    for actor in _engine.actors():
        actor.queue_free()
    _engine.clear_actors()
    _player.reset(_grid.grid_size / 2)
    _spawn_enemies()
    _refresh_danger()
    _refresh_hud()
    _set_message(reason)


func _toggle_mobility_mode() -> void:
    _cancel_smash_windup()
    _mobility_mode = MobilityMode.SMASH if _mobility_mode == MobilityMode.DASH else MobilityMode.DASH
    _set_message("Mobility slot: %s" % _mobility_mode_name())
    _refresh_hud()

# == View and HUD ==


## Pushes the actors' pending attacks to the view; runs after every world advance (hits resolve in
## stage 1 and are covered by the advance that follows every consumed verb).
func _refresh_danger() -> void:
    var danger: Array[Dictionary] = []
    for enemy in _engine.actors():
        var enemy_danger := enemy.get_danger()
        if not enemy_danger.is_empty():
            danger.append(enemy_danger)
    _view.set_danger(danger)


## Recomputes the free aiming previews every frame; aiming never consumes a tick.
## Previews carry resolved outcomes (landing ghost, per-victim angle/result badges) computed by the
## same predict_hit math that resolves the commit, so the display can never lie.
func _update_preview() -> void:
    var outcomes := { }
    var preview := { "aim_cell": _player.cell + _aim_direction() }
    var aim_enemy := _engine.enemy_at(preview["aim_cell"])
    if aim_enemy != null:
        outcomes[aim_enemy.cell] = _outcome_entry(aim_enemy, _player.cell, PLAYER_ATTACK_DAMAGE, false)

    if _mobility_mode == MobilityMode.DASH:
        if _player.dash_cooldown <= 0:
            var plan := _compute_dash_plan()
            preview["dash_path"] = plan["path"]
            preview["dash_legal"] = plan["legal"]
            if bool(plan["legal"]):
                preview["dash_landing"] = plan["landing"]
                preview["ghost_cell"] = plan["landing"]
                var dir: Vector2i = plan["dir"]
                for victim: TickEnemy in plan["victims"]:
                    outcomes[victim.cell] = _outcome_entry(victim, victim.cell - dir, PLAYER_DASH_DAMAGE, true)
    elif _player.is_smash_armed():
        preview["smash_armed_center"] = _player.smash_target
        preview["ghost_cell"] = _player.smash_target
        _collect_smash_outcomes(_player.smash_target, outcomes)
    else:
        var target := _clamped_smash_target()
        preview["smash_center"] = target
        preview["smash_legal"] = _engine.is_cell_open_for_player(target)
        if bool(preview["smash_legal"]):
            preview["ghost_cell"] = target
            _collect_smash_outcomes(target, outcomes)

    if not outcomes.is_empty():
        preview["outcomes"] = outcomes.values()
    _view.set_preview(preview)


## Predicts one hit for the preview and condenses it into a display entry: cell, label, and intensity tier.
func _outcome_entry(enemy: TickEnemy, origin_cell: Vector2i, damage: float, is_dash: bool) -> Dictionary:
    var result := enemy.predict_hit(origin_cell, damage, is_dash)
    var label := ""
    var tier := 0
    if bool(result["killed"]):
        label = "KILL"
        tier = 2
    elif bool(result["staggered"]):
        label = "BURST"
        tier = 1
    elif bool(result["guard_broken"]):
        label = "%s BREAK" % _angle_name(result["angle"]).to_upper()
        tier = 1
    else:
        label = _angle_name(result["angle"]).to_upper()
    return { "cell": enemy.cell, "label": label, "tier": tier }


func _collect_smash_outcomes(center: Vector2i, outcomes: Dictionary) -> void:
    for enemy in _engine.actors():
        if enemy.is_alive() and _chebyshev(enemy.cell - center) <= 1:
            outcomes[enemy.cell] = _outcome_entry(enemy, center, PLAYER_SMASH_DAMAGE, true)


func _refresh_hud() -> void:
    _stats_label.text = "HP %d/%d    Dash CD %d    Mobility: %s    Tick %d\n%s" % [
        int(_player.hp),
        int(TickPlayer.MAX_HP),
        _player.dash_cooldown,
        _mobility_mode_name(),
        _engine.tick_count(),
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
        TickCombatRules.HitAngle.FRONT:
            return "Front"
        TickCombatRules.HitAngle.SIDE:
            return "Side"
        TickCombatRules.HitAngle.BACK:
            return "BACK"
        _:
            ToastManager.show_dev_error("TickArena: unexpected hit angle %d" % angle)
            return "?"
