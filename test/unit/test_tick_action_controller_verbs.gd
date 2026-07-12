# test_tick_action_controller_verbs.gd
# Tests TickActionController's mode_set verb handling directly: default aim mode and mode_set toggling
# between Attack and Mobility. These paths touch no exported scene dependency (grid/view/engine/player),
# so the controller can be exercised without a scene tree per Phase 6b's ownership split (mode is the
# action controller's own state). Also covers the shared normal-attack/Dash action whoosh: exactly one
# play per legal committed action (hit or whiff), none for a denied action.
extends GutTest

class FakePlayer:
    extends TickPlayer

    var moved_to: Array[Vector2i] = []
    var whoosh_count := 0


    func move_to(target_cell: Vector2i, _leap := false) -> void:
        cell = target_cell
        moved_to.append(target_cell)


    func play_action_whoosh() -> void:
        whoosh_count += 1


class FakeEngine:
    extends TickEngine

    var advance_world_count := 0
    var blocked_cell: Vector2i = Vector2i(-999, -999)
    var enemy_at_blocked_cell: GridEnemy = null


    func advance_world() -> void:
        advance_world_count += 1


    func is_cell_open_for_player(target_cell: Vector2i) -> bool:
        return target_cell != blocked_cell


    func enemy_at(target_cell: Vector2i) -> GridEnemy:
        if target_cell == blocked_cell:
            return enemy_at_blocked_cell
        return null


class FakeView:
    extends TickGridView

    var denied_cells: Array[Vector2i] = []
    var swung_cells: Array[Vector2i] = []


    func flash_deny(target_cell: Vector2i) -> void:
        denied_cells.append(target_cell)


    func flash_swing(cells: Array[Vector2i]) -> void:
        swung_cells.append_array(cells)


class TestActionController:
    extends TickActionController

    func apply_chain_dash_state(outcomes: Array[TickHitOutcome]) -> void:
        _apply_chain_dash_state(outcomes)


func test_default_aim_mode_is_attack() -> void:
    var controller: TickActionController = autofree(TickActionController.new())

    assert_false(controller.is_mobility_mode())


func test_mode_set_verb_switches_to_mobility_and_back() -> void:
    var controller: TickActionController = autofree(TickActionController.new())

    controller.handle_verb(TickVerb.mode_set(true))
    assert_true(controller.is_mobility_mode())

    controller.handle_verb(TickVerb.mode_set(false))
    assert_false(controller.is_mobility_mode())


func test_default_last_aim_is_right() -> void:
    var controller: TickActionController = autofree(TickActionController.new())

    assert_eq(controller.get_last_aim(), Vector2i.RIGHT)


## Regression for the death-overlay/wave-banner input lock (Phase 6e): a locked controller must
## ignore every verb, including a mode_set that touches no exported node, so combat input can never
## sneak through while the death overlay or wave-clear banner is on screen.
func test_input_locked_blocks_verb_dispatch() -> void:
    var controller: TickActionController = autofree(TickActionController.new())

    controller.set_input_locked(true)
    controller.handle_verb(TickVerb.mode_set(true))
    assert_false(controller.is_mobility_mode(), "a locked controller must ignore even a mode_set verb")

    controller.set_input_locked(false)
    controller.handle_verb(TickVerb.mode_set(true))
    assert_true(controller.is_mobility_mode(), "unlocking should let verbs dispatch again")


func test_speed_free_move_ticks_player_cooldown_without_advancing_world() -> void:
    var context := _make_controller_context()
    var controller: TickActionController = context["controller"]
    var player: FakePlayer = context["player"]
    var engine: FakeEngine = context["engine"]
    player.dash_cooldown = 2
    player.speed_meter = TickPlayer.SPEED_METER_MAX

    controller.handle_verb(TickVerb.move(Vector2i.RIGHT))

    assert_eq(player.dash_cooldown, 1, "free actions still consume a player action for cooldowns")
    assert_eq(engine.advance_world_count, 0, "Speed-spent moves must not advance enemy/world clocks")


func test_wait_ticks_player_cooldown_once_before_advancing_world() -> void:
    var context := _make_controller_context()
    var controller: TickActionController = context["controller"]
    var player: FakePlayer = context["player"]
    var engine: FakeEngine = context["engine"]
    player.dash_cooldown = 2

    controller.handle_verb(TickVerb.wait())

    assert_eq(player.dash_cooldown, 1)
    assert_eq(engine.advance_world_count, 1)


func test_dash_sets_fresh_cooldown_after_player_action_upkeep() -> void:
    var context := _make_controller_context()
    var controller: TickActionController = context["controller"]
    var player: FakePlayer = context["player"]
    var engine: FakeEngine = context["engine"]
    player.smash_cooldown = 2

    controller.handle_verb(TickVerb.mode_set(true))
    controller.handle_verb(TickVerb.confirm())

    assert_eq(player.dash_cooldown, TickCombatRules.DASH_COOLDOWN_TICKS, "the Dash used this action should not immediately tick down")
    assert_eq(player.smash_cooldown, 1, "existing cooldowns still tick before the Dash resolves")
    assert_eq(engine.advance_world_count, 1)


func test_dash_advances_world_normally_even_when_chain_dash_is_owned() -> void:
    var context := _make_controller_context()
    var controller: TickActionController = context["controller"]
    var player: FakePlayer = context["player"]
    var engine: FakeEngine = context["engine"]
    var run_build: RunBuild = context["run_build"]
    run_build.set_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH, true)

    controller.handle_verb(TickVerb.mode_set(true))
    controller.handle_verb(TickVerb.confirm())

    assert_eq(engine.advance_world_count, 1, "the triggering Dash always advances the world normally")
    assert_eq(player.dash_cooldown, TickCombatRules.DASH_COOLDOWN_TICKS, "no victim qualifies on an empty grid, so cooldown is not cleared")


func test_viking_dispatches_smash_instead_of_dash() -> void:
    var context := _make_controller_context(CharacterClassData.MOBILITY_SMASH)
    var controller: TickActionController = context["controller"]
    var player: FakePlayer = context["player"]

    controller.handle_verb(TickVerb.mode_set(true))
    controller.handle_verb(TickVerb.confirm())

    assert_true(player.is_smash_armed())
    assert_eq(player.dash_cooldown, 0)


func test_chain_dash_state_clears_cooldown_and_prepares_speed_meter_once_for_several_qualifiers() -> void:
    var context := _make_controller_context()
    var controller: TestActionController = context["controller"]
    var player: FakePlayer = context["player"]
    var run_build: RunBuild = context["run_build"]
    var qualifying_a := TickHitOutcome.new()
    qualifying_a.staggered = true
    var qualifying_b := TickHitOutcome.new()
    qualifying_b.killed = true
    var outcomes: Array[TickHitOutcome] = [qualifying_a, qualifying_b]
    run_build.set_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH, true)
    player.dash_cooldown = TickCombatRules.DASH_COOLDOWN_TICKS
    player.speed_meter = 0

    controller.apply_chain_dash_state(outcomes)

    assert_eq(player.dash_cooldown, 0, "a qualifying Dash clears cooldown instead of refunding world time")
    assert_true(player.is_speed_meter_full(), "a qualifying Dash prepares the Speed meter as a ready follow-up free action")


func test_chain_dash_state_does_nothing_without_the_active_trigger() -> void:
    var context := _make_controller_context()
    var controller: TestActionController = context["controller"]
    var player: FakePlayer = context["player"]
    var outcome := TickHitOutcome.new()
    outcome.staggered = true
    var outcomes: Array[TickHitOutcome] = [outcome]
    player.dash_cooldown = TickCombatRules.DASH_COOLDOWN_TICKS
    player.speed_meter = 0

    controller.apply_chain_dash_state(outcomes)

    assert_eq(player.dash_cooldown, TickCombatRules.DASH_COOLDOWN_TICKS, "cooldown is unchanged when Chain Dash is not owned")
    assert_false(player.is_speed_meter_full(), "the Speed meter is unchanged when Chain Dash is not owned")


func test_chain_dash_state_does_nothing_when_no_outcome_qualifies() -> void:
    var context := _make_controller_context()
    var controller: TestActionController = context["controller"]
    var player: FakePlayer = context["player"]
    var run_build: RunBuild = context["run_build"]
    var non_qualifying := TickHitOutcome.new()
    var outcomes: Array[TickHitOutcome] = [non_qualifying]
    run_build.set_mobility_trigger(RunBuild.TRIGGER_CHAIN_DASH, true)
    player.dash_cooldown = TickCombatRules.DASH_COOLDOWN_TICKS
    player.speed_meter = 0

    controller.apply_chain_dash_state(outcomes)

    assert_eq(player.dash_cooldown, TickCombatRules.DASH_COOLDOWN_TICKS, "cooldown is unchanged when nothing qualifies")
    assert_false(player.is_speed_meter_full(), "the Speed meter is unchanged when nothing qualifies")


## Regression for the auto-attack-on-move handling: with the SettingsStore preference on, walking
## into an enemy's cell swings at it instead of just denying the move.
func test_move_into_enemy_attacks_when_auto_attack_on_move_enabled() -> void:
    var prior_setting := SettingsStore.auto_attack_on_move
    SettingsStore.auto_attack_on_move = true
    var context := _make_controller_context()
    var controller: TickActionController = context["controller"]
    var player: FakePlayer = context["player"]
    var engine: FakeEngine = context["engine"]
    var view: FakeView = context["view"]
    var target := player.cell + Vector2i.RIGHT
    engine.blocked_cell = target
    engine.enemy_at_blocked_cell = autofree(GridEnemy.new())

    controller.handle_verb(TickVerb.move(Vector2i.RIGHT))

    assert_true(view.swung_cells.has(target), "auto-attack should swing at the blocking enemy's cell")
    assert_false(view.denied_cells.has(target), "auto-attack should not also flash a deny on the same cell")
    assert_true(player.moved_to.is_empty(), "swinging at the enemy should not move the player into its cell")
    assert_eq(player.whoosh_count, 1, "the shared action whoosh should play once for the auto-attack swing")
    SettingsStore.auto_attack_on_move = prior_setting


## Counterpart to the enabled case above: with the preference off, walking into an enemy still just
## denies the move, matching pre-auto-attack behavior.
func test_move_into_enemy_denies_when_auto_attack_on_move_disabled() -> void:
    var prior_setting := SettingsStore.auto_attack_on_move
    SettingsStore.auto_attack_on_move = false
    var context := _make_controller_context()
    var player: FakePlayer = context["player"]
    var engine: FakeEngine = context["engine"]
    var view: FakeView = context["view"]
    var controller: TickActionController = context["controller"]
    var target := player.cell + Vector2i.RIGHT
    engine.blocked_cell = target
    engine.enemy_at_blocked_cell = autofree(GridEnemy.new())

    controller.handle_verb(TickVerb.move(Vector2i.RIGHT))

    assert_true(view.denied_cells.has(target), "move into an enemy should deny when the setting is off")
    assert_true(view.swung_cells.is_empty(), "no auto-attack swing should fire when the setting is off")
    assert_eq(player.whoosh_count, 0, "a denied move must not play the action whoosh")
    SettingsStore.auto_attack_on_move = prior_setting


## Every legal normal attack plays exactly one shared action whoosh, whether it whiffs or hits, because
## it communicates the committed swing rather than hit confirmation.
func test_normal_attack_whiff_plays_exactly_one_action_whoosh() -> void:
    var context := _make_controller_context()
    var controller: TickActionController = context["controller"]
    var player: FakePlayer = context["player"]

    controller.handle_verb(TickVerb.confirm())

    assert_eq(player.whoosh_count, 1, "a legal normal-attack whiff must still play one action whoosh")


func test_normal_attack_hit_plays_exactly_one_action_whoosh() -> void:
    var context := _make_controller_context()
    var controller: TickActionController = context["controller"]
    var player: FakePlayer = context["player"]
    var engine: FakeEngine = context["engine"]
    var target := player.cell + Vector2i.RIGHT
    engine.blocked_cell = target
    engine.enemy_at_blocked_cell = autofree(GridEnemy.new())

    controller.handle_verb(TickVerb.confirm())

    assert_eq(player.whoosh_count, 1, "a legal normal attack that hits must still play exactly one action whoosh")


## A legal Dash plays its whoosh outside the victim loop, so an empty-victim Dash still plays it once.
func test_dash_with_no_victims_plays_exactly_one_action_whoosh() -> void:
    var context := _make_controller_context()
    var controller: TickActionController = context["controller"]
    var player: FakePlayer = context["player"]

    controller.handle_verb(TickVerb.mode_set(true))
    controller.handle_verb(TickVerb.confirm())

    assert_eq(player.whoosh_count, 1, "a legal Dash must play exactly one action whoosh even with no victims")


func test_dash_denied_by_cooldown_plays_no_action_whoosh() -> void:
    var context := _make_controller_context()
    var controller: TickActionController = context["controller"]
    var player: FakePlayer = context["player"]
    player.dash_cooldown = 2

    controller.handle_verb(TickVerb.mode_set(true))
    controller.handle_verb(TickVerb.confirm())

    assert_eq(player.whoosh_count, 0, "a Dash denied by cooldown must not play the action whoosh")


func test_dash_denied_by_an_occupied_landing_cell_plays_no_action_whoosh() -> void:
    var context := _make_controller_context()
    var controller: TickActionController = context["controller"]
    var player: FakePlayer = context["player"]
    var engine: FakeEngine = context["engine"]
    var target := player.cell + Vector2i.RIGHT
    engine.blocked_cell = target
    engine.enemy_at_blocked_cell = autofree(GridEnemy.new())

    controller.handle_verb(TickVerb.mode_set(true))
    controller.handle_verb(TickVerb.confirm())

    assert_eq(player.whoosh_count, 0, "a Dash denied by an occupied landing cell must not play the action whoosh")


func _make_controller_context(mobility_id := CharacterClassData.MOBILITY_DASH) -> Dictionary:
    var grid: GridArena = autofree(GridArena.new())
    grid.grid_size = Vector2i(8, 8)
    grid.starting_land_size = Vector2i(8, 8)
    grid.generate_grid()

    var player: FakePlayer = autofree(FakePlayer.new())
    player.cell = Vector2i(4, 4)
    var character_class := CharacterClassData.new()
    character_class.id = &"test_class"
    character_class.display_name = "Test Class"
    character_class.base_speed_fill = 20
    character_class.mobility_id = mobility_id
    player.set_character_class(character_class)

    var engine: FakeEngine = autofree(FakeEngine.new())
    var view: FakeView = autofree(FakeView.new())
    var feedback: TickCombatFeedback = autofree(TickCombatFeedback.new())
    var controller: TestActionController = autofree(TestActionController.new())
    controller.grid = grid
    controller.engine = engine
    controller.player = player
    controller.view = view
    controller.feedback = feedback
    controller.smash_cancel_confirm_panel = autofree(Control.new())
    var run_build := RunBuild.new()
    controller.setup(run_build, character_class)

    return {
        "controller": controller,
        "player": player,
        "engine": engine,
        "view": view,
        "grid": grid,
        "feedback": feedback,
        "run_build": run_build,
    }
