# world_state.gd
# Save provider for the action-rpg preset. In a real-time game entities own their
# own state, so this provider does NOT hold state during play — at a save point it
# reads a snapshot of what must persist (here: the player's hp and position) into the
# save, and writes it back on load. Contrast the sim preset, where a Store IS the
# live state. The base save contract is unchanged.
#
# The arena registers the live player with set_player(); register_provider() makes
# this the save section "world".
extends Node

# ── State (snapshot only — populated at save/load, not during play) ──────────────

var _player: Entity = null
## Last loaded snapshot, applied to the player once it is registered.
var _pending: Dictionary = {}


func _ready() -> void:
	SaveManager.register_provider(self)


# ══ Common API ════════════════════════════════════════════════════════════════

## Registers the live player and applies any snapshot already loaded from disk.
func set_player(player: Entity) -> void:
	_player = player
	if not _pending.is_empty():
		_apply_to_player(_pending)
		_pending = {}


# ══ Save contract ═════════════════════════════════════════════════════════════

func to_dict() -> Dictionary:
	var hp := 0.0
	var pos := Vector2.ZERO
	if is_instance_valid(_player):
		pos = _player.global_position
		if _player.health != null:
			hp = _player.health.current()
	return {
		"world": {
			"_version": 1,
			"player_hp": hp,
			"player_x": pos.x,
			"player_y": pos.y,
		}
	}


func from_dict(data: Dictionary) -> void:
	var section: Dictionary = data.get("world", {})
	if is_instance_valid(_player):
		_apply_to_player(section)
	else:
		_pending = section   # player not spawned yet; apply on set_player()


func validate() -> bool:
	return true


# ══ Internal ══════════════════════════════════════════════════════════════════

func _apply_to_player(section: Dictionary) -> void:
	_player.global_position = Vector2(
		float(section.get("player_x", _player.global_position.x)),
		float(section.get("player_y", _player.global_position.y)),
	)
	if _player.health != null and section.has("player_hp"):
		var target_hp := float(section["player_hp"])
		_player.health.reset()
		var delta := _player.health.current() - target_hp
		if delta > 0.0:
			_player.health.take_damage(delta)
