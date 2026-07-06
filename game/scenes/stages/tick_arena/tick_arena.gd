# tick_arena.gd
# Tick arena scene root (debug-only until cutover; run the scene directly). Validates and executes
# player verbs (tick resolution stage 1), then hands world advancement to the TickEngine; also owns
# spawning, previews with resolved outcomes, HUD, and prototype-parity debug shortcuts.
extends Node2D

enum PreviewMode {
    NEUTRAL,
    MOBILITY_AIM,
}

# -- Constants --

const SmallEnemyScene := preload("res://game/entities/enemies/small_enemy.tscn")
const ChargeEnemyScene := preload("res://game/entities/enemies/charge_enemy.tscn")
const PuffEnemyScene := preload("res://game/entities/enemies/puff_enemy.tscn")
const ModeEnemyScene := preload("res://game/entities/enemies/mode_enemy.tscn")

const PLAYER_ATTACK_DAMAGE := 20.0
const PLAYER_DASH_DAMAGE := 30.0
const DASH_RANGE := 5
const DASH_COOLDOWN_TICKS := 4
const MESSAGE_SEC := 1.6
const SMALL_SPAWN_COUNT := 2
const CHARGER_SPAWN_COUNT := 1
const PUFF_SPAWN_COUNT := 1
const MODE_SPAWN_COUNT := 1
const SPAWN_MIN_PLAYER_DISTANCE := 4
const BACKGROUND_COLOR := Color(0.09, 0.1, 0.12)

# -- State --

var _preview_mode := PreviewMode.NEUTRAL
var _suppress_next_mobility_release := false
var _run_build := RunBuild.new()
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
    _controls_label.text = "WASD step · LMB attack · hold RMB aim mobility/release commit · Esc cancel · Space wait · T debug payload · R reset"
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
        "mobility_press":
            _begin_mobility_aim()
        "mobility_release":
            consumed = _release_mobility_aim()
        "mobility_cancel":
            _cancel_mobility_aim(true)
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
    var payload := _run_build.get_mobility_payload()
    if payload == RunBuild.PAYLOAD_DASH:
        return _verb_dash()
    if payload == RunBuild.PAYLOAD_DEBUG_STUB:
        return _verb_debug_stub_mobility()
    ToastManager.show_dev_error("TickArena: unknown mobility payload %s" % payload)
    return false


func _verb_dash() -> bool:
    if _player.dash_cooldown > 0:
        _set_message("Dash on cooldown (%d)." % _player.dash_cooldown)
        return false
    var plan := _compute_dash_plan()
    if not bool(plan["legal"]):
        _view.flash_deny(_player.cell + plan["dir"] * DASH_RANGE)
        return false
    var dir: Vector2i = plan["dir"]
    var hit_any := false
    for victim: GridEnemy in plan["victims"]:
        hit_any = true
        _apply_player_hit(victim, victim.get_grid_pos() - dir, PLAYER_DASH_DAMAGE, true)
    if not hit_any:
        _apply_player_result_message(TickHitResolver.empty_outcome())
    _view.flash_swing(plan["path"])
    _player.move_to(plan["landing"], true)
    _player.dash_cooldown = DASH_COOLDOWN_TICKS
    return true


func _verb_debug_stub_mobility() -> bool:
    var target := _player.cell + _aim_direction()
    if not _engine.is_cell_open_for_player(target):
        _view.flash_deny(target)
        return false
    _view.flash_swing([target])
    _player.move_to(target, true)
    _set_message("Debug mobility payload fired.")
    return true


func _verb_wait() -> bool:
    _cancel_smash_windup()
    return true


func _begin_mobility_aim() -> void:
    if not _can_aim_mobility_payload():
        return
    _preview_mode = PreviewMode.MOBILITY_AIM
    _suppress_next_mobility_release = false


func _release_mobility_aim() -> bool:
    if _suppress_next_mobility_release:
        _suppress_next_mobility_release = false
        return false
    if _preview_mode != PreviewMode.MOBILITY_AIM:
        return false
    _preview_mode = PreviewMode.NEUTRAL
    return _verb_mobility()


func _cancel_mobility_aim(suppress_release: bool) -> void:
    if _preview_mode != PreviewMode.MOBILITY_AIM:
        return
    _preview_mode = PreviewMode.NEUTRAL
    _suppress_next_mobility_release = suppress_release
    _set_message("Mobility cancelled.")


func _can_aim_mobility_payload() -> bool:
    var payload := _run_build.get_mobility_payload()
    if payload == RunBuild.PAYLOAD_DASH:
        if _player.dash_cooldown > 0:
            _set_message("Dash on cooldown (%d)." % _player.dash_cooldown)
            return false
        return true
    if payload == RunBuild.PAYLOAD_DEBUG_STUB:
        return true
    ToastManager.show_dev_error("TickArena: unknown mobility payload %s" % payload)
    return false


## Cancels an armed smash when another verb executes; the windup tick already spent is not refunded.
func _cancel_smash_windup() -> void:
    if _player.is_smash_armed():
        _player.disarm_smash()
        _set_message("Windup cancelled.")


func _apply_player_hit(enemy: GridEnemy, origin_cell: Vector2i, damage: float, is_dash: bool) -> void:
    var result := enemy.take_hit(origin_cell, damage, is_dash)
    if bool(result["killed"]):
        _remove_enemy(enemy)
    _apply_player_result_message(result)


func _apply_player_result_message(result: Dictionary) -> void:
    var feedback_kind := StringName(result.get("feedback_kind", TickHitResolver.FEEDBACK_DAMAGED))
    if feedback_kind == TickHitResolver.FEEDBACK_WHIFF:
        _set_message("Whiff.")
    elif feedback_kind == TickHitResolver.FEEDBACK_KILL:
        _set_message("Enemy destroyed!")
    elif feedback_kind == TickHitResolver.FEEDBACK_GUARD_BREAK:
        _set_message("%s hit — GUARD BREAK!" % _angle_name(result["angle"]))
    elif feedback_kind == TickHitResolver.FEEDBACK_STAGGER_BURST:
        _set_message("%s burst hit." % _angle_name(result["angle"]))
    elif feedback_kind == TickHitResolver.FEEDBACK_BLOCKED:
        _set_message("%s blocked." % _angle_name(result["angle"]))
    elif feedback_kind == TickHitResolver.FEEDBACK_DAMAGED:
        _set_message("%s hit." % _angle_name(result["angle"]))
    else:
        ToastManager.show_dev_error("TickArena: unexpected feedback kind %s" % feedback_kind)


## Stops scheduling a killed enemy. The enemy runs its own death-state tween and frees itself.
func _remove_enemy(enemy: GridEnemy) -> void:
    _engine.unregister_actor(enemy)
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

    var preview_path: Array[Vector2i] = []
    var travel_path: Array[Vector2i] = []
    var landing_index := -1
    for i in range(1, wanted + 1):
        var step_cell := _player.cell + dir * i
        if not _grid.is_land(step_cell):
            break
        preview_path.append(step_cell)
        travel_path.append(step_cell)
        if _engine.enemy_at(step_cell) == null:
            landing_index = travel_path.size() - 1
    if landing_index < 0:
        return { "legal": false, "dir": dir, "path": preview_path }

    var travel := travel_path.slice(0, landing_index + 1)
    var victims: Array[GridEnemy] = []
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

# == Spawning ==


func _spawn_enemies() -> void:
    for i in SMALL_SPAWN_COUNT:
        _spawn_enemy(SmallEnemyScene)
    for i in CHARGER_SPAWN_COUNT:
        _spawn_enemy(ChargeEnemyScene)
    for i in PUFF_SPAWN_COUNT:
        _spawn_enemy(PuffEnemyScene)
    for i in MODE_SPAWN_COUNT:
        _spawn_enemy(ModeEnemyScene)


## Instantiates a production enemy kind and binds it to the tick engine as a scheduled actor.
func _spawn_enemy(scene: PackedScene) -> void:
    var enemy: GridEnemy = scene.instantiate()
    enemy.global_position = _grid.cell_center(_pick_spawn_cell())
    enemy.setup(_grid, _player)
    enemy.bind_tick_engine(_engine)
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
        _grid.unregister_occupant(actor)
        actor.queue_free()
    _engine.clear_actors()
    _player.reset(_grid.grid_size / 2)
    _spawn_enemies()
    _refresh_danger()
    _refresh_hud()
    _set_message(reason)


func _toggle_mobility_mode() -> void:
    _cancel_smash_windup()
    _cancel_mobility_aim(false)
    if _run_build.get_mobility_payload() == RunBuild.PAYLOAD_DASH:
        _run_build.set_mobility_payload_override(RunBuild.PAYLOAD_DEBUG_STUB)
    else:
        _run_build.set_mobility_payload_override(RunBuild.PAYLOAD_DASH)
    _set_message("Mobility slot: %s" % _mobility_mode_name())
    _refresh_hud()

# == View and HUD ==


## Pushes the actors' pending attacks to the production telegraph layer, which GridTerrainView paints
## in the enemy-danger palette, and to the debug overlay for the tick countdowns; runs after every
## world advance (hits resolve in stage 1 and are covered by the advance that follows every consumed verb).
func _refresh_danger() -> void:
    _grid.clear_all_telegraphs()
    var danger: Array[Dictionary] = []
    for enemy in _engine.actors():
        var enemy_danger := enemy.get_danger()
        if enemy_danger.is_empty():
            continue
        danger.append(enemy_danger)
        var cells: Array[Vector2i] = enemy_danger["cells"]
        var phase := GridArena.TelegraphPhase.CHARGE if int(enemy_danger["ticks"]) <= 1 else GridArena.TelegraphPhase.WARNING
        _grid.set_telegraph(enemy, cells, phase)
    _view.set_danger(danger)


## Recomputes the free aiming previews every frame; aiming never consumes a tick.
## Previews carry resolved outcomes (landing ghost, per-victim angle/result badges) computed by the
## same predict_hit math that resolves the commit, so the display can never lie.
func _update_preview() -> void:
    var outcomes := { }
    var preview := { }

    if _preview_mode == PreviewMode.MOBILITY_AIM:
        _apply_mobility_preview(preview, outcomes)
    else:
        preview["aim_cell"] = _player.cell + _aim_direction()
        var aim_enemy := _engine.enemy_at(preview["aim_cell"])
        if aim_enemy != null:
            outcomes[aim_enemy.get_grid_pos()] = _outcome_entry(aim_enemy, _player.cell, PLAYER_ATTACK_DAMAGE, false)

    if not outcomes.is_empty():
        preview["outcomes"] = outcomes.values()
    _view.set_preview(preview)


func _apply_mobility_preview(preview: Dictionary, outcomes: Dictionary) -> void:
    var payload := _run_build.get_mobility_payload()
    if payload == RunBuild.PAYLOAD_DASH:
        var plan := _compute_dash_plan()
        preview["dash_path"] = plan["path"]
        preview["dash_legal"] = plan["legal"]
        if bool(plan["legal"]):
            preview["dash_landing"] = plan["landing"]
            preview["ghost_cell"] = plan["landing"]
            var dir: Vector2i = plan["dir"]
            for victim: GridEnemy in plan["victims"]:
                outcomes[victim.get_grid_pos()] = _outcome_entry(victim, victim.get_grid_pos() - dir, PLAYER_DASH_DAMAGE, true)
        return
    if payload == RunBuild.PAYLOAD_DEBUG_STUB:
        var target := _player.cell + _aim_direction()
        preview["dash_path"] = [target]
        preview["dash_legal"] = _engine.is_cell_open_for_player(target)
        if bool(preview["dash_legal"]):
            preview["dash_landing"] = target
            preview["ghost_cell"] = target
        return
    ToastManager.show_dev_error("TickArena: unknown mobility payload %s" % payload)


## Predicts one hit for the preview and condenses it into a display entry: cell, label, and intensity tier.
func _outcome_entry(enemy: GridEnemy, origin_cell: Vector2i, damage: float, is_dash: bool) -> Dictionary:
    var result := enemy.predict_hit(origin_cell, damage, is_dash)
    var label := ""
    var tier := 0
    if bool(result["killed"]):
        label = "KILL"
        tier = 2
    elif bool(result["stagger_burst"]):
        label = "BURST"
        tier = 1
    elif bool(result["guard_broken"]):
        label = "%s BREAK" % _angle_name(result["angle"]).to_upper()
        tier = 1
    else:
        label = _angle_name(result["angle"]).to_upper()
    return { "cell": enemy.get_grid_pos(), "label": label, "tier": tier }


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
    var payload := _run_build.get_mobility_payload()
    if payload == RunBuild.PAYLOAD_DASH:
        return "DASH"
    if payload == RunBuild.PAYLOAD_DEBUG_STUB:
        return "DEBUG STUB"
    return "UNKNOWN"


func _angle_name(angle: int) -> String:
    match angle:
        DirectionResolver.HitAngle.FRONT:
            return "Front"
        DirectionResolver.HitAngle.SIDE:
            return "Side"
        DirectionResolver.HitAngle.BACK:
            return "BACK"
        DirectionResolver.HitAngle.NONE:
            return "Side"
        _:
            ToastManager.show_dev_error("TickArena: unexpected hit angle %d" % angle)
            return "?"
