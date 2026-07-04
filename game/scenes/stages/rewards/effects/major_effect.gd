# major_effect.gd
# Abstract intermediate base for Major (behavior-changing) reward effects.
# Carries an exclusivity-group identifier and registers itself in the
# run-scoped RunBuild store on apply, so the store's cap and per-group
# exclusivity rules are enforced for every Major without further wiring.
@abstract
class_name MajorEffect
extends WaveRewardEffectDefinition

var exclusivity_group := ""

# == Lifecycle ==


func _init(
        init_effect_id: String,
        init_display_name: String,
        init_description_template: String,
        init_point_value: float,
        init_magnitude: float,
        init_max_stacks: int,
        init_min_wave: int,
        init_allowed_profiles: Array[int],
        init_exclusivity_group: String,
) -> void:
    super._init(
        init_effect_id,
        Tier.MAJOR,
        init_display_name,
        init_description_template,
        init_point_value,
        init_magnitude,
        init_max_stacks,
        init_min_wave,
        init_allowed_profiles,
    )
    exclusivity_group = init_exclusivity_group

# == Effect Contract ==


## Rejects offering this Major when the run-scoped store is at the cap, or
## when its non-empty exclusivity group already has a registered member.
func is_applicable(context: WaveRewardContext) -> bool:
    return context.run_build != null and context.run_build.can_add_major(exclusivity_group)


## Registers this Major in the run-scoped store. A rejected registration here
## signals a programmer error, since is_applicable is the pre-offer filter
## that should have already excluded a full or conflicting Major from being rolled.
func apply(context: WaveRewardContext, _stacks: int) -> void:
    if not context.run_build.add_major(effect_id, exclusivity_group):
        ToastManager.show_dev_error(
            "MajorEffect: %s rejected by RunBuild after passing is_applicable" % effect_id,
        )
