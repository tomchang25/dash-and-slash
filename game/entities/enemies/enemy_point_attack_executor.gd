# enemy_point_attack_executor.gd
# Shared single-hitbox attack executor: stamps damage/interval/guard profile from an
# attack profile onto a pre-placed hitbox and enables/disables it for the active window.
# Optionally drives the shared cell-based telegraph when the attack has a footprint
# worth warning about; skipped when a kind telegraphs itself through body/VFX changes.
class_name EnemyPointAttackExecutor
extends Node

var _grid: GridArena
var _telegraph: TileTelegraph
var _hitbox: Hitbox
var _show_telegraph := false
var _attack_cells: Array[Vector2i] = []
var _prepared := false


## Wires the executor to its grid, telegraph, and target hitbox. show_telegraph controls
## whether prepare() computes a cell footprint and whether the show_*/clear_cell calls
## drive the telegraph; pass false for kinds that telegraph through body/VFX instead.
func setup(grid: GridArena, telegraph: TileTelegraph, hitbox: Hitbox, show_telegraph: bool) -> void:
    _grid = grid
    _telegraph = telegraph
    _hitbox = hitbox
    _show_telegraph = show_telegraph
    if _show_telegraph and _telegraph != null:
        _telegraph.setup(grid)
    cancel()


## Stamps damage, damage interval, and guard-damage profile from attack_data onto the
## hitbox. Does not touch cells or telegraph state. damage_multiplier applies
## per-wave enemy scaling on top of the resource's base damage.
func configure(attack_data: EnemyAttackData, damage_multiplier: float = 1.0) -> bool:
    if _hitbox == null or attack_data == null:
        return false
    _hitbox.damage = attack_data.damage * damage_multiplier
    _hitbox.damage_interval = attack_data.damage_interval
    _hitbox.guard_damage_profile = Hitbox.GuardDamageProfile.NORMAL
    return true


## Configures the hitbox and, when telegraphing, computes the cell footprint used by
## show_warning/show_charge/show_active. Fails if configuration fails or, when
## telegraphing, the computed footprint is empty.
func prepare(origin_cell: Vector2i, facing: Vector2, attack_data: EnemyAttackData, damage_multiplier: float = 1.0) -> bool:
    cancel()
    if not configure(attack_data, damage_multiplier):
        return false

    if _show_telegraph:
        _attack_cells = EnemyAttackController.get_attack_cells(origin_cell, facing, attack_data, _grid)
        if _attack_cells.is_empty():
            return false

    _prepared = true
    return true


func show_warning() -> void:
    if _prepared and _show_telegraph and _telegraph != null:
        _telegraph.show_warning(_attack_cells)


func show_charge() -> void:
    if _prepared and _show_telegraph and _telegraph != null:
        _telegraph.show_charge(_attack_cells)


func show_active() -> void:
    if _prepared and _show_telegraph and _telegraph != null:
        _telegraph.show_active(_attack_cells)


func begin_attack() -> void:
    if not _prepared:
        return
    show_active()
    set_hitbox_enabled(true)


func end_attack() -> void:
    set_hitbox_enabled(false)
    if _show_telegraph and _telegraph != null:
        _telegraph.clear()
    _attack_cells.clear()
    _prepared = false


func cancel() -> void:
    set_hitbox_enabled(false)
    if _show_telegraph and _telegraph != null:
        _telegraph.clear()
    _attack_cells.clear()
    _prepared = false


## Enables or disables the target hitbox directly, bypassing telegraph state. Used by
## kinds whose delivery (e.g. a charge dash) owns its own telegraph timing.
func set_hitbox_enabled(enabled: bool) -> void:
    if _hitbox != null:
        _hitbox.set_enabled(enabled)


func get_cells() -> Array[Vector2i]:
    return _attack_cells.duplicate()


func clear_cell(cell: Vector2i) -> void:
    if _show_telegraph and _telegraph != null:
        _telegraph.clear_cell(cell)
