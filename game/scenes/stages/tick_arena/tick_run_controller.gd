# tick_run_controller.gd
# Transitional owner of the Phase 4c fixed-enemy bridge: fixed enemy composition and spawning,
# wave-clear banner timing, the reward choice open/apply flow, and the reset hook seam. Deliberately
# thin — it does not convert to the real wave controller, terrain cadence, or death/restart flow
# until Phase 6d/6e replace these seams.
class_name TickRunController
extends Node

signal reward_applied
signal run_reset_finished

# -- Constants --

const SmallEnemyScene := preload("res://game/entities/enemies/small_enemy.tscn")
const ChargeEnemyScene := preload("res://game/entities/enemies/charge_enemy.tscn")
const PuffEnemyScene := preload("res://game/entities/enemies/puff_enemy.tscn")
const ModeEnemyScene := preload("res://game/entities/enemies/mode_enemy.tscn")

const SMALL_SPAWN_COUNT := 2
const CHARGER_SPAWN_COUNT := 1
const PUFF_SPAWN_COUNT := 1
const MODE_SPAWN_COUNT := 1
const SPAWN_MIN_PLAYER_DISTANCE := 4
const REWARD_OPEN_DELAY := 2.0
const WAVE_BANNER_FADE := 0.35

# -- Exports --

@export var grid: GridArena
@export var engine: TickEngine
@export var player: TickPlayer
@export var enemy_container: Node2D
@export var action_controller: TickActionController
@export var reward_overlay: WaveRewardOverlay
@export var wave_banner_overlay: Control
@export var wave_banner_label: Label

# -- State --

var _run_build: RunBuild
var _wave_number := 1
var _reward_controller: WaveRewardChoiceController
var _rng := RandomNumberGenerator.new()

# -- Timer / tween handles --

var _wave_banner_tween: Tween

# == Signal handlers ==


## Starts the next enemy set with the current simple spawn composition once a reward is applied
## Phase 6 replaces this with the calibrated wave controller, planner, and spawner.
func _on_reward_choice_applied() -> void:
    action_controller.set_input_locked(false)
    _wave_number += 1
    _spawn_enemies()
    action_controller.set_message("Reward applied — wave %d begins." % _wave_number)
    reward_applied.emit()

# == Common API ==


## Stores the run build the reward flow applies effects onto, seeds the spawn/reward RNG, and wires
## the reward choice flow; the tick arena root owns and constructs the shared RunBuild instance.
func setup(run_build: RunBuild) -> void:
    _run_build = run_build
    _rng.randomize()
    _wire_reward_flow()


## Spawns the first wave's fixed enemy set. Called once the arena root has finished setting up the
## player, since spawn placement depends on the player's starting cell.
func start_first_wave() -> void:
    _spawn_enemies()


## Locks player input and shows the "WAVE END" banner, matching the legacy arena's wave-complete
## beat; the reward choice only opens once the banner has fully faded out.
func handle_wave_cleared() -> void:
    action_controller.set_input_locked(true)
    _show_wave_banner("WAVE END")


func handle_player_died() -> void:
    reset_run("You died — run reset.")


## Cancels any pending wave-end banner/reward-open callback before resetting, so a manual reset
## during the banner countdown can never open a stale reward choice after the run has already reset.
func reset_run(reason: String) -> void:
    if _wave_banner_tween != null and _wave_banner_tween.is_valid():
        _wave_banner_tween.kill()
    wave_banner_overlay.visible = false
    action_controller.set_input_locked(false)
    for actor in engine.actors():
        grid.unregister_occupant(actor)
        actor.queue_free()
    engine.clear_actors()
    player.reset(grid.grid_size / 2)
    action_controller.reset_for_new_run()
    _spawn_enemies()
    action_controller.set_message(reason)
    run_reset_finished.emit()

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
    enemy.global_position = grid.cell_center(_pick_spawn_cell())
    enemy.setup(grid, player)
    enemy.bind_tick_engine(engine)
    enemy_container.add_child(enemy)
    engine.register_actor(enemy)


func _pick_spawn_cell() -> Vector2i:
    var candidates: Array[Vector2i] = []
    var fallback: Array[Vector2i] = []
    for land_cell: Vector2i in grid.get_land_cells():
        if land_cell == player.cell or engine.enemy_at(land_cell) != null:
            continue
        fallback.append(land_cell)
        var delta := land_cell - player.cell
        if absi(delta.x) + absi(delta.y) >= SPAWN_MIN_PLAYER_DISTANCE:
            candidates.append(land_cell)
    if candidates.is_empty():
        candidates = fallback
    if candidates.is_empty():
        ToastManager.show_dev_error("TickRunController: no free land cell to spawn an enemy.")
        return player.cell
    return candidates[_rng.randi_range(0, candidates.size() - 1)]

# == Rewards ==


## Wires the shared reward generator/applier/context/controller and overlay flow (Phase 04c bridge)
## against this arena's own RunBuild, so a won Major writes through the same store tick verbs read.
## The context's player field stays null: the existing player-stat Minor effects require a real-time
## Player and are filtered out by their own is_applicable() check, while Majors only touch RunBuild.
func _wire_reward_flow() -> void:
    var reward_generator := WaveRewardChoiceGenerator.new(_rng)
    var reward_applier := WaveRewardApplier.new()
    var reward_context := WaveRewardContext.new(grid, null, _run_build)
    _reward_controller = WaveRewardChoiceController.new(
        reward_overlay,
        reward_generator,
        reward_applier,
        reward_context,
    )
    _reward_controller.choice_applied.connect(_on_reward_choice_applied)


## Opens the reward choice for the wave that was just cleared. This bridge applies no terrain
## mutation, so the terrain_mutation_kind argument only satisfies the shared controller's signature
## the tick arena's overlay omits the terrain-mutation note label, so no note is ever shown for it.
func _open_reward_choice() -> void:
    _reward_controller.open_reward_choice(
        _wave_number,
        _reward_target_points(_wave_number),
        WaveRewardChoiceController.TerrainMutationKind.REMOVE_LAND,
    )


func _reward_target_points(wave_number: int) -> float:
    return float(max(wave_number - 1, 0))

# == Wave banner ==


## Fades the banner in, holds, and fades it out over REWARD_OPEN_DELAY, then opens the reward
## choice; mirrors the legacy arena's wave-end banner and reward-open delay as a single tween chain.
func _show_wave_banner(text: String) -> void:
    if _wave_banner_tween != null and _wave_banner_tween.is_valid():
        _wave_banner_tween.kill()
    wave_banner_label.text = text
    wave_banner_overlay.modulate.a = 0.0
    wave_banner_overlay.visible = true
    _wave_banner_tween = create_tween()
    _wave_banner_tween.tween_property(wave_banner_overlay, "modulate:a", 1.0, WAVE_BANNER_FADE)
    _wave_banner_tween.tween_interval(max(REWARD_OPEN_DELAY - WAVE_BANNER_FADE * 2.0, 0.0))
    _wave_banner_tween.tween_property(wave_banner_overlay, "modulate:a", 0.0, WAVE_BANNER_FADE)
    _wave_banner_tween.tween_callback(_hide_wave_banner_and_open_reward)


func _hide_wave_banner_and_open_reward() -> void:
    wave_banner_overlay.visible = false
    _open_reward_choice()
