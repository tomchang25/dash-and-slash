# wave_composition_entry.gd
# One authored enemy entry within a WaveGroupDefinition's composition: the PackedScene the spawn
# boundary instantiates, plus a fixed-mode count or a weighted-mode selection weight. WaveGroupDefinition
# interprets count vs weight according to its own composition_mode; this resource stores both so
# authors can switch a group's mode without re-authoring entries.
class_name WaveCompositionEntry
extends Resource

# -- Exports --

@export var enemy_scene: PackedScene
## Fixed-mode entry count. Ignored in weighted mode.
@export var count := 0
## Weighted-mode selection weight. Ignored in fixed mode.
@export var weight := 0.0
