# enemy_health_pressure_effect.gd
# Reward effect that adds future enemy max-health pressure, recorded on the
# run-scoped RunBuild store's enemy-health channel. Magnitude is authored as a
# percent; apply() converts it to the fraction WaveScaling's hp multiplier expects.
# Always offerable — carries no grid/player dependency.
class_name EnemyHealthPressureEffect
extends WaveRewardEffectDefinition

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.run_build.record(RunBuild.CH_ENEMY_HEALTH_PRESSURE, (magnitude / 100.0) * float(stacks))
