**Entity layer legacy mixing after the tick conversion**

Status: Draft probe.

Decision: 02c step 5 has landed — the probe's gate is clear. Ready to promote into its own "tick purification" main plan; that promotion just hasn't happened yet. This probe also inherits the deletion sweep from the now-archived tick combat rework cutover, so nothing is orphaned by that archival.

The tick conversion left `game/entities/` and `common/gameplay/entity/` straddling two eras. The legacy real-time Player is an orphan: no scene instantiates `player.tscn` since the legacy arena scene was deleted, and its last production reference (the reward context's legacy `player` field) is already scheduled for deletion by consolidation child 02. `GridEnemy`'s dual-clock hybrid is now resolved: 02c step 5 deleted the real-time-only surface (the `_physics_process` chase path, the real-time cooldown `Timer` and its cycle-cooldown accessors, `set_facing()`, `get_move_speed()`, and every `_tick_engine == null` fallback branch), since production spawning always binds a tick engine before an enemy acts. What remains below is genuinely unclaimed.

What no in-flight plan claims — the residue this probe exists to hand off:

- **Entity base physics assumption** — `Entity` extends `CharacterBody2D` and fans a pooling protocol (`reset()` / `set_enabled()`) to component children. After cutover its only users are tick enemies, which move by cell snap plus visual tween and never use physics bodies; every enemy would carry a dead CharacterBody2D base.

- **Physics collision component chain** — enemy scenes still carry Area2D `Hurtbox` / `ContactHitbox` / `PuffHitbox` collision nodes, and `EnemyAttackController` / `EnemyPointAttackExecutor` still spawn per-tile physics `Hitbox` nodes, while `GridEnemy`'s own header states that tick-mode enemy-to-player damage resolves as a cell-membership check at detonation. Whether any of these hitboxes still deliver damage in tick flow, or survive only as guard-profile metadata carriers, is unverified.

- **Enemy thin layer** — `Enemy` between `Entity` and `GridEnemy` now only bridges `Health` signals and the `died` contract; whether any non-grid user (e.g. `DestructibleObject`) justifies keeping the layer is unsurveyed.

- **Dead autoload** — `WorldState` existed so the legacy arena could register the live player for provider queries; a repo-wide search finds zero remaining callers, so it belongs in the same purge survey.

Inherited from the archived rework cutover (its routing swap already shipped; these are the remaining deletion/cleanup tails, re-homed here so the cutover could close): delete the legacy real-time player path (`game/entities/player/` controller, states, tests, scene) and the tick-combat prototype folder (`game/scenes/prototype/tick_combat/`), each verified dead by search before removal; strip player-attack-hitbox and enemy-to-player hit-volume physics layers where no live consumer remains. The GDD v0.5 sync tail did not fit here and lives as a standalone chore.

One inversion was carved out and folded into consolidation child 04 (combat contracts) instead of waiting, because that child already reshapes the same take-hit pass-through: tick hit resolution reads `Hitbox.GuardDamageProfile.DASH` as its is-dash flag, making tick logic depend on a physics component's enum.

The discussion target, once the inherited cutover deletion tail below also lands: survey what legacy surface actually remains, then scope the tick purification main plan around the four facets above.

Open question: do the dynamically spawned per-tile hitboxes and the scene-authored contact hitboxes have any live damage role in tick flow, or are they fully replaced by detonation cell-membership checks?

Open question: what should `Entity` extend once no user needs a physics body — `Node2D`, or does the pooling protocol alone justify keeping a base class at all?

Open question: does anything outside the grid enemies still legitimately extend `Enemy` or `Entity` (destructible objects, future props), and does that change the slimming direction?
