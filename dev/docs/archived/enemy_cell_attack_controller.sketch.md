# Enemy Cell Attack Controller

## Goal

Unify the lifecycle for cell-based enemy attacks so tile attacks no longer need separate controller implementations. This makes attack data useful in real enemy behavior before broader special-case integration begins.

## Requirements

1. A shared attack controller owns cell snapshots, telegraph phases, hitbox setup, hitbox enablement, and cleanup.
2. Enemy classes keep AI decisions and movement ownership, because attack execution should not become a universal enemy brain.
3. Tile attack behavior migrates first, because it has the clearest duplication and the smallest behavior surface.
4. Shared cell-origin planning replaces duplicate search logic for enemies that attack from computed footprints.

## Design

The shared controller executes an attack profile selected by an enemy. It prepares cells from the selected shape, shows warning and charge phases, activates the correct hitbox, and clears all telegraph and hitbox state when the attack ends or is canceled. Enemy classes remain responsible for choosing the profile, deciding whether the target is valid, and entering their state transitions.

## Sketch (non-normative)

Proposed controller file:

```text
game/entities/enemies/enemy_attack_controller.gd
```

Proposed controller API:

```gdscript
class_name EnemyAttackController
extends Node

func setup(grid: GridArena, telegraph: TileTelegraph, tile_hitbox: Hitbox, contact_hitbox: Hitbox, puff_hitbox: Hitbox) -> void:
    pass

func prepare(origin_cell: Vector2i, facing: Vector2, attack_data: EnemyAttackData) -> bool:
    pass

func get_attack_cells(origin_cell: Vector2i, facing: Vector2, attack_data: EnemyAttackData) -> Array[Vector2i]:
    pass

func show_warning() -> void:
    pass

func show_charge() -> void:
    pass

func show_active() -> void:
    pass

func begin_attack() -> void:
    pass

func end_attack() -> void:
    pass

func cancel() -> void:
    pass

func get_cells() -> Array[Vector2i]:
    pass

func clear_cell(cell: Vector2i) -> void:
    pass
```

Proposed shape mapping:

```text
LINE -> AttackCellShapes.line
WIDE -> AttackCellShapes.wide
SQUARE -> AttackCellShapes.square
FULL_LINE -> repeatedly step in facing direction until grid bounds end
```

Proposed generalized planning helper:

```gdscript
func plan_cell_attack_action(get_cells_for_origin: Callable) -> bool:
    clear_planned_path()
    # Iterate possible origins and facings, find cells whose footprint contains the target, then path toward one valid origin.
    pass
```

Suggested migration steps:

1. Add the shared controller beside the existing enemy attack controllers.
2. Recreate the current small-enemy tile attack behavior through `EnemyAttackData` and the shared controller.
3. Replace the small enemy's controller reference with the shared controller once behavior matches.
4. Extract duplicate cell-origin planning into the shared grid enemy base.
5. Update the mode enemy's tile planning to use the shared helper without migrating its full attack controller yet.

## Non-Goals

1. Do not migrate charge or puff execution in this phase.
2. Do not consolidate state scripts in this phase.
3. Do not remove mode-specific controller behavior until the later special-attack phase.

## Acceptance Criteria

1. Small enemy tile attacks can run through the shared attack controller.
2. Tile cell shapes are selected from attack data rather than a local attack-pattern enum.
3. Cell-origin planning for tile attacks is shared between simple tile attackers and mode-based tile attackers.
4. Enemy movement and AI decisions remain in enemy classes, not in the attack controller.
