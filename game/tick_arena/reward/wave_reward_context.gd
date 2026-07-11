# wave_reward_context.gd
# Typed context bundle read by reward effects for both offer-eligibility and application.
# `run_build` is the shared cross-system truth every tick-compatible effect reads and writes directly.
class_name WaveRewardContext
extends RefCounted

var grid: GridArena
var run_build: RunBuild
var mobility_id: StringName

# == Lifecycle ==


func _init(init_grid: GridArena, init_run_build: RunBuild, init_mobility_id := &"") -> void:
    grid = init_grid
    run_build = init_run_build
    mobility_id = init_mobility_id
