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

## Explicit reward-flow state so the choice_applied handler and restart/death cleanup can never
## misinterpret which step, if any, is pending. NONE means no offer or confirmation is open.
enum RewardFlowState {
    NONE,
    AWAITING_NORMAL_REWARD,
    AWAITING_MILESTONE_REWARD,
    AWAITING_CURSE_CONFIRMATION,
}

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
@export var artifact_registry: ArtifactRegistry
@export var wave_banner_overlay: Control
@export var wave_banner_label: Label
@export var death_overlay: Control
@export var restart_button: Button

# -- State --

var _run_build: RunBuild
var _character_class: CharacterClassData
var _wave_controller: WaveController
var _spawn_planner: EnemySpawnPlanner
var _spawner: EnemySpawner
var _reward_controller: WaveRewardChoiceController
var _reward_generator: WaveRewardChoiceGenerator
var _reward_context: WaveRewardContext
var _reward_flow_state := RewardFlowState.NONE
var _completed_wave_number := 0
var _completed_wave_is_milestone := false
var _rng := RandomNumberGenerator.new()

# -- Timer / tween handles --

var _wave_banner_tween: Tween

# == Lifecycle ==


func _ready() -> void:
    restart_button.pressed.connect(_on_restart_button_pressed)

# == Signal handlers ==


## Advances the reward-flow state machine once the open offer or confirmation applies: a normal
## reward or a confirmed curse finishes the flow and starts the next wave, while a milestone reward
## pick opens the forced curse confirmation instead of finishing immediately.
func _on_reward_choice_applied() -> void:
    match _reward_flow_state:
        RewardFlowState.NONE:
            ToastManager.show_dev_error("TickRunController: reward applied with no pending reward flow")
        RewardFlowState.AWAITING_NORMAL_REWARD:
            _finish_reward_flow()
        RewardFlowState.AWAITING_MILESTONE_REWARD:
            _open_curse_confirmation()
        RewardFlowState.AWAITING_CURSE_CONFIRMATION:
            _finish_reward_flow()


## Locks player input, stores the completed wave's number and milestone flag for the reward flow
## that follows, and shows the "WAVE END" banner once the wave controller reports every queued and
## alive enemy is gone; the reward choice only opens once the banner has fully faded out.
func _on_normal_wave_completed(wave_number: int, is_milestone_wave: bool) -> void:
    _completed_wave_number = wave_number
    _completed_wave_is_milestone = is_milestone_wave
    action_controller.set_input_locked(true)
    _show_wave_banner("WAVE END")


## The death overlay's only recovery path; resets this controller's own injected RunBuild in place
## instead of asking the arena root to build a replacement.
func _on_restart_button_pressed() -> void:
    reset_run()


func _on_spawn_warning_changed(cells: Array[Vector2i], ticks: int) -> void:
    spawn_warning_changed.emit(cells, ticks)

# == Common API ==


## Stores the run build the reward flow and wave controller apply effects onto/read pressure from,
## seeds the spawn/reward RNG, and wires the reward choice and wave flow; the tick arena root owns
## and constructs the shared RunBuild instance.
func setup(run_build: RunBuild, character_class: CharacterClassData) -> void:
    _run_build = run_build
    _character_class = character_class
    _rng.randomize()
    _wire_reward_flow()
    _wire_wave_controller()


## Updates the class carried by reward eligibility at the run-reset boundary.
func set_character_class(character_class: CharacterClassData) -> void:
    _character_class = character_class
    if _reward_context != null:
        _reward_context.mobility_id = character_class.mobility_id if character_class != null else &""


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
func reset_run() -> void:
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
    run_reset_finished.emit()


## Returns the active spawn-warning display payload from the wave controller, or an empty dictionary.
func get_spawn_warning_danger() -> Dictionary:
    if _wave_controller == null:
        return { }
    return _wave_controller.get_spawn_warning_danger()


## Returns the current wave's display text, so the HUD can read wave state through this controller
## instead of reaching into WaveController directly.
func get_wave_display_text() -> String:
    if _wave_controller == null:
        return ""
    return _wave_controller.get_wave_display_text()

# == Debug (see dev/standards/debug_standard.md §4a/§5) ==


## Debug-only: force-kills every currently alive enemy through the wave controller's existing
## force-kill path, so wave bookkeeping, grid occupancy cleanup, and completion signals still fire
## exactly as if the enemies died normally. The arena root calls this instead of reaching through
## to the owned WaveController directly.
func debug_kill_all_enemies() -> void:
    if not Debug.enabled:
        return
    if _wave_controller == null:
        return
    _wave_controller.force_kill_all_enemies()

# == Death / Restart ==


## Kills any in-flight wave-end banner tween, hides the wave banner overlay, and cancels any open
## reward offer or curse confirmation, unpausing the tree — the shared cleanup death and restart
## both need so neither can leave a stale banner/reward-flow step able to fire once the store clears.
func _cancel_pending_wave_flow() -> void:
    if _wave_banner_tween != null and _wave_banner_tween.is_valid():
        _wave_banner_tween.kill()
    wave_banner_overlay.visible = false
    _reward_controller.cancel()
    _reward_flow_state = RewardFlowState.NONE
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


## Wires the shared reward generator/context/controller and overlay flow against this arena's own
## RunBuild, so a picked artifact writes through the same store tick verbs read. Every artifact —
## legendary or common — reads and writes RunBuild directly through its effect contributions, while
## the context also carries the class-owned Mobility used only for offer eligibility. The arena
## scene injects the production artifact registry explicitly.
func _wire_reward_flow() -> void:
    if artifact_registry == null:
        ToastManager.show_dev_error("TickRunController: missing artifact registry")
        artifact_registry = ArtifactRegistry.new()
    _reward_generator = WaveRewardChoiceGenerator.new(artifact_registry, _rng)
    var mobility_id := _character_class.mobility_id if _character_class != null else &""
    _reward_context = WaveRewardContext.new(grid, _run_build, mobility_id)
    _reward_controller = WaveRewardChoiceController.new(reward_overlay, _reward_context)
    _reward_controller.choice_applied.connect(_on_reward_choice_applied)


## Opens the reward offer for the wave that was just cleared: a normal Minor three-choice, or a
## milestone offer with a fixed Minor x2 first slot and per-slot Major-or-Minor x2 fallback.
func _open_reward_choice() -> void:
    if _completed_wave_is_milestone:
        _reward_flow_state = RewardFlowState.AWAITING_MILESTONE_REWARD
        _reward_controller.show_offer("Milestone Reward", _build_milestone_offer(_completed_wave_number))
    else:
        _reward_flow_state = RewardFlowState.AWAITING_NORMAL_REWARD
        _reward_controller.show_offer("Choose a Reward", _build_normal_offer(_completed_wave_number))


## Rolls the forced post-milestone curse and shows it as a one-card confirmation. A missing curse
## still shows a confirmation so the sequence cannot stall, but is flagged as a programmer error
## since the default curse pool should never be fully exhausted.
func _open_curse_confirmation() -> void:
    var curses := _reward_generator.roll(WaveRewardChoiceGenerator.RewardKind.CURSE, 1, _completed_wave_number, _reward_context)
    var curse_choice: WaveRewardChoice
    if curses.is_empty():
        ToastManager.show_dev_error("TickRunController: no eligible curse found for milestone wave %d" % _completed_wave_number)
        curse_choice = WaveRewardChoice.empty()
    else:
        curse_choice = curses[0]
    _reward_flow_state = RewardFlowState.AWAITING_CURSE_CONFIRMATION
    _reward_controller.show_confirmation("A Curse Takes Hold", curse_choice)


## Ends the current reward flow and starts the next wave — the sole path back to gameplay after a
## normal reward pick or a completed milestone-plus-curse sequence.
func _finish_reward_flow() -> void:
    _reward_flow_state = RewardFlowState.NONE
    action_controller.set_input_locked(false)
    _wave_controller.start_next_wave()
    reward_applied.emit()


func _build_normal_offer(wave_number: int) -> Array[WaveRewardChoice]:
    return _reward_generator.roll(WaveRewardChoiceGenerator.RewardKind.MINOR, 3, wave_number, _reward_context)


## Builds the fixed milestone offer shape: slot 1 is always one eligible Minor at two stacks
## slots 2 and 3 use an eligible Major each when available, falling back per slot to another
## Minor x2 pick so every milestone offer presents three enabled choices.
func _build_milestone_offer(wave_number: int) -> Array[WaveRewardChoice]:
    var majors := _reward_generator.roll(WaveRewardChoiceGenerator.RewardKind.MAJOR, 2, wave_number, _reward_context)
    var minor_x2_fallbacks := _roll_minor_x2_choices(wave_number, 3 - majors.size())
    var offer: Array[WaveRewardChoice] = [_take_next_choice(minor_x2_fallbacks)]
    for i in 2:
        if i < majors.size():
            offer.append(majors[i])
        else:
            offer.append(_take_next_choice(minor_x2_fallbacks))
    return offer


## Rolls the needed milestone Minor x2 fallback choices from one distinct Minor pool so the fixed
## baseline and fallback slots cannot repeat the same Minor artifact within a single offer.
func _roll_minor_x2_choices(wave_number: int, count: int) -> Array[WaveRewardChoice]:
    var picks := _reward_generator.roll(WaveRewardChoiceGenerator.RewardKind.MINOR, count, wave_number, _reward_context)
    var choices: Array[WaveRewardChoice] = []
    for pick in picks:
        choices.append(WaveRewardChoice.single(pick.artifact(), 2))
    return choices


func _take_next_choice(choices: Array[WaveRewardChoice]) -> WaveRewardChoice:
    if choices.is_empty():
        return WaveRewardChoice.empty()
    var choice: WaveRewardChoice = choices.pop_front()
    return choice

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
