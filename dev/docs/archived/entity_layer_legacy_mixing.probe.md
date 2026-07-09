**Entity layer legacy mixing after the tick conversion**

Status: Draft probe.

Decision: resolved by `feat(combat): switch attacks to tile-based hit resolution` (2d002b1) — no tick purification main plan needed.

The tick conversion left `game/entities/` and `common/gameplay/entity/` straddling two eras. 02c step 5 had already resolved `GridEnemy`'s dual-clock hybrid. The tile-based hit resolution commit then cleared every remaining facet below in one pass, so the planned "survey and promote a tick purification main plan" step is no longer needed — there is nothing left to purify.

- **Entity base physics assumption** — resolved. `Entity` (`common/gameplay/entity/entity.gd`) now extends `Node2D`, not `CharacterBody2D`. The pooling protocol (`reset()` / `set_enabled()`) is the only thing the base class carries.

- **Physics collision component chain** — resolved. `hitbox.gd`, `hurtbox.gd`, and `enemy_point_attack_executor.gd` are deleted; no enemy scene carries `Hurtbox` / `ContactHitbox` / `PuffHitbox` Area2D nodes or spawns per-tile physics `Hitbox` nodes anymore. Damage resolves entirely through `TileDirectionResolver` / `TickHitResolver` cell-membership logic.

- **Enemy thin layer** — resolved. `DestructibleObject` (the only plausible non-grid user) was deleted in the same commit. `GridEnemy` is now the sole class extending `Enemy`, so the thin bridge layer has exactly one justified user.

- **Dead autoload** — resolved. `WorldState` is deleted; no autoload registration or remaining callers.

Inherited cutover deletion tail — also resolved: `game/entities/player/` (legacy real-time player controller, states, tests, scene) and `game/scenes/prototype/tick_combat/` no longer exist; player-attack-hitbox and enemy-to-player hit-volume physics layers are stripped repo-wide.

The `Hitbox.GuardDamageProfile.DASH` inversion called out for consolidation child 04 is moot — `Hitbox` itself no longer exists; tick hit resolution reads its is-dash flag through the tile-space combat contracts instead.

No open questions remain. This probe can be archived or deleted per the probe standard's graduation rule — the discussion became work, the work landed, and no plan was ever needed as an intermediate step.
