# future_enemy_effect.gd
# Reward effect that adds future enemy count pressure, recorded on the
# run-scoped RunBuild store's future-enemy channel. Always offerable — carries
# no grid/player dependency.
class_name FutureEnemyEffect
extends WaveRewardEffectDefinition

func apply(context: WaveRewardContext, stacks: int) -> void:
    context.run_build.record(RunBuild.CH_FUTURE_ENEMY_COUNT, magnitude * float(stacks))
