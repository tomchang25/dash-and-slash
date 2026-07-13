# bomb_enemy.gd
# Guardless 1x1 grid enemy that commits a locked Manhattan-distance-four self-destruct once the
# player enters its adjacent ring, then kills itself through Health after the fuse resolves.
class_name BombEnemy
extends GridEnemy

const BOMB_RADIUS := 4
## Playtest tuning: slower pursuit gives the player a real window to kill or evade before the fuse ends.
const TICK_SPEED := 75

# -- State --

var _attack_data: EnemyAttackData

# == Lifecycle ==


func _ready() -> void:
    super()
    _select_attack_data()

# == Common API ==


## Returns Bomb's authored pursuit speed, leaving a kill-or-evade window before detonation.
func get_tick_speed() -> int:
    return TICK_SPEED


## Returns Bomb's sole authored self-destruct profile.
func get_current_attack_data() -> EnemyAttackData:
    return _attack_data


## Commits once the player stands in Bomb's eight-cell adjacent ring; the locked square never depends
## on facing, so approach and arrival share the same adjacency check.
func should_commit_before_plan() -> bool:
    return _is_target_in_adjacent_ring()


## Rechecks adjacency after movement so Bomb commits immediately upon reaching the target's ring.
func should_commit_on_arrival() -> bool:
    return _is_target_in_adjacent_ring()


## The centered Manhattan-distance-four footprint computed once from Bomb's commit cell; the runtime
## locks this snapshot, so later player movement changes hit membership but never recenters it.
func get_committed_attack_cells() -> Array[Vector2i]:
    var radius := _attack_data.radius if _attack_data != null else BOMB_RADIUS
    return AttackCellShapes.manhattan(_grid_pos, radius, _grid, true)


## Bomb has no facing-oriented windup VFX or tile executor; the shared danger fill and the presenter's
## fuse blink are the only prepare-phase presentation.
func begin_attack_telegraph() -> bool:
    if not begin_committed_action():
        return false
    if _visual_presenter != null:
        _visual_presenter.show_prepare_attack()
    return true


## Escalates to the presenter's faster final-tick fuse blink.
func show_attack_charge() -> void:
    if _visual_presenter != null:
        _visual_presenter.show_attack_commit()


## Resolves the locked footprint against the player, then self-kills through Health instead of
## entering a recovery window. Health.died removes Bomb from the engine before its later action stage.
func _tick_detonate() -> void:
    _resolve_detonation_on_player(get_attack_tiles())
    _tick_runtime.clear_attack()
    _clear_attack_presentation()
    force_death()


## Tick hook: clears the fuse presentation on a resolved or cancelled attack.
func _clear_attack_presentation() -> void:
    if _visual_presenter != null:
        _visual_presenter.show_idle()

# == Setup helpers ==


func _after_setup_ready() -> void:
    _select_attack_data()


func _on_begin_death_extra() -> void:
    _clear_attack_presentation()


## Pool-acquire cleanup: a reused Bomb must never carry a locked fuse over from a run reset or an
## earlier pool cycle into its next spawn, so this also drops the runtime countdown itself.
func _reset_extra() -> void:
    _tick_runtime.clear_attack()
    _clear_attack_presentation()


## True while the target occupies one of Bomb's eight surrounding cells, excluding its own cell.
func _is_target_in_adjacent_ring() -> bool:
    if _grid == null or not has_target():
        return false
    return get_target_cell() in AttackCellShapes.adjacent_ring(_grid_pos, 1, _grid, true)


func _select_attack_data() -> void:
    if enemy_data != null:
        for attack: EnemyAttackData in enemy_data.attacks:
            if attack != null and attack.attack_kind == EnemyAttackData.AttackKind.AREA:
                _attack_data = attack
                return
    _attack_data = _create_fallback_attack_data()


func _create_fallback_attack_data() -> EnemyAttackData:
    var attack_data := EnemyAttackData.new()
    attack_data.attack_kind = EnemyAttackData.AttackKind.AREA
    attack_data.cell_shape = EnemyAttackData.CellShape.MANHATTAN
    attack_data.damage = 50.0
    attack_data.warning_duration = 3
    attack_data.radius = BOMB_RADIUS
    return attack_data
