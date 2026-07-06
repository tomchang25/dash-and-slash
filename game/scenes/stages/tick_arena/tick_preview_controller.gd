# tick_preview_controller.gd
# Owns read-only tick-arena preview calculation: mouse cell/aim resolution, dash plan previews,
# smash previews, and predicted outcome badges. Writes only view payloads to TickGridView and must
# never mutate player state, enemy state, run-build state, wave state, or world time. Duplicates a
# handful of pure planning helpers also present on TickActionController rather than sharing them
# across the boundary, per the ownership split's correctness-over-consolidation rule; the aim mode
# and last-aim direction it reads are the action controller's own truth so a preview can never
# disagree with what a confirm would actually resolve.
class_name TickPreviewController
extends Node

# -- Constants --

const PLAYER_ATTACK_DAMAGE := 20.0
const PLAYER_DASH_DAMAGE := 30.0
const PLAYER_SMASH_DAMAGE := 30.0
const DASH_RANGE := 5
const SMASH_RANGE := 3
const MAX_MOBILITY_RANGE_BONUS_PERCENT := 200.0

# -- Exports --

@export var grid: GridArena
@export var view: TickGridView
@export var engine: TickEngine
@export var player: TickPlayer
@export var action_controller: TickActionController

# -- State --

var _run_build: RunBuild

# == Lifecycle ==


func _process(_delta: float) -> void:
    _update_preview()

# == Common API ==


## Stores the run build this controller reads the mobility payload and mobility triggers from; the
## tick arena root owns and constructs the shared RunBuild instance.
func setup(run_build: RunBuild) -> void:
    _run_build = run_build

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
        preview["aim_cell"] = player.cell + _aim_direction()
        var aim_enemy := engine.enemy_at(preview["aim_cell"])
        if aim_enemy != null:
            outcomes[aim_enemy.get_grid_pos()] = _outcome_entry(aim_enemy, player.cell, _normal_attack_damage(), false)

    if not outcomes.is_empty():
        preview["outcomes"] = outcomes.values()
    view.set_preview(preview)


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
            var guard_shredder := _run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER)
            var execution := _run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION)
            for victim: GridEnemy in plan["victims"]:
                outcomes[victim.get_grid_pos()] = _outcome_entry(victim, victim.get_grid_pos() - dir, _mobility_attack_damage(PLAYER_DASH_DAMAGE), true, guard_shredder, execution)
        return
    if payload == RunBuild.PAYLOAD_SMASH:
        var target := _clamped_smash_target()
        preview["smash_center"] = target
        preview["smash_legal"] = engine.is_cell_open_for_player(target)
        if bool(preview["smash_legal"]):
            preview["ghost_cell"] = target
            _collect_smash_outcomes(target, outcomes)
        return
    if payload == RunBuild.PAYLOAD_DEBUG_STUB:
        var target := player.cell + _aim_direction()
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
func _outcome_entry(enemy: GridEnemy, origin_cell: Vector2i, damage: float, is_dash: bool, guard_shredder_trigger := false, execution_trigger := false) -> Dictionary:
    var result := enemy.predict_hit(origin_cell, damage, is_dash, guard_shredder_trigger, execution_trigger)
    var major_trigger := StringName(result.get("major_trigger", TickHitResolver.MAJOR_TRIGGER_NONE))
    var label := ""
    var tier := 0
    if bool(result["killed"]):
        label = "EXECUTION" if major_trigger == TickHitResolver.MAJOR_TRIGGER_EXECUTION else "KILL"
        tier = 2
    elif bool(result["stagger_burst"]):
        label = "BURST"
        tier = 1
    elif bool(result["guard_broken"]):
        label = "SHREDDER" if major_trigger == TickHitResolver.MAJOR_TRIGGER_GUARD_SHREDDER else "%s BREAK" % _angle_name(result["angle"]).to_upper()
        tier = 1
    else:
        label = _angle_name(result["angle"]).to_upper()
    return { "cell": enemy.get_grid_pos(), "label": label, "tier": tier }


## Collects predicted outcomes for every living enemy in the 3x3 block centered on the given cell.
## The landing cell is the origin for every victim, per the Smash direction rule (Phase 04 sketch),
## so Guard Shredder's back-angle check reads relative to the landing, not the player's start cell.
func _collect_smash_outcomes(center: Vector2i, outcomes: Dictionary) -> void:
    var guard_shredder := _run_build.has_mobility_trigger(RunBuild.TRIGGER_GUARD_SHREDDER)
    var execution := _run_build.has_mobility_trigger(RunBuild.TRIGGER_EXECUTION)
    for enemy: GridEnemy in engine.actors():
        if _chebyshev(enemy.get_grid_pos() - center) <= 1:
            outcomes[enemy.get_grid_pos()] = _outcome_entry(enemy, center, _mobility_attack_damage(PLAYER_SMASH_DAMAGE), true, guard_shredder, execution)


## Shows the locked Smash landing and its outcomes regardless of the current aim mode, since an armed
## windup is a standing commitment the player can glance at even while briefly back in Attack Mode.
func _apply_locked_smash_preview(preview: Dictionary, outcomes: Dictionary) -> void:
    preview["smash_armed_center"] = player.smash_target
    preview["ghost_cell"] = player.smash_target
    _collect_smash_outcomes(player.smash_target, outcomes)

# == Aiming and plans ==


func _mouse_cell() -> Vector2i:
    return grid.world_to_grid(grid.get_global_mouse_position())


func _aim_direction() -> Vector2i:
    var dir := TickCombatRules.dominant_direction(_mouse_cell() - player.cell)
    if dir == Vector2i.ZERO:
        return action_controller.get_last_aim()
    return dir


## Computes the dash plan shared by the preview and the verb: direction and wanted length from the cursor,
## landing on the farthest open cell at or before it, victims collected along the traveled path.
func _compute_dash_plan() -> Dictionary:
    var delta := _mouse_cell() - player.cell
    var dir := TickCombatRules.dominant_direction(delta)
    if dir == Vector2i.ZERO:
        dir = action_controller.get_last_aim()
    var wanted := clampi(absi(delta.x * dir.x + delta.y * dir.y), 1, _mobility_range_cells(DASH_RANGE))

    var preview_path: Array[Vector2i] = []
    var travel_path: Array[Vector2i] = []
    var landing_index := -1
    for i in range(1, wanted + 1):
        var step_cell := player.cell + dir * i
        if not grid.is_land(step_cell):
            break
        preview_path.append(step_cell)
        travel_path.append(step_cell)
        if engine.enemy_at(step_cell) == null:
            landing_index = travel_path.size() - 1
    if landing_index < 0:
        return { "legal": false, "dir": dir, "path": preview_path }

    var travel := travel_path.slice(0, landing_index + 1)
    var victims: Array[GridEnemy] = []
    for travel_cell: Vector2i in travel:
        var enemy := engine.enemy_at(travel_cell)
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
    var smash_range := _mobility_range_cells(SMASH_RANGE)
    var delta := _mouse_cell() - player.cell
    delta.x = clampi(delta.x, -smash_range, smash_range)
    delta.y = clampi(delta.y, -smash_range, smash_range)
    return player.cell + delta


func _chebyshev(delta: Vector2i) -> int:
    return maxi(absi(delta.x), absi(delta.y))


## Projects normal attack's base damage through the run's Normal Attack Damage bonus total.
func _normal_attack_damage() -> float:
    return PLAYER_ATTACK_DAMAGE + _run_build.total(RunBuild.CH_NORMAL_ATTACK_DAMAGE)


## Projects a mobility-slot payload's base damage (Dash or Smash) through the run's Mobility Attack
## Damage bonus total.
func _mobility_attack_damage(base_damage: float) -> float:
    return base_damage + _run_build.total(RunBuild.CH_MOBILITY_ATTACK_DAMAGE)


## Projects a mobility-slot payload's base range (in cells, Dash or Smash) through the run's Mobility
## Range percent bonus.
func _mobility_range_cells(base_range: int) -> int:
    return TickCombatRules.mobility_range_cells(base_range, _run_build.total(RunBuild.CH_MOBILITY_RANGE), MAX_MOBILITY_RANGE_BONUS_PERCENT)


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
            ToastManager.show_dev_error("TickPreviewController: unexpected hit angle %d" % angle)
            return "?"
