# ranged_enemy.gd
# Small-enemy variant that pressures the player from a Manhattan-distance band with a centered
# five-cell cross. It inherits the shared Tile attack countdown, recovery, cancellation, and hit
# response; only target-centered commitment and its movement policy differ.
class_name RangedEnemy
extends SmallEnemy

const MINIMUM_ATTACK_RANGE := 3
const MAXIMUM_ATTACK_RANGE := 5
const CROSS_FACING := Vector2.RIGHT

# == Common API ==


## Ranged attacks need only be in their authored Manhattan-distance band; they never wait for a facing turn.
func can_attack() -> bool:
    if get_grid() == null or not has_target() or get_current_attack_data() == null:
        return false
    return _is_target_in_attack_band()


## Commits immediately after a reposition step reaches the authored attack band.
func should_commit_on_arrival() -> bool:
    return can_attack()


## Commits the symmetric cross around the player cell captured at warning start, not around self.
func begin_attack_telegraph() -> bool:
    if not begin_committed_action():
        return false

    var attack := get_attack_controller()
    var attack_data := get_current_attack_data()
    var grid := get_grid()
    if attack == null or attack_data == null or grid == null:
        return false

    var target_cell := get_target_cell()
    if not grid.is_in_bounds(target_cell):
        return false

    var cells := EnemyAttackController.get_attack_cells(target_cell, CROSS_FACING, attack_data, grid)
    if not attack.prepare_cells(cells):
        return false
    attack.show_warning()
    start_attack_windup_vfx(CombatFeedbackVFX.WindupStyle.TILE)
    if _visual_presenter != null:
        _visual_presenter.show_prepare_attack()
    return true


## Repositions to the nearest reachable cell in the authored attack band with no melee fallback.
func plan_next_action() -> bool:
    return plan_manhattan_distance_band_action(MINIMUM_ATTACK_RANGE, MAXIMUM_ATTACK_RANGE)

# == Setup helpers ==


## Ranged has exactly one authored attack; invalid data disables attacks instead of random fallback.
func _select_attack_data() -> void:
    _attack_data = null
    if enemy_data == null or enemy_data.attacks.size() != 1:
        ToastManager.show_dev_error("RangedEnemy: expected exactly one authored attack")
        return

    var attack_data := enemy_data.attacks[0]
    if attack_data == null or attack_data.attack_kind != EnemyAttackData.AttackKind.TILE or attack_data.cell_shape != EnemyAttackData.CellShape.CUSTOM_OFFSETS:
        ToastManager.show_dev_error("RangedEnemy: expected one TILE CUSTOM_OFFSETS attack")
        return
    _attack_data = attack_data


func _is_target_in_attack_band() -> bool:
    var target_cell := get_target_cell()
    var enemy_cell := get_grid_pos()
    var distance := absi(target_cell.x - enemy_cell.x) + absi(target_cell.y - enemy_cell.y)
    return distance >= MINIMUM_ATTACK_RANGE and distance <= MAXIMUM_ATTACK_RANGE
