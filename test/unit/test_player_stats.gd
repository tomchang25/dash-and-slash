# test_player_stats.gd
# Tests Player-owned run stat projection (authored base + RunBuild store) and
# reward effect application routing.
extends GutTest

func test_player_uses_run_local_base_stats() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    player.set_run_build(RunBuild.new())
    player.setup_run_stats()

    assert_eq(player.get_normal_attack_damage(), 20.0)
    assert_eq(player.get_dash_attack_damage(), 80.0)
    assert_eq(player.get_normal_attack_duration(), 0.25)
    assert_eq(player.get_dash_cooldown_duration(), 2.0)
    assert_eq(player.get_normal_attack_range_scale(), 1.0)
    assert_eq(player.get_dash_speed(), player.DASH_SPEED)


func test_attack_buffs_mutate_run_stats() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    player.set_run_build(RunBuild.new())
    player.setup_run_stats()

    player.add_normal_attack_damage(10.0)
    player.add_dash_attack_damage(20.0)
    player.reduce_normal_attack_cooldown(0.05)

    assert_eq(player.get_normal_attack_damage(), 30.0)
    assert_eq(player.get_dash_attack_damage(), 100.0)
    assert_eq(player.get_normal_attack_duration(), 0.2)


func test_range_buffs_mutate_run_stats() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    player.set_run_build(RunBuild.new())
    player.setup_run_stats()

    player.add_attack_range(10.0)
    player.add_dash_range(50.0)

    assert_eq(player.get_normal_attack_range_scale(), 1.1)
    assert_eq(player.get_dash_speed(), player.DASH_SPEED * 1.5)


func test_dash_range_buff_clamps_to_maximum() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    player.set_run_build(RunBuild.new())
    player.setup_run_stats()

    player.add_dash_range(9999.0)

    assert_eq(player.get_dash_speed(), player.DASH_SPEED * (1.0 + player.MAX_DASH_RANGE_BONUS_PERCENT / 100.0))


func test_cooldown_buffs_clamp_to_minimums() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    player.set_run_build(RunBuild.new())
    player.setup_run_stats()

    player.reduce_normal_attack_cooldown(99.0)
    player.reduce_dash_cooldown(99.0)

    assert_eq(player.get_normal_attack_duration(), 0.08)
    assert_eq(player.get_dash_cooldown_duration(), 0.5)


func test_dash_cooldown_buff_clamps_active_cooldown() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    player.set_run_build(RunBuild.new())
    player.setup_run_stats()
    player.set("_dash_cooldown_remaining", 2.0)

    player.reduce_dash_cooldown(1.0)

    assert_eq(player.get_dash_cooldown(), 1.0)


## Two reductions that individually stay above the floor must still clamp
## correctly once their projected sum breaches it — the floor applies to the
## combined value, not to either entry.
func test_two_cooldown_reductions_only_breach_floor_when_combined() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    player.set_run_build(RunBuild.new())
    player.setup_run_stats()

    player.reduce_normal_attack_cooldown(0.1)
    player.reduce_normal_attack_cooldown(0.15)

    assert_eq(player.get_normal_attack_duration(), 0.08, "0.25 - 0.1 - 0.15 = 0.0, floored to MIN_ATTACK_DURATION")


func test_reward_applier_routes_concrete_player_buff() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    var run_build := RunBuild.new()
    player.set_run_build(run_build)
    player.setup_run_stats()
    var applier := WaveRewardApplier.new()
    var context := WaveRewardContext.new(null, player, run_build)
    var definition := DashAttackDamageEffect.new(
        "dash_damage_up",
        WaveRewardEffectDefinition.Tier.MINOR,
        "Impact Dash",
        "+%d dash attack damage",
        -1,
        20.0,
        1,
        1,
        [WaveRewardEffectDefinition.Profile.CONSERVATIVE],
    )
    var effects: Array[WaveRewardEffect] = [definition.create_effect(1)]
    var choice := WaveRewardChoice.new(WaveRewardEffectDefinition.Profile.CONSERVATIVE, -1.0, effects)

    applier.apply(choice, context)

    assert_eq(player.get_dash_attack_damage(), 100.0)
    assert_eq(run_build.total(RunBuild.CH_MOBILITY_ATTACK_DAMAGE), 20.0)


func test_reward_applier_routes_attack_range_buff() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    var run_build := RunBuild.new()
    player.set_run_build(run_build)
    player.setup_run_stats()
    var applier := WaveRewardApplier.new()
    var context := WaveRewardContext.new(null, player, run_build)
    var definition := AttackRangeEffect.new(
        "attack_range_up",
        WaveRewardEffectDefinition.Tier.MINOR,
        "Longer Reach",
        "+%d%% attack range",
        -1,
        10.0,
        1,
        1,
        [WaveRewardEffectDefinition.Profile.CONSERVATIVE],
    )
    var effects: Array[WaveRewardEffect] = [definition.create_effect(1)]
    var choice := WaveRewardChoice.new(WaveRewardEffectDefinition.Profile.CONSERVATIVE, -1.0, effects)

    applier.apply(choice, context)

    assert_eq(player.get_normal_attack_range_scale(), 1.1)
    assert_eq(run_build.total(RunBuild.CH_ATTACK_RANGE), 10.0)


## Player-stat effects are only offered when a player is present in context
## this is PlayerStatEffect's shared is_applicable, not a per-effect switch.
func test_player_stat_effect_is_not_applicable_without_player() -> void:
    var definition := AttackRangeEffect.new(
        "attack_range_up",
        WaveRewardEffectDefinition.Tier.MINOR,
        "Longer Reach",
        "+%d%% attack range",
        -1,
        10.0,
        1,
        1,
        [WaveRewardEffectDefinition.Profile.CONSERVATIVE],
    )
    var context := WaveRewardContext.new(null, null, RunBuild.new())

    assert_false(definition.is_applicable(context))


## The future-enemy effect is always applicable and records to RunBuild's
## dedicated channel rather than routing through the player.
func test_future_enemy_effect_records_to_run_build_channel() -> void:
    var run_build := RunBuild.new()
    var context := WaveRewardContext.new(null, null, run_build)
    var definition := FutureEnemyEffect.new(
        "future_enemy",
        WaveRewardEffectDefinition.Tier.MINOR,
        "Raise Pressure",
        "+%d future enemy",
        1,
        1.0,
        4,
        1,
        [WaveRewardEffectDefinition.Profile.CONSERVATIVE],
    )

    assert_true(definition.is_applicable(context))
    definition.apply(context, 3)

    assert_eq(run_build.total(RunBuild.CH_FUTURE_ENEMY_COUNT), 3.0)


func _make_stats() -> PlayerStatsData:
    var stats := PlayerStatsData.new()
    stats.max_health = 100.0
    stats.normal_attack_damage = 20.0
    stats.normal_attack_cooldown = 0.25
    stats.dash_attack_damage = 80.0
    stats.dash_cooldown = 2.0
    return stats
