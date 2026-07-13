# enemy_tick_runtime.gd
# Per-enemy tick combat runtime: owns the clocked combat status an enemy carries between world ticks —
# the committed attack's locked tiles, the player-action countdown to detonation, and the post-attack
# recovery window. One instance per enemy. The enemy entity stays the engine-facing actor and sequences
# detonation through these primitives. Centralizing the counters here keeps their invariants in one
# owner instead of scattered across the shared base, the states, and the engine.
class_name EnemyTickRuntime
extends RefCounted

# -- State --

## The committed attack's locked footprint, checked against the player's cell at detonation.
var _attack_tiles: Array[Vector2i] = []
## Player-actions remaining until the committed attack detonates; -1 when no attack is pending.
var _attack_ticks := -1
## World ticks the enemy stays disabled in its post-attack recovery window.
var _recovery_ticks := 0

# == Common API ==


## Locks a committed attack: stores its footprint tiles and starts the player-action countdown.
func commit_attack(tiles: Array[Vector2i], ticks: int) -> void:
    _attack_tiles = tiles
    _attack_ticks = ticks


## True while a committed attack is still counting down (the enemy is frozen until it detonates).
func has_pending_attack() -> bool:
    return _attack_ticks > 0


## The committed attack's locked footprint tiles (live reference; callers that mutate must duplicate).
func attack_tiles() -> Array[Vector2i]:
    return _attack_tiles


## Player-actions remaining until detonation; -1 when no attack is pending.
func attack_ticks() -> int:
    return _attack_ticks


## Counts the pending attack down by one player action and returns the remaining count.
func step_attack_countdown() -> int:
    _attack_ticks -= 1
    return _attack_ticks


## Drops the committed attack: clears the locked tiles and the countdown.
func clear_attack() -> void:
    _attack_tiles.clear()
    _attack_ticks = -1


## Returns the danger display payload ({cells, ticks}) for a pending attack, or an empty dictionary.
func danger() -> Dictionary:
    if _attack_ticks <= 0 or _attack_tiles.is_empty():
        return { }
    return {
        "cells": _attack_tiles.duplicate(),
        "ticks": _attack_ticks,
    }


## World ticks left in the recovery window; 0 when not recovering.
func recovery_remaining() -> int:
    return _recovery_ticks


## Opens a recovery window of the given world-tick length (the enemy is disabled until it counts out).
func begin_recovery(ticks: int) -> void:
    _recovery_ticks = ticks


## Cancels any pending recovery window (used on guard break so no saved-up recovery survives a stagger).
func clear_recovery() -> void:
    _recovery_ticks = 0


## Counts the recovery window down by one world tick. Returns true while the enemy is still recovering
## (disabled this tick), so the engine neither funds an action nor lets it bank energy.
func advance_recovery() -> bool:
    if _recovery_ticks > 0:
        _recovery_ticks -= 1
        return true
    return false
