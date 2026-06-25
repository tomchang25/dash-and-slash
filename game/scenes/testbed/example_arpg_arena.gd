# example_arpg_arena.gd
# Block 01 (action-rpg) — the real-time system driver. Owns cross-entity, timed
# behaviour the individual entities should not: spawning enemies on an interval,
# assigning each the player as its chase target, and releasing them back to the pool
# on death. Per-entity behaviour (the player's input, an enemy's steering) stays on
# the entities; batch/management behaviour lives here.
#
# Also wires the save spine: registers the live player with WorldState and binds
# save/load to keys, demonstrating snapshot-at-save-point persistence.
extends Node2D

# ── Constants ─────────────────────────────────────────────────────────────────

const EnemyScene := preload("res://game/entities/enemies/chase_enemy.tscn")
const SPAWN_SECONDS := 1.5
const SPAWN_RADIUS := 320.0
const MAX_ENEMIES := 12

# ── Node references ───────────────────────────────────────────────────────────

@onready var _player: Entity = $Player
@onready var _hp_label: Label = $HUD/HpLabel

# ── State ─────────────────────────────────────────────────────────────────────

var _spawn_timer: Timer
var _live_enemies: Array[Entity] = []


# ══ Lifecycle ═════════════════════════════════════════════════════════════════

func _ready() -> void:
	WorldState.set_player(_player)
	if _player.health != null:
		_player.health.health_changed.connect(_on_player_health_changed)
		_on_player_health_changed(_player.health.current(), _player.health.max_health)

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = SPAWN_SECONDS
	_spawn_timer.timeout.connect(_on_spawn_tick)
	# node-src: timer
	add_child(_spawn_timer)
	_spawn_timer.start()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_focus_next"):   # Tab — save
		SaveManager.save()
	elif event.is_action_pressed("ui_cancel"):     # Esc — load
		SaveManager.load()


# ══ Signal handlers ════════════════════════════════════════════════════════════

func _on_spawn_tick() -> void:
	if _live_enemies.size() >= MAX_ENEMIES:
		return
	var enemy := NodePool.acquire(EnemyScene, self) as Entity
	var angle := randf() * TAU
	enemy.global_position = _player.global_position + Vector2.RIGHT.rotated(angle) * SPAWN_RADIUS
	if enemy.has_method("set_target"):
		enemy.set_target(_player)
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	_live_enemies.append(enemy)


func _on_enemy_died(enemy: Entity) -> void:
	_live_enemies.erase(enemy)
	NodePool.release(enemy)


func _on_player_health_changed(current: float, maximum: float) -> void:
	_hp_label.text = "HP: %d / %d   (Tab = save)" % [int(current), int(maximum)]
