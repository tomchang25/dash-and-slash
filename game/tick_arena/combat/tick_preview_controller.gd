# tick_preview_controller.gd
# Owns read-only tick-arena preview calculation: mouse cell/aim resolution, dash plan previews,
# smash previews, and predicted outcome badges. Writes only view payloads to TickGridView and must
# never mutate player state, enemy state, run-build state, wave state, or world time. Shares aim/plan
# resolution with TickActionController through TickAimContext and combat base numbers through
# TickCombatRules so a preview can never disagree with what a commit resolves; the aim mode and
# last-aim direction it reads stay the action controller's own truth.
class_name TickPreviewController
extends Node

# -- Exports --

@export var grid: GridArena
@export var view: TickGridView
@export var engine: TickEngine
@export var player: TickPlayer
@export var action_controller: TickActionController

# -- State --

var _run_build: RunBuild
var _aim_context: TickAimContext

# == Lifecycle ==


func _process(_delta: float) -> void:
    _update_preview()

# == Common API ==


## Stores the run build this controller reads the mobility payload and mobility triggers from; the
## tick arena root owns and constructs the shared RunBuild instance.
func setup(run_build: RunBuild) -> void:
    _run_build = run_build
    _aim_context = TickAimContext.new(grid, engine, player, run_build, action_controller.get_last_aim)

# == Preview ==


## Recomputes the free aiming previews every frame; aiming never consumes a tick.
## Previews carry resolved outcomes (landing ghost, per-victim angle/result badges) computed by the
## same predict_hit math that resolves the commit, so the display can never lie.
func _update_preview() -> void:
    var outcomes := { }
    var preview := { }

    if player.is_smash_armed():
        _apply_locked_smash_preview(preview, outcomes)
    elif action_controller.is_mobility_mode():
        _apply_mobility_preview(preview, outcomes)
    else:
        preview["aim_cell"] = player.cell + _aim_context.aim_direction()
        var aim_enemy := engine.enemy_at(preview["aim_cell"])
        if aim_enemy != null:
            outcomes[aim_enemy.get_grid_pos()] = _outcome_entry(aim_enemy, player.cell, TickCombatProjection.normal_attack_damage(_run_build))

    if not outcomes.is_empty():
        preview["outcomes"] = outcomes.values()
    view.set_preview(preview)


## Only reached while no Smash is armed, since an armed windup's preview is locked in by
## _update_preview() before this is ever called.
func _apply_mobility_preview(preview: Dictionary, outcomes: Dictionary) -> void:
    var payload := _run_build.get_mobility_payload()
    if payload == RunBuild.PAYLOAD_DASH:
        var plan := _aim_context.compute_dash_plan()
        preview["dash_path"] = plan["path"]
        preview["dash_legal"] = plan["legal"]
        if bool(plan["legal"]):
            preview["dash_landing"] = plan["landing"]
            preview["ghost_cell"] = plan["landing"]
            var dir: Vector2i = plan["dir"]
            var guard_shredder := TickCombatProjection.has_mobility_guard_shredder(_run_build)
            var execution := TickCombatProjection.has_mobility_execution(_run_build)
            for victim: GridEnemy in plan["victims"]:
                outcomes[victim.get_grid_pos()] = _outcome_entry(
                    victim,
                    victim.get_grid_pos() - dir,
                    TickCombatProjection.mobility_attack_damage(_run_build, TickCombatRules.PLAYER_DASH_DAMAGE),
                    guard_shredder,
                    execution,
                    TickCombatProjection.mobility_stagger_burst_multiplier(),
                )
        return
    if payload == RunBuild.PAYLOAD_SMASH:
        var target := _aim_context.clamped_smash_target()
        preview["smash_center"] = target
        preview["smash_legal"] = engine.is_cell_open_for_player(target)
        if bool(preview["smash_legal"]):
            preview["ghost_cell"] = target
            _collect_smash_outcomes(target, outcomes)
        return
    if payload == RunBuild.PAYLOAD_DEBUG_STUB:
        var target := player.cell + _aim_context.aim_direction()
        preview["dash_path"] = [target]
        preview["dash_legal"] = engine.is_cell_open_for_player(target)
        if bool(preview["dash_legal"]):
            preview["dash_landing"] = target
            preview["ghost_cell"] = target
        return
    ToastManager.show_dev_error("TickPreviewController: unknown mobility payload %s" % payload)


## Predicts one hit for the preview and condenses it into a display entry: cell, label, and intensity
## tier. Honesty extends to the mobility-slot-triggered Majors: an active Shredder or Execution upgrades
## the label to the same distinct result the commit will show, never a generic guard-break/kill fallback.
func _outcome_entry(
        enemy: GridEnemy,
        origin_cell: Vector2i,
        damage: float,
        guard_shredder_trigger := false,
        execution_trigger := false,
        stagger_burst_multiplier := TickCombatRules.STAGGER_ATTACK_MULTIPLIER,
) -> Dictionary:
    var result := enemy.predict_hit(origin_cell, damage, guard_shredder_trigger, execution_trigger, stagger_burst_multiplier)
    var label := ""
    var tier := 0
    if result.killed:
        label = "EXECUTION" if result.major_trigger == TickHitOutcome.MajorTrigger.EXECUTION else "KILL"
        tier = 2
    elif result.stagger_burst:
        label = "BURST"
        tier = 1
    elif result.guard_broken:
        label = "SHREDDER" if result.major_trigger == TickHitOutcome.MajorTrigger.GUARD_SHREDDER else "%s BREAK" % TickCombatRules.angle_name(result.angle).to_upper()
        tier = 1
    else:
        label = TickCombatRules.angle_name(result.angle).to_upper()
    return { "cell": enemy.get_grid_pos(), "label": label, "tier": tier }


## Collects predicted outcomes for every living enemy in the 3x3 block centered on the given cell.
## The landing cell is the origin for every victim, per the Smash direction rule (Phase 04 sketch),
## so Guard Shredder's back-angle check reads relative to the landing, not the player's start cell.
func _collect_smash_outcomes(center: Vector2i, outcomes: Dictionary) -> void:
    var guard_shredder := TickCombatProjection.has_mobility_guard_shredder(_run_build)
    var execution := TickCombatProjection.has_mobility_execution(_run_build)
    for enemy: GridEnemy in engine.actors():
        if _aim_context.chebyshev(enemy.get_grid_pos() - center) <= 1:
            outcomes[enemy.get_grid_pos()] = _outcome_entry(
                enemy,
                center,
                TickCombatProjection.mobility_attack_damage(_run_build, TickCombatRules.PLAYER_SMASH_DAMAGE),
                guard_shredder,
                execution,
                TickCombatProjection.mobility_stagger_burst_multiplier(),
            )


## Shows the locked Smash landing and its outcomes regardless of the current aim mode, since an armed
## windup is a standing commitment the player can glance at even while briefly back in Attack Mode.
func _apply_locked_smash_preview(preview: Dictionary, outcomes: Dictionary) -> void:
    preview["smash_armed_center"] = player.smash_target
    preview["ghost_cell"] = player.smash_target
    _collect_smash_outcomes(player.smash_target, outcomes)
