# tick_run_controller.gd
# Owns tick-arena run flow: starts and advances waves through WaveController, the wave-clear
# banner timing, the reward choice open/apply flow, the death overlay/restart flow, and the reset
# hook seam. Wave/spawn logistics (support count, population cap, spawn warnings, milestone elites,
# stat scaling) belong to WaveController and its EnemySpawnPlanner/EnemySpawner collaborators, not
# here. Restart clears this controller's own injected RunBuild in place via reset_run(); the arena
# root constructs that store once at setup and never replaces it.
class_name TickRunController
extends Node

signal reward_applied
signal run_reset_finished
signal spawn_warning_changed(cells: Array[Vector2i], ticks: int)

# -- Constants --

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
@export var death_overlay: Control
@export var restart_button: Button

# -- State --

var _run_build: RunBuild
var _wave_controller: WaveController
var _spawn_planner: EnemySpawnPlanner
var _spawner: EnemySpawner
var _reward_controller: WaveRewardChoiceController
var _reward_context: WaveRewardContext
var _rng := RandomNumberGenerator.new()

# -- Timer / tween handles --

var _wave_banner_tween: Tween

# == Lifecycle ==


func _ready() -> void:
    restart_button.pressed.connect(_on_restart_button_pressed)

# == Signal handlers ==


## Starts the next wave once a reward is applied.
func _on_reward_choice_applied() -> void:
    action_controller.set_input_locked(false)
    _wave_controller.start_next_wave()
    action_controller.set_message("Reward applied — wave %d begins." % _wave_controller.get_wave_number())
    reward_applied.emit()


## Locks player input and shows the "WAVE END" banner once the wave controller reports every
## queued and alive enemy is gone; the reward choice only opens once the banner has fully faded out.
func _on_normal_wave_completed(_wave_number: int, _is_milestone_wave: bool) -> void:
    action_controller.set_input_locked(true)
    _show_wave_banner("WAVE END")


## The death overlay's only recovery path; resets this controller's own injected RunBuild in place
## instead of asking the arena root to build a replacement.
func _on_restart_button_pressed() -> void:
    reset_run("Run reset.")


func _on_spawn_warning_changed(cells: Array[Vector2i], ticks: int) -> void:
    spawn_warning_changed.emit(cells, ticks)

# == Common API ==


## Stores the run build the reward flow and wave controller apply effects onto/read pressure from,
## seeds the spawn/reward RNG, and wires the reward choice and wave flow; the tick arena root owns
## and constructs the shared RunBuild instance.
func setup(run_build: RunBuild) -> void:
    _run_build = run_build
    _rng.randomize()
    _wire_reward_flow()
    _wire_wave_controller()


## Starts the first wave. Called once the arena root has finished setting up the player, since
## spawn placement depends on the player's starting cell.
func start_first_wave() -> void:
    _wave_controller.start_next_wave()


## TickEngine emits player death only after the killing tick fully resolves; this shows the death
## overlay instead of resetting immediately, so the player can see what killed them before restarting.
## Combat input stays locked and the wave controller force-kills/stops spawning so nothing keeps
## acting behind the overlay; restart is the only recovery path from here.
func handle_player_died() -> void:
    _cancel_pending_wave_flow()
    action_controller.set_input_locked(true)
    _wave_controller.end_run()
    death_overlay.visible = true


## Cancels any pending wave-end banner/reward-open callback before resetting, so a restart during the
## banner countdown or an open reward choice can never let that stale flow reopen or reapply after the
## run has already reset. Clears the run's own RunBuild in place instead of replacing it, so the
## reward context and wave controller keep the same reference they were injected with at setup.
func reset_run(reason: String) -> void:
    _cancel_pending_wave_flow()
    death_overlay.visible = false
    action_controller.set_input_locked(false)
    for actor in engine.actors():
        grid.unregister_occupant(actor)
        actor.queue_free()
    engine.clear_actors()
    _run_build.clear()
    player.reset(grid.grid_size / 2, _run_build.total(RunBuild.CH_MAX_HEALTH))
    action_controller.reset_for_new_run()
    _wave_controller.reset()
    _wave_controller.start_next_wave()
    action_controller.set_message(reason)
    run_reset_finished.emit()


## Returns the active spawn-warning display payload from the wave controller, or an empty dictionary.
func get_spawn_warning_danger() -> Dictionary:
    if _wave_controller == null:
        return { }
    return _wave_controller.get_spawn_warning_danger()

# == Death / Restart ==


## Kills any in-flight wave-end banner tween and hides the wave banner and reward overlays, unpausing
## the tree if the reward choice happened to be open — the shared cleanup death and restart both need
## so neither can leave a stale banner/reward callback able to fire once the store clears.
func _cancel_pending_wave_flow() -> void:
    if _wave_banner_tween != null and _wave_banner_tween.is_valid():
        _wave_banner_tween.kill()
    wave_banner_overlay.visible = false
    reward_overlay.hide_choices()
    get_tree().paused = false

# == Wave Controller ==


## Wires the wave controller and its spawn collaborators against this arena's grid, engine, and
## enemy container. The spawn planner reads the player's logical cell through a callable instead
## of a concrete player type, per EnemySpawnPlanner's arena-agnostic contract.
func _wire_wave_controller() -> void:
    _spawn_planner = EnemySpawnPlanner.new(grid, func() -> Vector2i: return player.cell)
    _spawner = EnemySpawner.new(grid, player, enemy_container, engine)
    _wave_controller = WaveController.new()
    _wave_controller.setup(grid, _spawn_planner, _spawner, engine)
    _wave_controller.set_run_build(_run_build)
    _wave_controller.normal_wave_completed.connect(_on_normal_wave_completed)
    _wave_controller.spawn_warning_changed.connect(_on_spawn_warning_changed)

# == Rewards ==


## Wires the shared reward generator/applier/context/controller and overlay flow (Phase 04c bridge)
## against this arena's own RunBuild, so a won Major writes through the same store tick verbs read.
## The context's player field stays null: Majors and every tick-compatible Minor read and write
## RunBuild directly, while Attack Range is the sole remaining legacy player-stat effect and is
## filtered out of this pool by its own is_applicable() check.
func _wire_reward_flow() -> void:
    var reward_generator := WaveRewardChoiceGenerator.new(_rng)
    var reward_applier := WaveRewardApplier.new()
    _reward_context = WaveRewardContext.new(grid, null, _run_build)
    _reward_controller = WaveRewardChoiceController.new(
        reward_overlay,
        reward_generator,
        reward_applier,
        _reward_context,
    )
    _reward_controller.choice_applied.connect(_on_reward_choice_applied)


## Opens the reward choice for the wave that was just cleared. This bridge applies no terrain
## mutation, so the terrain_mutation_kind argument only satisfies the shared controller's signature
## the tick arena's overlay omits the terrain-mutation note label, so no note is ever shown for it.
func _open_reward_choice() -> void:
    var wave_number := _wave_controller.get_wave_number()
    _reward_controller.open_reward_choice(
        wave_number,
        _reward_target_points(wave_number),
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
