# build_inspection_total_row.gd
# Compact label/value row for one build-inspection totals entry: a channel total, the mobility
# payload summary, or a mobility trigger line. Visual formatting only.
class_name BuildInspectionTotalRow
extends HBoxContainer

# -- State --

var _row_data: Dictionary = { }

# -- Node references --

@onready var _name_label: Label = %NameLabel
@onready var _value_label: Label = %ValueLabel

# == Lifecycle ==


func _ready() -> void:
    if not _row_data.is_empty():
        _apply()

# == Common API ==


## Stores the row data this row displays, refreshing immediately if already in the scene tree.
## Safe to call before or after add_child().
func setup(row_data: Dictionary) -> void:
    _row_data = row_data
    if is_node_ready():
        _apply()


## Re-paints the row from its already-stored data. No-op before the row enters the scene tree.
func refresh() -> void:
    if is_node_ready():
        _apply()

# == View ==


func _apply() -> void:
    var style: StringName = _row_data.get("style", &"")
    var value: String = _row_data.get("value", "")
    _name_label.text = _row_data.get("label", "")
    _name_label.theme_type_variation = style
    _value_label.text = value
    _value_label.visible = value != ""
    _value_label.theme_type_variation = style
