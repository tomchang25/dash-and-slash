# tick_action_controller.gd
# Owns tick-arena verb dispatch (move, confirm/attack, class Mobility, wait), Speed meter
# spend/fill, Chain Dash cooldown-clear/Speed-ready state, hit application, and the decision to
# advance the tick world (tick resolution stage 1); world advancement itself is handed to TickEngine. Result
# presentation (Major-trigger VFX) belongs to TickCombatFeedback.
# Aim/plan resolution (mouse cell, aim direction, dash/smash plans) is shared with TickPreviewController
# through TickAimContext; the presentation-only facing direction is owned here too and read by
# TickPreviewController each frame. Facing only ever changes on a discrete input event (keyboard move,
# a click that resolves attack/Dash/Smash, or the mouse hovering into a new aim cell) — never recomputed
# continuously from a stationary cursor — so it cannot drift out from under the player between events.
# May mutate TickPlayer, RunBuild, enemy health through the existing hit path, and TickGridView
# input-driven feedback flashes; may request world advancement from TickEngine, but never owns tick
# count, actor energy, wave state, reward state, spawn queues, or terrain cadence.
class_name TickActionController
extends Node

signal state_changed

enum AimMode {
    ATTACK,
    MOBILITY,
}

# -- Exports --

@export var grid: GridArena
@export var view: TickGridView
@export var engine: TickEngine
@export var player: TickPlayer
@export var feedback: TickCombatFeedback
@export var smash_cancel_confirm_panel: Control
@export var smash_cancel_confirm_button: Button
@export var smash_cancel_keep_button: Button

# -- State --

var _run_build: RunBuild
var _character_class: CharacterClassData
var _aim_context: TickAimContext
var _aim_mode := AimMode.ATTACK
var _smash_cancel_confirm_open := false
var _input_locked := false
var _last_aim := Vector2i.RIGHT
var _facing_direction := Vector2i.RIGHT

# == Lifecycle ==


func _ready() -> void:
    smash_cancel_confirm_button.pressed.connect(_on_smash_cancel_confirm_pressed)
    smash_cancel_keep_button.pressed.connect(_on_smash_cancel_keep_pressed)

# == Signal handlers ==


func _on_smash_cancel_confirm_pressed() -> void:
    player.disarm_smash()
    _close_smash_cancel_confirm()


func _on_smash_cancel_keep_pressed() -> void:
    _close_smash_cancel_confirm()

# == Common API ==


## Stores the run build and immutable active class distributed by the tick arena root.
func setup(run_build: RunBuild, character_class: CharacterClassData) -> void:
    _run_build = run_build
    _character_class = character_class
    _aim_context = TickAimContext.new(grid, engine, player, run_build, func() -> Vector2i: return _last_aim)


## Replaces the active class only at the arena's run-reset boundary.
func set_character_class(character_class: CharacterClassData) -> void:
    _character_class = character_class


## Locks or unlocks verb dispatch; the run controller locks input while the wave-clear banner and
## reward choice are pending so no verb can act on a run that is about to be replaced.
func set_input_locked(locked: bool) -> void:
    _input_locked = locked


## Restores aim mode and clears any armed Smash windup for a fresh run; called by the run
## controller's reset seam before it respawns enemies.
func reset_for_new_run() -> void:
    _aim_mode = AimMode.ATTACK
    _facing_direction = Vector2i.RIGHT
    _close_smash_cancel_confirm()


func is_mobility_mode() -> bool:
    return _aim_mode == AimMode.MOBILITY


## Returns the last non-zero aim direction, shared read-only with the preview controller so its aim
## preview can never disagree with what a confirm would actually resolve.
func get_last_aim() -> Vector2i:
    return _last_aim


## Returns the presentation-only facing direction, shared read-only with the preview controller so the
## body/weapon marker only ever reflects a discrete input event (see class doc), never a continuously
## recomputed cursor delta.
func get_facing_direction() -> Vector2i:
    return _facing_direction


## Reports the mouse hovering into a new aim cell — called by TickPreviewController only on the frame
## the resolved mouse cell actually changes, so idle cursor presence never touches facing.
func report_cursor_hover(direction: Vector2i) -> void:
    if direction != Vector2i.ZERO:
        _facing_direction = direction


## Cancels an armed Smash unconditionally through the shared cleanup path.
func cancel_smash_windup() -> void:
    if player.is_smash_armed():
        player.disarm_smash()
        _close_smash_cancel_confirm()


## While the Smash cancel-confirm popup is open, every arena verb is blocked — only the popup's own
## buttons (Do Nothing / Cancel Attack) can resolve it, so a stray click or key press can never sneak
## past it and act on the game underneath.
## Verbs return an action result (`{ "consumed": bool, "advances_world": bool }`) instead of a bare
## bool: a consumed verb only advances the world when it was not a Speed-meter free move/attack, and
## illegal inputs stay consumed false per the shared verb-result contract.
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
        # A Speed-spent free move/attack still changed HUD-visible state (the meter) even though the
        # world did not advance, so the HUD must refresh here too.
        state_changed.emit()

# == Player verbs (tick resolution stage 1) ==


## Movement requires confirmation to cancel an armed Smash windup, same as an explicit right-click
## cancel; the move itself is withheld this tick while the confirmation popup is pending. Move is one
## of the two Speed-eligible actions: a full meter spends here and lets this step skip world advancement.
## When the SettingsStore auto-attack-on-move preference is on and Attack Mode is active with no Smash
## armed, walking into an enemy's cell swings at it instead of just denying the move.
func _verb_move(dir: Vector2i) -> Dictionary:
    _facing_direction = dir
    if not _try_cancel_smash_windup():
        return _verb_illegal()
    var target := player.cell + dir
    if not engine.is_cell_open_for_player(target):
        if SettingsStore.auto_attack_on_move and _confirm_is_attack() and engine.enemy_at(target) != null:
            return _resolve_attack(dir)
        view.flash_deny(target)
        return _verb_illegal()
    _tick_player_action_upkeep()
    var free_action := _spend_speed_if_full()
    player.move_to(target)
    _fill_speed_meter()
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
## free. Normal attack is the second Speed-eligible action, accounted for the same way as move. The
## click resolving this counts as a facing event, same as a keyboard move.
func _verb_attack() -> Dictionary:
    cancel_smash_windup()
    var aim := _aim_context.aim_direction()
    _facing_direction = aim
    return _resolve_attack(aim)


## Shared normal-attack resolution for the mouse-aim confirm and the move-into-enemy auto-attack:
## both swing at the given adjacent direction and consume the tick the same way, whiff or hit.
func _resolve_attack(aim: Vector2i) -> Dictionary:
    _last_aim = aim
    var target := player.cell + aim
    _tick_player_action_upkeep()
    player.play_action_whoosh()
    view.flash_swing([target])
    player.play_normal_attack_visual(aim)
    var free_action := _spend_speed_if_full()
    var enemy := engine.enemy_at(target)
    if enemy != null:
        _apply_player_hit(enemy, player.cell, TickCombatProjection.normal_attack_damage(_run_build))
    _fill_speed_meter()
    return _verb_result(not free_action)


func _verb_mobility() -> Dictionary:
    if _character_class == null:
        ToastManager.show_dev_error("TickActionController: missing CharacterClassData")
        return _verb_illegal()
    if _character_class.mobility_id == CharacterClassData.MOBILITY_DASH:
        return _verb_dash()
    if _character_class.mobility_id == CharacterClassData.MOBILITY_SMASH:
        return _verb_smash()
    ToastManager.show_dev_error("TickActionController: unknown class Mobility %s" % _character_class.mobility_id)
    return _verb_illegal()


func _verb_dash() -> Dictionary:
    if player.dash_cooldown > 0:
        return _verb_illegal()
    var plan := _aim_context.compute_dash_plan()
    _facing_direction = plan["dir"]
    if not bool(plan["legal"]):
        view.flash_deny(player.cell + plan["dir"] * _aim_context.dash_range())
        return _verb_illegal()
    _tick_player_action_upkeep()
    player.play_action_whoosh()
    var dir: Vector2i = plan["dir"]
    var guard_shredder := TickCombatProjection.has_dash_guard_shredder(_run_build)
    var execution := TickCombatProjection.has_dash_execution(_run_build)
    var sfx_context := _build_mobility_sfx_context()
    var outcomes: Array[TickHitOutcome] = []
    for victim: GridEnemy in plan["victims"]:
        outcomes.append(
            _apply_player_hit(
                victim,
                victim.get_grid_pos() - dir,
                TickCombatProjection.mobility_attack_damage(_run_build, TickCombatRules.PLAYER_DASH_DAMAGE),
                guard_shredder,
                execution,
                TickCombatProjection.mobility_stagger_burst_multiplier(),
                sfx_context,
            ),
        )
    view.flash_swing(plan["path"])
    player.move_to(plan["landing"], true)
    player.dash_cooldown = TickCombatProjection.mobility_cooldown_ticks(_run_build, TickCombatRules.DASH_COOLDOWN_TICKS)
    _apply_chain_dash_state(outcomes)
    return _verb_result(true)


## First confirm arms the windup on a locked landing cell (costs one tick, enemies act one beat)
## the next confirm releases the leap and 3x3 hit regardless of where the mouse is now aimed. Arming
## has no attack outcome and neither phase can inherit Dash-only Major triggers such as Chain Dash.
## The arming click also sets the presentation-only facing direction toward the locked target, same
## as a Dash confirm.
func _verb_smash() -> Dictionary:
    if not player.is_smash_armed():
        if player.smash_cooldown > 0:
            return _verb_illegal()
        var target := _aim_context.clamped_smash_target()
        _facing_direction = _aim_context.aim_direction()
        if not engine.is_cell_open_for_player(target):
            view.flash_deny(target)
            return _verb_illegal()
        _tick_player_action_upkeep()
        player.arm_smash(target)
        _close_smash_cancel_confirm()
        SmashFeedbackVFX.play_windup(player.global_position, self)
        AudioManager.play_event(player.smash_windup_sfx_event, player.global_position)
        return _verb_result(true)

    var landing := player.smash_target
    if not engine.is_cell_open_for_player(landing):
        view.flash_deny(landing)
        return _verb_illegal()
    _tick_player_action_upkeep()
    view.flash_swing(_aim_context.smash_area(landing))
    var sfx_context := _build_mobility_sfx_context()
    for enemy: GridEnemy in engine.actors():
        if _aim_context.chebyshev(enemy.get_grid_pos() - landing) <= 1:
            _apply_player_hit(
                enemy,
                landing,
                TickCombatProjection.mobility_attack_damage(_run_build, TickCombatRules.PLAYER_SMASH_DAMAGE),
                false,
                false,
                TickCombatProjection.mobility_stagger_burst_multiplier(),
                sfx_context,
            )
    SmashFeedbackVFX.play_impact(grid.cell_center(landing), self)
    AudioManager.play_event(player.smash_impact_sfx_event, grid.cell_center(landing))
    player.move_to(landing, true)
    player.disarm_smash()
    player.smash_cooldown = TickCombatProjection.mobility_cooldown_ticks(_run_build, TickCombatRules.SMASH_COOLDOWN_TICKS)
    _close_smash_cancel_confirm()
    return _verb_result(true)


func _verb_wait() -> Dictionary:
    cancel_smash_windup()
    _tick_player_action_upkeep()
    return _verb_result(true)


## Shared verb-result shape for a consumed verb: consumed is always true, advances_world is false only
## for a Speed-meter free move/attack.
func _verb_result(advances_world: bool) -> Dictionary:
    return { "consumed": true, "advances_world": advances_world }


## Shared verb-result shape for an illegal input: consumes nothing and never advances the world.
func _verb_illegal() -> Dictionary:
    return { "consumed": false, "advances_world": false }


## Advances player-side per-action upkeep for a consumed verb. This is intentionally separate from
## TickEngine.advance_world() so free actions reduce player cooldowns without advancing enemy clocks,
## spawn warnings, or attack telegraphs.
func _tick_player_action_upkeep() -> void:
    player.tick_cooldowns()


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


## Applies Chain Dash's state change once when any outcome from this Dash qualifies: clears Dash
## cooldown and prepares the Speed meter as a ready follow-up free action. Several qualifying victims
## still apply this once. The triggering Dash itself still advances the world normally; only the
## later free move/attack that spends the prepared meter skips it.
func _apply_chain_dash_state(outcomes: Array[TickHitOutcome]) -> void:
    if not TickCombatProjection.has_chain_dash(_run_build):
        return
    if not TickHitResolver.any_qualifies_for_chain_dash(outcomes):
        return
    player.dash_cooldown = 0
    player.prepare_speed_free_action()


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
        return true
    _open_smash_cancel_confirm()
    return false


func _open_smash_cancel_confirm() -> void:
    _smash_cancel_confirm_open = true
    smash_cancel_confirm_panel.visible = true


func _close_smash_cancel_confirm() -> void:
    _smash_cancel_confirm_open = false
    smash_cancel_confirm_panel.visible = false


## Builds the shared Dash/Smash Result SFX context from player-owned event references, so both
## mobility actions resolve their mobility-kill, Guard Shredder, and Execution overrides through the
## same immutable object. A normal attack passes no context at all, keeping every branch on its
## generic enemy-owned event.
func _build_mobility_sfx_context() -> TickHitSfxContext:
    return TickHitSfxContext.new(player.mobility_kill_sfx_event, player.guard_shredder_sfx_event, player.execution_sfx_event)


## Resolves one committed player hit and returns the resolver outcome so mobility strike loops can
## collect it for Chain Dash's qualification check instead of losing it. sfx_context is the Dash/Smash
## Result SFX override context; normal attack passes none, keeping generic feedback. A kill needs no
## explicit removal here: take_hit() synchronously fires the enemy's died signal, which the wave
## controller (via the spawner's died_callback) already uses to drop it from alive-count tracking.
func _apply_player_hit(
        enemy: GridEnemy,
        origin_cell: Vector2i,
        damage: float,
        guard_shredder_trigger := false,
        execution_trigger := false,
        stagger_burst_multiplier := TickCombatRules.STAGGER_ATTACK_MULTIPLIER,
        sfx_context: TickHitSfxContext = null,
) -> TickHitOutcome:
    var enemy_pos := enemy.global_position
    var result := enemy.take_hit(origin_cell, damage, guard_shredder_trigger, execution_trigger, stagger_burst_multiplier, sfx_context)
    feedback.report_hit_outcome(result, enemy_pos)
    return result
