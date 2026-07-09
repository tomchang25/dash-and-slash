# artifact_strip_item.gd
# Compact icon-only cell for the tick-arena HUD's owned-artifact strip: icon, stack badge, and a
# rarity/curse readability bar, sharing BuildInspectionArtifactRow's row data shape in a smaller
# at-a-glance footprint. Visual formatting only; row data comes from BuildInspectionFormatter.
class_name ArtifactStripItem
extends PanelContainer

# -- Constants --

const PLACEHOLDER_ICON: Texture2D = preload("res://data/rewards/icons/artifact_placeholder.svg")
const LEGENDARY_BAR_COLOR := Color(0.9, 0.76, 0.32)
const CURSE_BAR_COLOR := Color(0.88, 0.4, 0.52)
const MINOR_BAR_COLOR := Color(0.55, 0.55, 0.62)

# -- State --

var _row_data: Dictionary = { }

# -- Node references --

@onready var _icon_texture: TextureRect = %IconTexture
@onready var _rarity_bar: ColorRect = %RarityBar
@onready var _stack_badge: Control = %StackBadge
@onready var _stack_badge_label: Label = %StackBadgeLabel

# == Lifecycle ==


func _ready() -> void:
    if not _row_data.is_empty():
        _apply()

# == Common API ==


## Stores the `{ "artifact": Artifact, "stacks": int, "description": String }` row data this cell
## displays, refreshing immediately if already in the scene tree. Safe to call before or after
## add_child().
func setup(row_data: Dictionary) -> void:
    _row_data = row_data
    if is_node_ready():
        _apply()


## Re-paints the cell from its already-stored data. No-op before the cell enters the scene tree.
func refresh() -> void:
    if is_node_ready():
        _apply()

# == View ==


func _apply() -> void:
    var picked_artifact: Artifact = _row_data.get("artifact")
    if picked_artifact == null:
        ToastManager.show_dev_error("ArtifactStripItem: setup() called with no artifact in row data")
        return
    var stacks: int = _row_data.get("stacks", 1)
    _icon_texture.texture = _resolve_icon(picked_artifact)
    _stack_badge.visible = stacks > 1
    if stacks > 1:
        _stack_badge_label.text = "x%d" % stacks
    _rarity_bar.color = _bar_color_for(picked_artifact)
    tooltip_text = "%s\n%s" % [picked_artifact.display_name, _row_data.get("description", "")]


func _resolve_icon(picked_artifact: Artifact) -> Texture2D:
    if picked_artifact.icon != null:
        return picked_artifact.icon
    ToastManager.show_dev_error("ArtifactStripItem: artifact '%s' has no icon; using placeholder" % picked_artifact.id)
    return PLACEHOLDER_ICON


func _bar_color_for(picked_artifact: Artifact) -> Color:
    if picked_artifact.is_curse:
        return CURSE_BAR_COLOR
    if picked_artifact.rarity == Artifact.Rarity.LEGENDARY:
        return LEGENDARY_BAR_COLOR
    return MINOR_BAR_COLOR
