# enemy_damage_pressure_effect.gd
# Reward effect that adds future enemy outgoing-damage pressure, recorded on the
# run-scoped RunBuild store's enemy-damage channel. Magnitude is authored as a
# percent; apply() converts it to the fraction WaveScaling's damage multiplier expects.
# Always offerable — carries no grid/player dependency.
class_name EnemyDamagePressureEffect
extends WaveRewardEffectDefinition

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.run_build.record(RunBuild.CH_ENEMY_DAMAGE_PRESSURE, (magnitude / 100.0) * float(stacks))
