# wave_reward_card.gd
# Reusable reward-offer card: paints one WaveRewardChoice's artifact identity onto pre-placed card
# nodes — icon, title, rarity/curse caption, stack-scaled description, and stack badge — and
# forwards presses via card_pressed. Visual formatting only: does not apply rewards, roll
# artifacts, pause the tree, or advance waves.
class_name WaveRewardCard
extends Button

signal card_pressed

# -- Constants --

const PLACEHOLDER_ICON: Texture2D = preload("res://data/rewards/icons/artifact_placeholder.svg")

# -- State --

var _choice: WaveRewardChoice = null

# -- Node references --

@onready var _icon_texture: TextureRect = %IconTexture
@onready var _title_label: Label = %TitleLabel
@onready var _caption_label: Label = %CaptionLabel
@onready var _description_label: Label = %DescriptionLabel
@onready var _stack_badge: Control = %StackBadge
@onready var _stack_badge_label: Label = %StackBadgeLabel

# == Lifecycle ==


func _ready() -> void:
    pressed.connect(func() -> void: card_pressed.emit())

    if _choice != null:
        _apply()

# == Common API ==


## Stores the choice this card represents and sets the card's disabled state, refreshing the view
## immediately if the card is already in the scene tree. Safe to call before or after add_child().
func setup(choice: WaveRewardChoice, disabled_state := false) -> void:
    _choice = choice
    disabled = disabled_state
    if is_node_ready():
        _apply()


## Re-paints the card from its already-stored choice. No-op before the card enters the scene tree.
func refresh() -> void:
    if is_node_ready():
        _apply()

# == View ==


func _apply() -> void:
    _title_label.text = _choice.title()
    _description_label.text = _choice.description()
    var picked_artifact := _choice.artifact()
    if picked_artifact == null:
        _caption_label.text = ""
        _icon_texture.texture = PLACEHOLDER_ICON
        _stack_badge.visible = false
        theme_type_variation = &""
        return
    var stacks := _choice.stack_count()
    _caption_label.text = _caption_for(picked_artifact)
    _icon_texture.texture = _resolve_icon(picked_artifact)
    _stack_badge.visible = stacks > 1
    if stacks > 1:
        _stack_badge_label.text = "x%d" % stacks
    theme_type_variation = _style_variation_for(picked_artifact)


func _resolve_icon(picked_artifact: Artifact) -> Texture2D:
    if picked_artifact.icon != null:
        return picked_artifact.icon
    ToastManager.show_dev_error("WaveRewardCard: artifact '%s' has no icon; using placeholder" % picked_artifact.id)
    return PLACEHOLDER_ICON


func _caption_for(picked_artifact: Artifact) -> String:
    if picked_artifact.is_curse:
        return "Curse"
    if picked_artifact.rarity == Artifact.Rarity.LEGENDARY:
        return "Major"
    return "Minor"


func _style_variation_for(picked_artifact: Artifact) -> StringName:
    if picked_artifact.is_curse:
        return &"RewardCardCurse"
    if picked_artifact.rarity == Artifact.Rarity.LEGENDARY:
        return &"RewardCardLegendary"
    return &""
