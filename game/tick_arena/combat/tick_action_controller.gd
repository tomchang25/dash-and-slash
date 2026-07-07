# tick_action_controller.gd
# Owns tick-arena verb dispatch (move, confirm/attack, mobility payloads, wait), Speed meter
# spend/fill, Mobility Free Action refunds, hit application, action feedback messages, and the
# decision to advance the tick world (tick resolution stage 1); world advancement itself is handed
# to TickEngine. May mutate TickPlayer, RunBuild, enemy health through the existing hit path, and
# TickGridView feedback flashes; may request world advancement from TickEngine, but never owns tick
# count, actor energy, wave state, reward state, spawn queues, or terrain cadence.
class_name TickActionController
extends Node

signal state_changed

enum AimMode {
    ATTACK,
    MOBILITY,
}

# -- Constants --

const MESSAGE_SEC := 1.6

# -- Exports --

@export var grid: GridArena
@export var view: TickGridView
@export var engine: TickEngine
@export var player: TickPlayer
@export var smash_cancel_confirm_panel: Control
@export var smash_cancel_confirm_button: Button
@export var smash_cancel_keep_button: Button

# -- State --

var _run_build: RunBuild
var _aim_mode := AimMode.ATTACK
var _smash_cancel_confirm_open := false
var _input_locked := false
var _last_aim := Vector2i.RIGHT
var _message := ""
var _message_time := 0.0

# == Lifecycle ==


func _ready() -> void:
    smash_cancel_confirm_button.pressed.connect(_on_smash_cancel_confirm_pressed)
    smash_cancel_keep_button.pressed.connect(_on_smash_cancel_keep_pressed)


func _process(delta: float) -> void:
    _update_message(delta)

# == Signal handlers ==


func _on_smash_cancel_confirm_pressed() -> void:
    player.disarm_smash()
    _close_smash_cancel_confirm()
    set_message("Smash windup cancelled.")


func _on_smash_cancel_keep_pressed() -> void:
    _close_smash_cancel_confirm()

# == Common API ==


## Stores the run build this controller reads Speed stacks, mobility payload, and mobility
## triggers from; the tick arena root owns and constructs the shared RunBuild instance.
func setup(run_build: RunBuild) -> void:
    _run_build = run_build


## Locks or unlocks verb dispatch; the run controller locks input while the wave-clear banner and
## reward choice are pending so no verb can act on a run that is about to be replaced.
func set_input_locked(locked: bool) -> void:
    _input_locked = locked


## Restores aim mode and clears any armed Smash windup for a fresh run; called by the run
## controller's reset seam before it respawns enemies.
func reset_for_new_run() -> void:
    _aim_mode = AimMode.ATTACK
    _close_smash_cancel_confirm()


## Sets the HUD message text and restarts its display timer; exposed publicly so debug controls can
## post the same feedback real verb resolution uses instead of writing a second message path.
func set_message(text: String) -> void:
    _message = text
    _message_time = MESSAGE_SEC


func current_message() -> String:
    return _message


func is_mobility_mode() -> bool:
    return _aim_mode == AimMode.MOBILITY


func aim_mode_name() -> String:
    return "ATTACK" if _aim_mode == AimMode.ATTACK else "MOBILITY"


## Returns the last non-zero aim direction, shared read-only with the preview controller so its aim
## preview can never disagree with what a confirm would actually resolve.
func get_last_aim() -> Vector2i:
    return _last_aim


## Cancels an armed smash unconditionally, the same behavior Attack/Wait verbs use; exposed publicly
## so a debug mobility-payload switch can cancel a pending windup through this one path instead of
## duplicating the behavior.
func cancel_smash_windup() -> void:
    if player.is_smash_armed():
        player.disarm_smash()
        _close_smash_cancel_confirm()
        set_message("Windup cancelled.")


## While the Smash cancel-confirm popup is open, every arena verb is blocked — only the popup's own
## buttons (Do Nothing / Cancel Attack) can resolve it, so a stray click or key press can never sneak
## past it and act on the game underneath.
## Verbs return an action result (`{ "consumed": bool, "advances_world": bool }`) instead of a bare
## bool: a consumed verb only advances the world when it was not a Speed-meter or Mobility Free
## Action Major free action, and illegal inputs stay consumed false per the shared verb-result contract.
## The tick arena root connects TickInput's verb_requested signal directly to this method.
func handle_verb(verb: TickVerb) -> void:
    if _input_locked or _smash_cancel_confirm_open:
        return
    var result := _verb_illegal()
    match verb.kind:
        TickVerb.Kind.MOVE:
            result = _verb_move(verb.dir)
        TickVerb.Kind.CONFIRM:
            if not (verb.repeat and not _confirm_is_attack()):
                result = _verb_confirm()
        TickVerb.Kind.MODE_SET:
            _set_aim_mode(verb.mobility)
        TickVerb.Kind.CANCEL:
            _verb_cancel()
        TickVerb.Kind.WAIT:
            result = _verb_wait()
        _:
            ToastManager.show_dev_error("TickActionController: unknown verb kind %d" % verb.kind)
    if bool(result.get("advances_world", false)):
        engine.advance_world()
    elif bool(result.get("consumed", false)):
        # A free action (Speed spend or Mobility Free Action refund) still changed HUD-visible state
        # (the meter, a cooldown) even though the world did not advance, so the HUD must refresh here too.
        state_changed.emit()

# == Player verbs (tick resolution stage 1) ==


## Movement requires confirmation to cancel an armed Smash windup, same as an explicit right-click
## cancel; the move itself is withheld this tick while the confirmation popup is pending. Move is one
## of the two Speed-eligible actions: a full meter spends here and lets this step skip world advancement.
func _verb_move(dir: Vector2i) -> Dictionary:
    if not _try_cancel_smash_windup():
        return _verb_illegal()
    var target := player.cell + dir
    if not engine.is_cell_open_for_player(target):
        view.flash_deny(target)
        return _verb_illegal()
    var free_action := _spend_speed_if_full()
    player.move_to(target)
    _fill_speed_meter()
    if free_action:
        _append_message_suffix("Speed spent — free move!")
    return _verb_result(not free_action)


## Dispatches the command-style left-click confirm to the active aim mode's handler. An armed Smash
## always claims the confirm, regardless of Alt state, so it can be released without first re-entering
## Mobility Mode.
func _verb_confirm() -> Dictionary:
    if _confirm_is_attack():
        return _verb_attack()
    return _verb_mobility()


## Whether the next confirm resolves to a normal attack: only when in Attack Mode with no Smash armed.
func _confirm_is_attack() -> bool:
    return _aim_mode == AimMode.ATTACK and not player.is_smash_armed()


## Swings at the mouse-aimed adjacent cell; a whiff still consumes the tick, only illegal inputs are
## free. Normal attack is the second Speed-eligible action, accounted for the same way as move.
func _verb_attack() -> Dictionary:
    cancel_smash_windup()
    var aim := _aim_direction()
    _last_aim = aim
    var target := player.cell + aim
    view.flash_swing([target])
    var free_action := _spend_speed_if_full()
    var enemy := engine.enemy_at(target)
    if enemy != null:
        _apply_player_hit(enemy, player.cell, _normal_attack_damage())
    _fill_speed_meter()
    if free_action:
        _append_message_suffix("Speed spent — free attack!")
    return _verb_result(not free_action)


func _verb_mobility() -> Dictionary:
    var payload := _run_build.get_mobility_payload()
    if payload == RunBuild.PAYLOAD_DASH:
        return _verb_dash()
    if payload == RunBuild.PAYLOAD_SMASH:
        return _verb_smash()
    if payload == RunBuild.PAYLOAD_DEBUG_STUB:
        return _verb_debug_stub_mobility()
    ToastManager.show_dev_error("TickActionController: unknown mobility payload %s" % payload)
    return _verb_illegal()


func _verb_dash() -> Dictionary:
    if player.dash_cooldown > 0:
        set_message("Dash on cooldown (%d)." % player.dash_cooldown)
        return _verb_illegal()
    var plan := _compute_dash_plan()
    if not bool(plan["legal"]):
        view.flash_deny(player.cell + plan["dir"] * _mobility_range_cells(TickCombatRules.DASH_RANGE))
        return _verb_illegal()
    var dir: Vector2i = plan["dir"]
    var guard_shredder := _run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER)
    var execution := _run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION)
    var outcomes: Array[TickHitOutcome] = []
    for victim: GridEnemy in plan["victims"]:
        outcomes.append(_apply_player_hit(victim, victim.get_grid_pos() - dir, _mobility_attack_damage(TickCombatRules.PLAYER_DASH_DAMAGE), guard_shredder, execution))
    if outcomes.is_empty():
        _apply_player_result_message(TickHitResolver.empty_outcome())
    view.flash_swing(plan["path"])
    player.move_to(plan["landing"], true)
    player.dash_cooldown = _mobility_cooldown_ticks(TickCombatRules.DASH_COOLDOWN_TICKS)
    var refunds := _mobility_action_refunds(outcomes)
    if refunds:
        _append_message_suffix("Mobility refunded — free!")
    return _verb_result(not refunds)


## First confirm arms the windup on a locked landing cell (costs one tick, enemies act one beat)
## the next confirm releases the leap and 3x3 hit regardless of where the mouse is now aimed. Arming
## has no attack outcome and can never refund; only the release can.
func _verb_smash() -> Dictionary:
    if not player.is_smash_armed():
        if player.smash_cooldown > 0:
            set_message("Smash on cooldown (%d)." % player.smash_cooldown)
            return _verb_illegal()
        var target := _clamped_smash_target()
        if not engine.is_cell_open_for_player(target):
            view.flash_deny(target)
            return _verb_illegal()
        player.arm_smash(target)
        _close_smash_cancel_confirm()
        SmashFeedbackVFX.play_windup(player.global_position, self)
        AudioManager.play_event(player.smash_windup_sfx_event, player.global_position)
        set_message("Smash windup...")
        return _verb_result(true)

    var landing := player.smash_target
    if not engine.is_cell_open_for_player(landing):
        view.flash_deny(landing)
        return _verb_illegal()
    view.flash_swing(_smash_area(landing))
    var guard_shredder := _run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER)
    var execution := _run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION)
    var outcomes: Array[TickHitOutcome] = []
    for enemy: GridEnemy in engine.actors():
        if _chebyshev(enemy.get_grid_pos() - landing) <= 1:
            outcomes.append(_apply_player_hit(enemy, landing, _mobility_attack_damage(TickCombatRules.PLAYER_SMASH_DAMAGE), guard_shredder, execution))
    if outcomes.is_empty():
        _apply_player_result_message(TickHitResolver.empty_outcome())
    SmashFeedbackVFX.play_impact(grid.cell_center(landing), self)
    AudioManager.play_event(player.smash_impact_sfx_event, grid.cell_center(landing))
    player.move_to(landing, true)
    player.disarm_smash()
    player.smash_cooldown = _mobility_cooldown_ticks(TickCombatRules.SMASH_COOLDOWN_TICKS)
    _close_smash_cancel_confirm()
    var refunds := _mobility_action_refunds(outcomes)
    if refunds:
        _append_message_suffix("Mobility refunded — free!")
    return _verb_result(not refunds)


func _verb_debug_stub_mobility() -> Dictionary:
    var target := player.cell + _aim_direction()
    if not engine.is_cell_open_for_player(target):
        view.flash_deny(target)
        return _verb_illegal()
    view.flash_swing([target])
    player.move_to(target, true)
    set_message("Debug mobility payload fired.")
    return _verb_result(true)


func _verb_wait() -> Dictionary:
    cancel_smash_windup()
    return _verb_result(true)


## Shared verb-result shape for a consumed verb: consumed is always true, advances_world is false only
## for a Speed-meter free move/attack or a Mobility Free Action Major refund.
func _verb_result(advances_world: bool) -> Dictionary:
    return { "consumed": true, "advances_world": advances_world }


## Shared verb-result shape for an illegal input: consumes nothing and never advances the world.
func _verb_illegal() -> Dictionary:
    return { "consumed": false, "advances_world": false }


## Spends a full Speed charge for the eligible move/attack now resolving, returning whether it was
## free. Spend happens before the action resolves so the underlying whiff/hit/move logic runs unchanged.
func _spend_speed_if_full() -> bool:
    var was_full := player.is_speed_meter_full()
    if was_full:
        player.spend_speed_meter()
    return was_full


## Fills the Speed meter after an eligible move/attack resolves, including a free one, from the run's
## current Speed stack total.
func _fill_speed_meter() -> void:
    player.fill_speed_meter(_run_build.total(RunBuild.CH_SPEED))


## Projects a mobility-slot payload's base cooldown through the run's Mobility Cooldown reduction, floored at 1 tick.
func _mobility_cooldown_ticks(base_ticks: int) -> int:
    return TickCombatRules.mobility_cooldown_ticks(base_ticks, int(_run_build.total(RunBuild.CH_MOBILITY_COOLDOWN)))


## Projects normal attack's base damage through the run's Normal Attack Damage bonus total.
func _normal_attack_damage() -> float:
    return TickCombatRules.normal_attack_damage(_run_build.total(RunBuild.CH_NORMAL_ATTACK_DAMAGE))


## Projects a mobility-slot payload's base damage (Dash or Smash) through the run's Mobility Attack
## Damage bonus total.
func _mobility_attack_damage(base_damage: float) -> float:
    return TickCombatRules.mobility_attack_damage(base_damage, _run_build.total(RunBuild.CH_MOBILITY_ATTACK_DAMAGE))


## Projects a mobility-slot payload's base range (in cells, Dash or Smash) through the run's Mobility
## Range percent bonus.
func _mobility_range_cells(base_range: int) -> int:
    return TickCombatRules.mobility_range_cells(base_range, _run_build.total(RunBuild.CH_MOBILITY_RANGE), TickCombatRules.MAX_MOBILITY_RANGE_BONUS_PERCENT)


## Whether a mobility-slot strike's collected hit outcomes refund this action's world advancement:
## the Mobility Free Action Major must be active, and at least one outcome must be a kill, guard
## break, or back-angle hit. A strike with several qualifying victims still refunds at most once.
func _mobility_action_refunds(outcomes: Array[TickHitOutcome]) -> bool:
    return _run_build.has_mobility_trigger(RunBuild.TRIGGER_MOBILITY_FREE_ACTION) and TickHitResolver.any_qualifies_for_mobility_free_action(outcomes)


## Appends a short suffix to the current HUD message instead of replacing it, so a Speed spend or
## Mobility Free Action refund note stays visible alongside whatever hit/whiff message the action already set.
func _append_message_suffix(suffix: String) -> void:
    set_message("%s (%s)" % [_message, suffix] if _message != "" else suffix)


## Holding Alt selects Mobility Mode; releasing it returns to Attack Mode. Switching never consumes a
## tick or disturbs an armed Smash windup, since only an executed verb (move/attack/wait) or an
## explicit cancel does that.
func _set_aim_mode(mobility: bool) -> void:
    _aim_mode = AimMode.MOBILITY if mobility else AimMode.ATTACK


## Right click requests cancellation of the armed Smash windup, the same confirmation gate movement uses.
func _verb_cancel() -> void:
    _try_cancel_smash_windup()


## Requests cancellation of the armed Smash windup, gated behind the confirm-cancel setting. Returns
## true when the caller's action may proceed this tick (nothing was armed, or the setting is disabled
## and the windup was cancelled immediately); returns false when a confirm popup is now pending — or
## already pending from an earlier request — and the caller's action must not proceed this tick.
func _try_cancel_smash_windup() -> bool:
    if not player.is_smash_armed():
        return true
    if _smash_cancel_confirm_open:
        return false
    if not SettingsStore.confirm_smash_cancel:
        player.disarm_smash()
        set_message("Smash windup cancelled.")
        return true
    _open_smash_cancel_confirm()
    return false


func _open_smash_cancel_confirm() -> void:
    _smash_cancel_confirm_open = true
    smash_cancel_confirm_panel.visible = true


func _close_smash_cancel_confirm() -> void:
    _smash_cancel_confirm_open = false
    smash_cancel_confirm_panel.visible = false


## Resolves one committed player hit and returns the resolver outcome so mobility strike loops can
## collect it for the Mobility Free Action Major's refund check instead of losing it. A kill needs
## no explicit removal here: take_hit() synchronously fires the enemy's died signal, which the wave
## controller (via the spawner's died_callback) already uses to drop it from alive-count tracking.
func _apply_player_hit(enemy: GridEnemy, origin_cell: Vector2i, damage: float, guard_shredder_trigger := false, execution_trigger := false) -> TickHitOutcome:
    var enemy_pos := enemy.global_position
    var result := enemy.take_hit(origin_cell, damage, guard_shredder_trigger, execution_trigger)
    _play_major_trigger_feedback(result, enemy_pos)
    _apply_player_result_message(result)
    return result


## Layers distinct temporary VFX/SFX for a mobility-slot-triggered Major's upgraded result on top of the
## shared hit feedback GridEnemy already played, so Shredder and Execution read clearly without silencing
## the fallback guard-break/kill feedback every hit already has.
func _play_major_trigger_feedback(result: TickHitOutcome, world_pos: Vector2) -> void:
    if result.major_trigger == TickHitOutcome.MajorTrigger.GUARD_SHREDDER:
        MajorTriggerFeedbackVFX.play_guard_shredder(world_pos, self)
        AudioManager.play_event(player.guard_shredder_sfx_event, world_pos)
    elif result.major_trigger == TickHitOutcome.MajorTrigger.EXECUTION:
        MajorTriggerFeedbackVFX.play_execution(world_pos, self)
        AudioManager.play_event(player.execution_sfx_event, world_pos)


func _apply_player_result_message(result: TickHitOutcome) -> void:
    match result.feedback_kind:
        TickHitOutcome.FeedbackKind.WHIFF:
            set_message("Whiff.")
        TickHitOutcome.FeedbackKind.KILL:
            if result.major_trigger == TickHitOutcome.MajorTrigger.EXECUTION:
                set_message("EXECUTION!")
            else:
                set_message("Enemy destroyed!")
        TickHitOutcome.FeedbackKind.GUARD_BREAK:
            if result.major_trigger == TickHitOutcome.MajorTrigger.GUARD_SHREDDER:
                set_message("GUARD SHREDDER!")
            else:
                set_message("%s hit — GUARD BREAK!" % TickCombatRules.angle_name(result.angle))
        TickHitOutcome.FeedbackKind.STAGGER_BURST:
            set_message("%s burst hit." % TickCombatRules.angle_name(result.angle))
        TickHitOutcome.FeedbackKind.BLOCKED:
            set_message("%s blocked." % TickCombatRules.angle_name(result.angle))
        TickHitOutcome.FeedbackKind.DAMAGED:
            set_message("%s hit." % TickCombatRules.angle_name(result.angle))
        _:
            ToastManager.show_dev_error("TickActionController: unexpected feedback kind %s" % result.feedback_kind)

# == Aiming and plans ==


func _mouse_cell() -> Vector2i:
    return TickActionPlanner.mouse_cell(grid)


func _aim_direction() -> Vector2i:
    return TickActionPlanner.aim_direction(_mouse_cell(), player.cell, _last_aim)


func _compute_dash_plan() -> Dictionary:
    return TickActionPlanner.compute_dash_plan(grid, engine, _mouse_cell(), player.cell, _last_aim, _mobility_range_cells(TickCombatRules.DASH_RANGE))


func _clamped_smash_target() -> Vector2i:
    return TickActionPlanner.clamped_smash_target(_mouse_cell(), player.cell, _mobility_range_cells(TickCombatRules.SMASH_RANGE))


func _smash_area(center: Vector2i) -> Array[Vector2i]:
    return TickActionPlanner.smash_area(center)


func _chebyshev(delta: Vector2i) -> int:
    return TickActionPlanner.chebyshev(delta)

# == Messages ==


func _update_message(delta: float) -> void:
    if _message_time <= 0.0:
        return
    _message_time -= delta
    if _message_time <= 0.0:
        _message = ""
        state_changed.emit()
