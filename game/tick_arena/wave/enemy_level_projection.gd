# enemy_level_projection.gd
# Typed level-projection result: EnemyLevelProgressionProfile.project() returns instances of this
# class instead of a dictionary, so runtime consumers read named fields for an enemy's final
# projected max HP, max Guard, Defense, and shared outgoing-damage multiplier. A default-constructed
# instance is Level 1 identity (zero growth, multiplier 1.0) with zeroed base stats.
class_name EnemyLevelProjection
extends RefCounted

var max_health := 0.0
var max_guard := 0
var defense := 0.0
var damage_multiplier := 1.0
