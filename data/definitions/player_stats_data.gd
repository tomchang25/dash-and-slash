# player_stats_data.gd
# Resource schema for first-pass player combat stat tuning.
class_name PlayerStatsData
extends Resource

@export var max_health := 100.0
@export var normal_attack_damage := 20.0
@export var normal_attack_cooldown := 0.25
@export var dash_attack_damage := 50000.0
@export var dash_cooldown := 2.0
