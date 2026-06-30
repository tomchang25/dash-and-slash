# test_player_stats.gd
# Tests Player-owned run stat buffs and reward application routing.
extends GutTest

func test_player_uses_run_local_base_stats() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    player.setup_run_stats()

    assert_eq(player.get_normal_attack_damage(), 20.0)
    assert_eq(player.get_dash_attack_damage(), 80.0)
    assert_eq(player.get_normal_attack_duration(), 0.25)
    assert_eq(player.get_dash_cooldown_duration(), 2.0)


func test_attack_buffs_mutate_run_stats() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    player.setup_run_stats()

    player.add_normal_attack_damage(10.0)
    player.add_dash_attack_damage(20.0)
    player.reduce_normal_attack_cooldown(0.05)

    assert_eq(player.get_normal_attack_damage(), 30.0)
    assert_eq(player.get_dash_attack_damage(), 100.0)
    assert_eq(player.get_normal_attack_duration(), 0.2)


func test_cooldown_buffs_clamp_to_minimums() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    player.setup_run_stats()

    player.reduce_normal_attack_cooldown(99.0)
    player.reduce_dash_cooldown(99.0)

    assert_eq(player.get_normal_attack_duration(), 0.08)
    assert_eq(player.get_dash_cooldown_duration(), 0.5)


func test_dash_cooldown_buff_clamps_active_cooldown() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    player.setup_run_stats()
    player.set("_dash_cooldown_remaining", 2.0)

    player.reduce_dash_cooldown(1.0)

    assert_eq(player.get_dash_cooldown(), 1.0)


func test_reward_applier_routes_concrete_player_buff() -> void:
    var player: Player = autofree(Player.new())
    player.player_stats = _make_stats()
    player.setup_run_stats()
    var applier := WaveRewardApplier.new(null, player, Callable(), RandomNumberGenerator.new())
    var definition := WaveRewardEffectDefinition.new(
        "dash_damage_up",
        WaveRewardEffectDefinition.Kind.ADD_PLAYER_DASH_ATTACK_DAMAGE,
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

    applier.apply(choice)

    assert_eq(player.get_dash_attack_damage(), 100.0)


func _make_stats() -> PlayerStatsData:
    var stats := PlayerStatsData.new()
    stats.max_health = 100.0
    stats.normal_attack_damage = 20.0
    stats.normal_attack_cooldown = 0.25
    stats.dash_attack_damage = 80.0
    stats.dash_cooldown = 2.0
    return stats
