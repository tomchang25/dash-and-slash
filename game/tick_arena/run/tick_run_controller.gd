# tick_run_controller.gd
# Owns tick-arena run flow: starts and advances waves through WaveController, the wave-clear
# banner timing, the reward choice open/apply flow, the wave-10 demo-completion branch, terminal
# RunOutcome finalization, and the reset hook seam. Wave/spawn logistics (group scheduling,
# population cap, spawn warnings, boss role, level projection) belong to WaveController and its
# EnemySpawnPlanner/EnemySpawner collaborators, not here. Restart clears this controller's own
# injected RunBuild in place via reset_run(); the arena root constructs that store once at setup
# and never replaces it.
class_name TickRunController
extends Node

signal reward_applied
signal run_reset_finished
signal spawn_warning_changed(cells: Array[Vector2i], ticks: int)

## Explicit reward-flow state so the choice_applied handler and restart/death cleanup can never
## misinterpret which step, if any, is pending. NONE means no offer is open.
enum RewardFlowState {
    NONE,
    AWAITING_NORMAL_REWARD,
    AWAITING_MILESTONE_REWARD,
}

# -- Constants --

const REWARD_OPEN_DELAY := 2.0
const WAVE_BANNER_FADE := 0.35
const DebugWaveOneBossScene := preload("res://game/entities/enemies/mode_boss.tscn")

# -- Exports --

@export var grid: GridArena
@export var engine: TickEngine
@export var player: TickPlayer
@export var enemy_container: Node2D
@export var action_controller: TickActionController
@export var reward_overlay: WaveRewardOverlay
@export var artifact_registry: ArtifactRegistry
@export var wave_catalog: WaveCatalog
@export var wave_banner_overlay: Control
@export var wave_banner_label: Label
@export var demo_completion_overlay: DemoCompletionOverlay
@export var result_overlay: RunResultOverlay

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
var _highest_completed_wave := 0
var _demo_completed := false
var _run_finalized := false
## The terminal snapshot for this run identity. It remains available after the result overlay has
## formatted it, so a later scene-local consumer can read the same finalized outcome.
var _run_outcome: RunOutcome = null
var _rng := RandomNumberGenerator.new()

# -- Timer / tween handles --

var _wave_banner_tween: Tween

# == Lifecycle ==


func _ready() -> void:
    result_overlay.restart_pressed.connect(_on_restart_button_pressed)
    result_overlay.main_menu_pressed.connect(_on_main_menu_button_pressed)
    demo_completion_overlay.end_run_pressed.connect(_on_end_run_button_pressed)
    demo_completion_overlay.continue_endless_pressed.connect(_on_continue_endless_button_pressed)

# == Signal handlers ==


## Advances the reward-flow state machine once the open offer applies: both a normal reward pick
## and a milestone reward pick finish the flow and start the next wave. Milestone offers never open
## a curse confirmation.
func _on_reward_choice_applied() -> void:
    match _reward_flow_state:
        RewardFlowState.NONE:
            ToastManager.show_dev_error("TickRunController: reward applied with no pending reward flow")
        RewardFlowState.AWAITING_NORMAL_REWARD, RewardFlowState.AWAITING_MILESTONE_REWARD:
            _finish_reward_flow()


## Locks player input, stores the completed wave's number for the reward flow that follows, records
## it as the run's new highest completed wave before any post-wave presentation, and shows the
## "WAVE END" banner once the wave controller reports every queued and alive enemy is gone; the
## wave-10 demo-completion branch or the reward choice only opens once the banner has fully faded
## out.
func _on_normal_wave_completed(wave_number: int) -> void:
    _completed_wave_number = wave_number
    _highest_completed_wave = max(_highest_completed_wave, wave_number)
    action_controller.set_input_locked(true)
    _show_wave_banner("WAVE END")


## The result overlay's restart intent; resets this controller's own injected RunBuild in place
## instead of asking the arena root to build a replacement. Ignored once the result overlay is no
## longer showing, so a stale/duplicate button press can never re-enter reset mid-flow.
func _on_restart_button_pressed() -> void:
    if not result_overlay.visible:
        return
    reset_run()


## The result overlay's Main Menu intent. Ignored once the result overlay is no longer showing. A
## successful route clears the paused result state so the arriving menu can process normally.
func _on_main_menu_button_pressed() -> void:
    if not result_overlay.visible:
        return
    if SceneRouter.go_to_main_menu():
        result_overlay.hide_result()
        get_tree().paused = false


## The wave-10 demo-completion overlay's End Run intent: finalizes the run successfully. Ignored
## once the overlay is no longer showing or the run has already finalized, so a duplicate or
## stale press can never create a second RunOutcome.
func _on_end_run_button_pressed() -> void:
    if not demo_completion_overlay.visible or _run_finalized:
        return
    demo_completion_overlay.hide_choice()
    _finalize_run(RunOutcome.Reason.END_RUN)


## The wave-10 demo-completion overlay's Continue Endless intent: leaves the run non-terminal,
## unpauses, and opens the normal wave-10 milestone reward before the endless template starts.
## Ignored once the overlay is no longer showing or the run has already finalized.
func _on_continue_endless_button_pressed() -> void:
    if not demo_completion_overlay.visible or _run_finalized:
        return
    demo_completion_overlay.hide_choice()
    get_tree().paused = false
    _open_reward_choice()


func _on_spawn_warning_changed(cells: Array[Vector2i], ticks: int) -> void:
    spawn_warning_changed.emit(cells, ticks)


## Forwards a newly recorded positive Max Health contribution to the player as an immediate current-hp
## gain, clamped at the maximum this contribution just raised. Every other channel, and non-positive
## deltas, must never reach the player as a heal; a run reset clears the store without calling
## record(), so it never fires this handler either.
func _on_run_build_contribution_recorded(channel: StringName, delta: float, total: float) -> void:
    if channel != RunBuild.CH_MAX_HEALTH or delta <= 0.0:
        return
    player.apply_max_health_gain(delta, total)

# == Common API ==


## Stores the run build that reward effects write to, seeds the spawn/reward RNG, and wires the
## reward choice and wave flow; the tick arena root owns and constructs the shared RunBuild instance.
func setup(run_build: RunBuild, character_class: CharacterClassData) -> void:
    _run_build = run_build
    _character_class = character_class
    _rng.randomize()
    _run_build.contribution_recorded.connect(_on_run_build_contribution_recorded)
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


## TickEngine emits player death only after the killing tick fully resolves; this finalizes the run
## with a DEATH outcome instead of resetting immediately, so the player can see what killed them
## before restarting. Combat input stays locked and the wave controller force-kills/stops spawning
## so nothing keeps acting behind the results overlay; restart is the only recovery path from here.
func handle_player_died() -> void:
    _finalize_run(RunOutcome.Reason.DEATH)


## Cancels any pending wave-end banner/reward-open callback before resetting, so a restart during the
## banner countdown, an open reward choice, or the demo-completion branch can never let that stale
## flow reopen or reapply after the run has already reset. Clears the run's own RunBuild in place
## instead of replacing it, so the reward context and wave controller keep the same reference they
## were injected with at setup. Clears result/demo state, the run-finalization guard, and the
## highest-completed-wave state for the fresh run identity that follows.
func reset_run() -> void:
    _cancel_pending_wave_flow()
    result_overlay.hide_result()
    _run_finalized = false
    _run_outcome = null
    _demo_completed = false
    _highest_completed_wave = 0
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


## Returns this run's terminal snapshot, or null while the run remains active or after reset.
func get_run_outcome() -> RunOutcome:
    return _run_outcome

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
## reward offer or the demo-completion branch, unpausing the tree — the shared cleanup death,
## End Run, and restart all need so neither can leave a stale banner/reward/demo-flow step able to
## fire once the store clears.
func _cancel_pending_wave_flow() -> void:
    if _wave_banner_tween != null and _wave_banner_tween.is_valid():
        _wave_banner_tween.kill()
    wave_banner_overlay.visible = false
    _reward_controller.cancel()
    _reward_flow_state = RewardFlowState.NONE
    demo_completion_overlay.hide_choice()
    get_tree().paused = false

# == Terminal Outcome ==


## Creates exactly one RunOutcome for this run identity, on first call only: stops wave scheduling,
## locks input, snapshots the run's terminal data, pauses safely, and shows the results overlay.
## Both death and a successful End Run route through here, so neither path can ever create a second
## outcome for the same run.
func _finalize_run(reason: RunOutcome.Reason) -> void:
    if _run_finalized:
        return
    _run_finalized = true
    _cancel_pending_wave_flow()
    action_controller.set_input_locked(true)
    _wave_controller.end_run()
    _run_outcome = RunOutcome.new(reason, _character_class, _highest_completed_wave, _demo_completed)
    get_tree().paused = true
    result_overlay.show_result(_run_outcome)


## Marks run-local demo completion once, pauses, and opens the wave-10 End Run / Continue Endless
## choice. Reached only once, right after the wave-10 banner fades.
func _open_demo_completion_choice() -> void:
    _demo_completed = true
    get_tree().paused = true
    demo_completion_overlay.show_choice()

# == Wave Controller ==


## Wires the wave controller and its spawn collaborators against this arena's grid, engine, and
## enemy container. The spawn planner reads the player's logical cell through a callable instead
## of a concrete player type, per EnemySpawnPlanner's arena-agnostic contract.
func _wire_wave_controller() -> void:
    _spawn_planner = EnemySpawnPlanner.new(grid, func() -> Vector2i: return player.cell)
    _spawner = EnemySpawner.new(grid, player, enemy_container, engine)
    _wave_controller = WaveController.new()
    _wave_controller.setup(grid, _spawn_planner, _spawner, engine)
    _wave_controller.set_catalog(wave_catalog)
    _wave_controller.set_debug_wave_one_boss_scene(DebugWaveOneBossScene)
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
## milestone offer with a fixed Minor x2 first slot and per-slot Major-or-Minor x2 fallback. Major
## cadence is decided here, purely from the completed wave number — never from Boss identity, the
## catalog, or demo completion.
func _open_reward_choice() -> void:
    if _is_major_reward_wave(_completed_wave_number):
        _reward_flow_state = RewardFlowState.AWAITING_MILESTONE_REWARD
        _reward_controller.show_offer("Milestone Reward", _build_milestone_offer(_completed_wave_number))
    else:
        _reward_flow_state = RewardFlowState.AWAITING_NORMAL_REWARD
        _reward_controller.show_offer("Choose a Reward", _build_normal_offer(_completed_wave_number))


## Every-third completed wave opens the Major milestone offer; every other wave opens the normal
## Minor offer. This is the sole cadence input: Boss wave 10 is not divisible by three, so continuing
## past it opens a normal offer, and wave 12 opens a Major offer despite having no Boss.
func _is_major_reward_wave(wave_number: int) -> bool:
    return wave_number > 0 and wave_number % 3 == 0


## Ends the current reward flow and starts the next wave — the sole path back to gameplay after a
## normal or milestone reward pick.
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


## Wave 10 branches into the demo-completion choice instead of the normal reward flow; every other
## wave keeps the normal reward-choice open.
func _hide_wave_banner_and_open_reward() -> void:
    wave_banner_overlay.visible = false
    if _completed_wave_number == WaveCatalog.DEMO_WAVE_COUNT:
        _open_demo_completion_choice()
    else:
        _open_reward_choice()
