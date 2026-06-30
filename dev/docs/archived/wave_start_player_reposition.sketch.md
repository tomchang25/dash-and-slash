# Wave Start Player Reposition

## Goal

Move the player to a safe central land cell when each wave starts so terrain changes cannot leave the player stuck at an edge, on removed terrain, or in a bad spawn position.

## Requirements

1. Each wave begins by placing the player on a safe land cell near the arena center.
2. If the exact center is not valid, the system chooses the nearest valid empty land cell.
3. Repositioning happens before enemy spawn telegraphs are chosen so spawn selection can treat the updated player cell as authoritative.
4. Repositioning should preserve the player as a world-space actor, not convert player movement into grid movement.

## Design

The reposition is a wave-start safety reset, not a combat movement ability. It should happen during the transition between reward choice and enemy spawning, when no active enemies remain from the previous normal wave.

The preferred target is the arena center if it is land and unblocked. If not, the fallback searches outward for the nearest empty land cell. The result updates the player's world position and the grid's player-cell tracking before enemy spawn cells are chosen.

## Sketch (non-normative)

Suggested wave-start call order:

```gdscript
func _begin_wave(wave_index: int) -> void:
    _reposition_player_for_wave_start()
    _prepare_wave_spawns(wave_index)
    _show_spawn_telegraphs()
```

Suggested helper:

```gdscript
func _reposition_player_for_wave_start() -> void:
    var center_cell := _grid.grid_size / 2
    var target_cell := center_cell
    if not _grid.is_walkable(center_cell) or not _grid.is_empty(center_cell):
        target_cell = _grid.nearest_empty_cell(_grid.cell_center(center_cell))
    _player.global_position = _grid.cell_center(target_cell)
    _grid.set_player_cell(_player.global_position)
```

Migration steps:

1. Add a wave-start reposition helper in the stage or wave orchestration layer.
2. Call it before enemy spawn cells are selected.
3. Keep the helper independent from reward selection so it also protects direct wave starts.
4. Add coverage or manual verification for center-valid and center-blocked fallback cases.

## Non-Goals

1. Do not make player movement grid-locked.
2. Do not add a visible teleport effect in this phase.
3. Do not reposition the player mid-wave.

## Acceptance Criteria

1. Starting a wave places the player on a land cell near the center.
2. Enemy spawn selection uses the updated player cell.
3. The player is not placed on sea, occupied, or reserved cells.
4. Normal player movement remains world-space after the wave begins.
