# player_stats_data.gd
# Resource schema for first-pass player combat stat tuning.
class_name PlayerStatsData
extends Resource

@export var max_health := 100.0
@export var normal_attack_damage := 20.0
@export var normal_attack_cooldown := 0.25
@export var dash_attack_damage := 100.0
@export var dash_cooldown := 2.0
@export var attack_range := 152.0
# Percentage points added on top of the base 1.0 normal attack hit-geometry scale.
@export var normal_attack_range_bonus_percent := 0.0
# Percentage points added on top of the base 1.0 dash travel-distance scale.
@export var dash_range_bonus_percent := 0.0
