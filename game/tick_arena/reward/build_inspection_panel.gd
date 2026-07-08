# build_inspection_panel.gd
# Toggleable, read-only view over the run's shared RunBuild: owned-artifact rows and aggregate
# build-total rows (channels, mobility payload, mobility triggers). Rebuilds its row children from
# BuildInspectionFormatter on open, reward application, and run reset; keeps no authoritative copy
# of owned artifacts or totals between refreshes.
class_name BuildInspectionPanel
extends PanelContainer

# -- Constants --

const ArtifactRowScene: PackedScene = preload("res://game/tick_arena/reward/build_inspection_artifact_row.tscn")
const TotalRowScene: PackedScene = preload("res://game/tick_arena/reward/build_inspection_total_row.tscn")

# -- State --

var _run_build: RunBuild = null

# -- Node references --

@onready var _close_button: Button = %CloseButton
@onready var _owned_empty_label: Label = %OwnedEmptyLabel
@onready var _owned_list: VBoxContainer = %OwnedList
@onready var _totals_list: VBoxContainer = %TotalsList

# == Lifecycle ==


func _ready() -> void:
    _close_button.pressed.connect(_on_close_pressed)

    if _run_build != null:
        _apply()

# == Signal handlers ==


func _on_close_pressed() -> void:
    close()

# == Common API ==


## Stores the shared run-scoped RunBuild this panel reads from. TickArena owns and injects this
## reference; the panel never constructs or replaces it.
func setup(run_build: RunBuild) -> void:
    _run_build = run_build
    if is_node_ready():
        _apply()


## Shows the panel and rebuilds its rows from the live run build.
func open() -> void:
    visible = true
    if is_node_ready():
        _apply()


## Hides the panel. Closing changes no run state because the panel only reads RunBuild.
func close() -> void:
    visible = false


## Shows the panel if hidden, or hides it if shown.
func toggle() -> void:
    if visible:
        close()
    else:
        open()


## Rebuilds rows from the live run build. No-op before the panel enters the scene tree.
func refresh() -> void:
    if is_node_ready():
        _apply()

# == View ==


func _apply() -> void:
    if _run_build == null:
        return
    _apply_owned_artifacts()
    _apply_totals()


func _apply_owned_artifacts() -> void:
    _clear_children(_owned_list)
    var rows := BuildInspectionFormatter.build_artifact_rows(_run_build)
    _owned_empty_label.visible = rows.is_empty()
    for row_data in rows:
        var row: BuildInspectionArtifactRow = ArtifactRowScene.instantiate()
        row.setup(row_data)
        _owned_list.add_child(row)


func _apply_totals() -> void:
    _clear_children(_totals_list)
    var rows: Array[Dictionary] = []
    rows.append_array(BuildInspectionFormatter.build_channel_rows(_run_build))
    rows.append(BuildInspectionFormatter.build_payload_row(_run_build))
    rows.append_array(BuildInspectionFormatter.build_trigger_rows(_run_build))
    for row_data in rows:
        var row: BuildInspectionTotalRow = TotalRowScene.instantiate()
        row.setup(row_data)
        _totals_list.add_child(row)


## Frees every current child immediately rather than via queue_free(), so a rebuild never renders
## both the outgoing and incoming rows in the same frame.
func _clear_children(container: Node) -> void:
    for child in container.get_children():
        child.free()
