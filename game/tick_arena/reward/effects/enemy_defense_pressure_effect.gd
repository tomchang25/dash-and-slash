# enemy_defense_pressure_effect.gd
# Reward effect that adds future enemy flat-defense pressure, recorded on the
# run-scoped RunBuild store's enemy-defense channel. Magnitude is authored flat,
# matching the defense formula's own flat convention, and is recorded unconverted.
# Always offerable — carries no grid/player dependency.
class_name EnemyDefensePressureEffect
extends WaveRewardEffectDefinition

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.run_build.record(RunBuild.CH_ENEMY_DEFENSE_PRESSURE, magnitude * float(stacks))
