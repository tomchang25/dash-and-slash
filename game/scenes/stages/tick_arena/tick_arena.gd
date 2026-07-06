# tick_arena.gd
# Tick arena scene root (debug-only until cutover; run the scene directly). Validates and executes
# player verbs (tick resolution stage 1), then hands world advancement to the TickEngine; also owns
# spawning, previews with resolved outcomes, HUD, and prototype-parity debug shortcuts.
extends Node2D

enum AimMode {
    ATTACK,
    MOBILITY,
}

# -- Constants --

const SmallEnemyScene := preload("res://game/entities/enemies/small_enemy.tscn")
const ChargeEnemyScene := preload("res://game/entities/enemies/charge_enemy.tscn")
const PuffEnemyScene := preload("res://game/entities/enemies/puff_enemy.tscn")
const ModeEnemyScene := preload("res://game/entities/enemies/mode_enemy.tscn")

const PLAYER_ATTACK_DAMAGE := 20.0
const PLAYER_DASH_DAMAGE := 30.0
const PLAYER_SMASH_DAMAGE := 30.0
const DASH_RANGE := 5
const DASH_COOLDOWN_TICKS := 4
const SMASH_RANGE := 3
const SMASH_COOLDOWN_TICKS := 6
const MESSAGE_SEC := 1.6
const SMALL_SPAWN_COUNT := 2
const CHARGER_SPAWN_COUNT := 1
const PUFF_SPAWN_COUNT := 1
const MODE_SPAWN_COUNT := 1
const SPAWN_MIN_PLAYER_DISTANCE := 4
const BACKGROUND_COLOR := Color(0.09, 0.1, 0.12)

# -- State --

var _aim_mode := AimMode.ATTACK
var _smash_cancel_confirm_open := false
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
@onready var _smash_cancel_confirm_panel: Control = %SmashCancelConfirmPanel
@onready var _smash_cancel_confirm_button: Button = %SmashCancelConfirmButton
@onready var _smash_cancel_keep_button: Button = %SmashCancelKeepButton

# == Lifecycle ==


func _ready() -> void:
    _input.verb_requested.connect(_on_verb_requested)
    _engine.world_advanced.connect(_on_world_advanced)
    _engine.attack_detonated.connect(_on_attack_detonated)
    _engine.player_died.connect(_on_player_died)
    _smash_cancel_confirm_button.pressed.connect(_on_smash_cancel_confirm_pressed)
    _smash_cancel_keep_button.pressed.connect(_on_smash_cancel_keep_pressed)

    _rng.randomize()
    RenderingServer.set_default_clear_color(BACKGROUND_COLOR)
    _player.setup(_grid, _grid.grid_size / 2)
    _spawn_enemies()
    _controls_label.text = "WASD step · Hold Alt for Mobility Mode · LMB confirm · RMB cancel · Space wait · T debug payload · R reset"
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
                if not _smash_cancel_confirm_open:
                    _toggle_mobility_mode()
            KEY_R:
                _reset_run("Run reset.")

# == Signal handlers ==


## While the Smash cancel-confirm popup is open, every arena verb is blocked — only the popup's own
## buttons (Do Nothing / Cancel Attack) can resolve it, so a stray click or key press can never sneak
## past it and act on the game underneath.
func _on_verb_requested(verb: Dictionary) -> void:
    if _smash_cancel_confirm_open:
        return
    var consumed := false
    match String(verb.get("type", "")):
        "move":
            consumed = _verb_move(verb["dir"])
        "confirm":
            if not (bool(verb.get("repeat", false)) and not _confirm_is_attack()):
                consumed = _verb_confirm()
        "mode_set":
            _set_aim_mode(bool(verb.get("mobility", false)))
        "cancel":
            _verb_cancel()
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


func _on_smash_cancel_confirm_pressed() -> void:
    _player.disarm_smash()
    _close_smash_cancel_confirm()
    _set_message("Smash windup cancelled.")


func _on_smash_cancel_keep_pressed() -> void:
    _close_smash_cancel_confirm()

# == Player verbs (tick resolution stage 1) ==


## Movement requires confirmation to cancel an armed Smash windup, same as an explicit right-click
## cancel; the move itself is withheld this tick while the confirmation popup is pending.
func _verb_move(dir: Vector2i) -> bool:
    if not _try_cancel_smash_windup():
        return false
    var target := _player.cell + dir
    if not _engine.is_cell_open_for_player(target):
        _view.flash_deny(target)
        return false
    _player.move_to(target)
    return true


## Dispatches the command-style left-click confirm to the active aim mode's handler. An armed Smash
## always claims the confirm, regardless of Alt state, so it can be released without first re-entering
## Mobility Mode.
func _verb_confirm() -> bool:
    if _confirm_is_attack():
        return _verb_attack()
    return _verb_mobility()


## Whether the next confirm resolves to a normal attack: only when in Attack Mode with no Smash armed.
func _confirm_is_attack() -> bool:
    return _aim_mode == AimMode.ATTACK and not _player.is_smash_armed()


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
    if payload == RunBuild.PAYLOAD_SMASH:
        return _verb_smash()
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


## First confirm arms the windup on a locked landing cell (costs one tick, enemies act one beat)
## the next confirm releases the leap and 3x3 hit regardless of where the mouse is now aimed.
func _verb_smash() -> bool:
    if not _player.is_smash_armed():
        if _player.smash_cooldown > 0:
            _set_message("Smash on cooldown (%d)." % _player.smash_cooldown)
            return false
        var target := _clamped_smash_target()
        if not _engine.is_cell_open_for_player(target):
            _view.flash_deny(target)
            return false
        _player.arm_smash(target)
        _close_smash_cancel_confirm()
        SmashFeedbackVFX.play_windup(_player.global_position, self)
        AudioManager.play_event(_player.smash_windup_sfx_event, _player.global_position)
        _set_message("Smash windup...")
        return true

    var landing := _player.smash_target
    if not _engine.is_cell_open_for_player(landing):
        _view.flash_deny(landing)
        return false
    _view.flash_swing(_smash_area(landing))
    var hit_any := false
    for enemy: GridEnemy in _engine.actors():
        if _chebyshev(enemy.get_grid_pos() - landing) <= 1:
            hit_any = true
            _apply_player_hit(enemy, landing, PLAYER_SMASH_DAMAGE, true)
    if not hit_any:
        _apply_player_result_message(TickHitResolver.empty_outcome())
    SmashFeedbackVFX.play_impact(_grid.cell_center(landing), self)
    AudioManager.play_event(_player.smash_impact_sfx_event, _grid.cell_center(landing))
    _player.move_to(landing, true)
    _player.disarm_smash()
    _player.smash_cooldown = SMASH_COOLDOWN_TICKS
    _close_smash_cancel_confirm()
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


## Holding Alt selects Mobility Mode; releasing it returns to Attack Mode. Switching never consumes a
## tick or disturbs an armed Smash windup, since only an executed verb (move/attack/wait) or an
## explicit cancel does that.
func _set_aim_mode(mobility: bool) -> void:
    _aim_mode = AimMode.MOBILITY if mobility else AimMode.ATTACK


## Right click requests cancellation of the armed Smash windup, the same confirmation gate movement uses.
func _verb_cancel() -> void:
    _try_cancel_smash_windup()


## Cancels an armed smash unconditionally when Attack or Wait executes, or when the debug payload
## toggle switches away from Smash; the windup tick already spent is not refunded. These verbs are not
## gated behind the confirm-cancel popup — only right-click and movement are.
func _cancel_smash_windup() -> void:
    if _player.is_smash_armed():
        _player.disarm_smash()
        _close_smash_cancel_confirm()
        _set_message("Windup cancelled.")


## Requests cancellation of the armed Smash windup, gated behind the confirm-cancel setting. Returns
## true when the caller's action may proceed this tick (nothing was armed, or the setting is disabled
## and the windup was cancelled immediately); returns false when a confirm popup is now pending — or
## already pending from an earlier request — and the caller's action must not proceed this tick.
func _try_cancel_smash_windup() -> bool:
    if not _player.is_smash_armed():
        return true
    if _smash_cancel_confirm_open:
        return false
    if not SettingsStore.confirm_smash_cancel:
        _player.disarm_smash()
        _set_message("Smash windup cancelled.")
        return true
    _open_smash_cancel_confirm()
    return false


func _open_smash_cancel_confirm() -> void:
    _smash_cancel_confirm_open = true
    _smash_cancel_confirm_panel.visible = true


func _close_smash_cancel_confirm() -> void:
    _smash_cancel_confirm_open = false
    _smash_cancel_confirm_panel.visible = false


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


## Clamps the mouse-aimed cell to the Smash range box independently per axis.
func _clamped_smash_target() -> Vector2i:
    var delta := _mouse_cell() - _player.cell
    delta.x = clampi(delta.x, -SMASH_RANGE, SMASH_RANGE)
    delta.y = clampi(delta.y, -SMASH_RANGE, SMASH_RANGE)
    return _player.cell + delta


## Returns the 3x3 block of cells centered on the given landing cell.
func _smash_area(center: Vector2i) -> Array[Vector2i]:
    var area: Array[Vector2i] = []
    for ox in range(-1, 2):
        for oy in range(-1, 2):
            area.append(center + Vector2i(ox, oy))
    return area


func _chebyshev(delta: Vector2i) -> int:
    return maxi(absi(delta.x), absi(delta.y))

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
    _aim_mode = AimMode.ATTACK
    _close_smash_cancel_confirm()
    _spawn_enemies()
    _refresh_danger()
    _refresh_hud()
    _set_message(reason)


## Cycles the debug-prototype mobility payload (Dash -> Smash -> debug stub -> Dash); writes through
## the same RunBuild override real Major effects use. A proper debug surface for Major state at large
## is Phase 04a's job — this keyboard accelerator only predates and outlives it as a fast local toggle.
func _toggle_mobility_mode() -> void:
    _cancel_smash_windup()
    var payload := _run_build.get_mobility_payload()
    if payload == RunBuild.PAYLOAD_DASH:
        _run_build.set_mobility_payload_override(RunBuild.PAYLOAD_SMASH)
    elif payload == RunBuild.PAYLOAD_SMASH:
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

    if _player.is_smash_armed():
        _apply_locked_smash_preview(preview, outcomes)
    elif _aim_mode == AimMode.MOBILITY:
        _apply_mobility_preview(preview, outcomes)
    else:
        preview["aim_cell"] = _player.cell + _aim_direction()
        var aim_enemy := _engine.enemy_at(preview["aim_cell"])
        if aim_enemy != null:
            outcomes[aim_enemy.get_grid_pos()] = _outcome_entry(aim_enemy, _player.cell, PLAYER_ATTACK_DAMAGE, false)

    if not outcomes.is_empty():
        preview["outcomes"] = outcomes.values()
    _view.set_preview(preview)


## Only reached while no Smash is armed, since an armed windup's preview is locked in by
## _update_preview() before this is ever called.
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
    if payload == RunBuild.PAYLOAD_SMASH:
        var target := _clamped_smash_target()
        preview["smash_center"] = target
        preview["smash_legal"] = _engine.is_cell_open_for_player(target)
        if bool(preview["smash_legal"]):
            preview["ghost_cell"] = target
            _collect_smash_outcomes(target, outcomes)
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


## Collects predicted outcomes for every living enemy in the 3x3 block centered on the given cell.
func _collect_smash_outcomes(center: Vector2i, outcomes: Dictionary) -> void:
    for enemy: GridEnemy in _engine.actors():
        if _chebyshev(enemy.get_grid_pos() - center) <= 1:
            outcomes[enemy.get_grid_pos()] = _outcome_entry(enemy, center, PLAYER_SMASH_DAMAGE, true)


## Shows the locked Smash landing and its outcomes regardless of the current aim mode, since an armed
## windup is a standing commitment the player can glance at even while briefly back in Attack Mode.
func _apply_locked_smash_preview(preview: Dictionary, outcomes: Dictionary) -> void:
    preview["smash_armed_center"] = _player.smash_target
    preview["ghost_cell"] = _player.smash_target
    _collect_smash_outcomes(_player.smash_target, outcomes)


func _refresh_hud() -> void:
    _stats_label.text = "HP %d/%d    Dash CD %d    Smash CD %d    Mode: %s    Mobility: %s    Tick %d\n%s" % [
        int(_player.hp),
        int(TickPlayer.MAX_HP),
        _player.dash_cooldown,
        _player.smash_cooldown,
        _aim_mode_name(),
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
    if payload == RunBuild.PAYLOAD_SMASH:
        return "SMASH"
    if payload == RunBuild.PAYLOAD_DEBUG_STUB:
        return "DEBUG STUB"
    return "UNKNOWN"


func _aim_mode_name() -> String:
    return "ATTACK" if _aim_mode == AimMode.ATTACK else "MOBILITY"


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
