# tick_engine.gd
# Scene-scoped tick engine: owns the tick counter, the actor registry with energy scheduling, and the
# world-advance resolution order (detonations against the player's post-action cell, then actor actions).
# The player path never passes a variable action cost into world advancement — one verb, one tick.
class_name TickEngine
extends Node

signal world_advanced(tick_count: int)
signal attack_detonated(cells: Array[Vector2i])
signal player_died

const ENERGY_PER_ACTION := 100

# -- State --

var _tick_count := 0
var _actors: Array[GridEnemy] = []
var _energy := { }
var _player_dead := false

# -- Node references --

@onready var _grid: GridArena = %GridArena
@onready var _player: TickPlayer = %Player

# == Common API ==


## Advances the world by exactly one tick after a consumed player verb (stage 1 already resolved):
## stage 2 detonates zero-countdown attacks against the player's new cell, stage 3 counts status in
## world ticks and grants action energy only to enabled actors, then tick cooldowns count down.
func advance_world() -> void:
    _tick_count += 1

    # Publish the player's logical cell so enemy reservation priority (closer-to-player) stays correct.
    _grid.set_player_cell(_grid.cell_center(_player.cell))

    for actor in _actors.duplicate():
        if actor.is_alive():
            actor.resolve_detonation()

    for actor in _actors.duplicate():
        if not actor.is_alive():
            continue
        if actor.advance_status():
            # Disabled actors (staggered/recovering) neither act nor bank energy, so a just-recovered
            # enemy can never surprise the player with saved-up movement.
            _energy[actor] = 0
            continue
        _energy[actor] = int(_energy.get(actor, 0)) + actor.get_tick_speed()
        while int(_energy[actor]) >= ENERGY_PER_ACTION:
            _energy[actor] = int(_energy[actor]) - ENERGY_PER_ACTION
            actor.act_tick()

    _player.tick_cooldowns()
    world_advanced.emit(_tick_count)

    if _player_dead:
        _player_dead = false
        player_died.emit()


## Registers an enemy actor into the energy scheduler.
func register_actor(actor: GridEnemy) -> void:
    if actor in _actors:
        return
    _actors.append(actor)
    _energy[actor] = 0


## Removes an actor from the scheduler (killed or despawned); the caller owns freeing the node.
func unregister_actor(actor: GridEnemy) -> void:
    _actors.erase(actor)
    _energy.erase(actor)


## Drops all registered actors from the scheduler; the caller owns freeing the nodes.
func clear_actors() -> void:
    _actors.clear()
    _energy.clear()


## Zeroes an actor's banked action energy (used on guard break so no saved-up action survives a stagger).
func clear_energy(actor: GridEnemy) -> void:
    if _energy.has(actor):
        _energy[actor] = 0


## Returns a snapshot of the registered actors.
func actors() -> Array[GridEnemy]:
    return _actors.duplicate()


func tick_count() -> int:
    return _tick_count

# == Tick context (queried by actors and the scene root) ==


## Returns the player's current grid cell.
func player_cell() -> Vector2i:
    return _player.cell


## Applies enemy damage to the player; death is deferred to the end of the current tick resolution.
func damage_player(amount: float, _source: Node) -> void:
    if _player.take_damage(amount):
        _player_dead = true


## Returns true when an enemy may stand on the cell: in-bounds land, not the player, not another living actor.
func is_cell_open_for_enemy(target_cell: Vector2i, asking: GridEnemy) -> bool:
    if not _grid.is_land(target_cell) or target_cell == _player.cell:
        return false
    for actor in _actors:
        if actor != asking and actor.is_alive() and actor.get_grid_pos() == target_cell:
            return false
    return true


## Returns true when the player may stand on the cell: in-bounds land with no living enemy on it.
func is_cell_open_for_player(target_cell: Vector2i) -> bool:
    return _grid.is_land(target_cell) and enemy_at(target_cell) == null


## Returns the living enemy occupying the cell, or null.
func enemy_at(target_cell: Vector2i) -> GridEnemy:
    for actor in _actors:
        if actor.is_alive() and actor.get_grid_pos() == target_cell:
            return actor
    return null


## Relays a detonation to presentation listeners.
func notify_detonation(cells: Array[Vector2i]) -> void:
    attack_detonated.emit(cells)
