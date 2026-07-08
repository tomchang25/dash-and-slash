# build_inspection_artifact_row.gd
# Compact owned-artifact row for the build inspection panel: icon, display name, rarity/curse
# caption, stack badge, and stack-scaled description, sharing WaveRewardCard's visual language in
# a smaller footprint. Visual formatting only; row data comes from BuildInspectionFormatter.
class_name BuildInspectionArtifactRow
extends PanelContainer

# -- Constants --

const PLACEHOLDER_ICON: Texture2D = preload("res://data/rewards/icons/artifact_placeholder.svg")
const LEGENDARY_CAPTION_COLOR := Color(0.9, 0.76, 0.32)
const CURSE_CAPTION_COLOR := Color(0.88, 0.4, 0.52)

# -- State --

var _row_data: Dictionary = { }

# -- Node references --

@onready var _icon_texture: TextureRect = %IconTexture
@onready var _name_label: Label = %NameLabel
@onready var _caption_label: Label = %CaptionLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _stack_badge: Control = %StackBadge
@onready var _stack_badge_label: Label = %StackBadgeLabel

# == Lifecycle ==


func _ready() -> void:
    if not _row_data.is_empty():
        _apply()

# == Common API ==


## Stores the `{ "artifact": Artifact, "stacks": int, "description": String }` row data this row
## displays, refreshing immediately if already in the scene tree. Safe to call before or after
## add_child().
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
    var picked_artifact: Artifact = _row_data.get("artifact")
    if picked_artifact == null:
        ToastManager.show_dev_error("BuildInspectionArtifactRow: setup() called with no artifact in row data")
        return
    var stacks: int = _row_data.get("stacks", 1)
    _name_label.text = picked_artifact.display_name
    _description_label.text = _row_data.get("description", "")
    _icon_texture.texture = _resolve_icon(picked_artifact)
    _stack_badge.visible = stacks > 1
    if stacks > 1:
        _stack_badge_label.text = "x%d" % stacks
    _caption_label.text = _caption_for(picked_artifact)
    _caption_label.remove_theme_color_override("font_color")
    if picked_artifact.is_curse:
        _caption_label.add_theme_color_override("font_color", CURSE_CAPTION_COLOR)
    elif picked_artifact.rarity == Artifact.Rarity.LEGENDARY:
        _caption_label.add_theme_color_override("font_color", LEGENDARY_CAPTION_COLOR)


func _resolve_icon(picked_artifact: Artifact) -> Texture2D:
    if picked_artifact.icon != null:
        return picked_artifact.icon
    ToastManager.show_dev_error("BuildInspectionArtifactRow: artifact '%s' has no icon; using placeholder" % picked_artifact.id)
    return PLACEHOLDER_ICON


func _caption_for(picked_artifact: Artifact) -> String:
    if picked_artifact.is_curse:
        return "Curse"
    if picked_artifact.rarity == Artifact.Rarity.LEGENDARY:
        return "Major"
    return "Minor"
