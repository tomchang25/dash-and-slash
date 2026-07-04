# wave_reward_context.gd
# Typed context bundle read by reward effects for both offer-eligibility and
# application. Built once per run by DashAndSlashArena and shared by the
# generator (rolling) and the applier (applying) so an effect reads the same
# owners in either use. Fields are typed rather than a Dictionary so an effect
# can only reach the owner it legitimately mutates.
class_name WaveRewardContext
extends RefCounted

var grid: GridArena
var player: Player
var run_build: RunBuild

# == Lifecycle ==


func _init(init_grid: GridArena, init_player: Player, init_run_build: RunBuild) -> void:
    grid = init_grid
    player = init_player
    run_build = init_run_build
