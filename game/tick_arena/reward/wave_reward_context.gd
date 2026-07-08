# wave_reward_context.gd
# Typed context bundle read by reward effects for both offer-eligibility and application.
# `run_build` is the shared cross-system truth every tick-compatible effect reads and writes directly.
class_name WaveRewardContext
extends RefCounted

var grid: GridArena
var run_build: RunBuild

# == Lifecycle ==


func _init(init_grid: GridArena, _legacy_player: Variant, init_run_build: RunBuild) -> void:
    grid = init_grid
    run_build = init_run_build
