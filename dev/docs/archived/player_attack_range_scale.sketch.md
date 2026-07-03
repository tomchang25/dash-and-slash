# Player Attack Range Scale

## Goal

Move the player's normal-attack reach and dash travel distance off hardcoded constants onto run-mutable `PlayerStatsData` fields, with a shared hit-geometry scaling helper future weapon effects (Smash and beyond) can reuse instead of re-deriving hit-geometry math per attack.

## Requirements

1. Normal attack reach and dash travel distance scale independently through two separate stats, not one shared factor — they serve different build identities (melee reach vs. dash mobility/clear), and forcing them to share a number would remove that build-diversity axis from future reward choices.
2. The base offset distance normal attack currently hardcodes (`ATTACK_RANGE` in `player.gd`) becomes data on `PlayerStatsData`, matching how `normal_attack_damage`, `dash_attack_damage`, etc. already work — this is the literal ask behind "data-drive player attack range."
3. Scaling normal attack's range keeps the hitbox's collision shape and its paired VFX node visually in sync, since a swing that looks bigger or smaller than what actually connects breaks the hit-feedback trust the GDD calls out as non-negotiable (GDD v0.4 §2.2, §2.3). Dash's existing trail VFX (ghost, wind burst, speed lines) already track the player's real position each physics frame, so a longer dash travel distance stays in sync with its own visuals for free.
4. Normal attack and dash range are two different mechanisms, not one: normal attack range is a hit-geometry concern (hitbox offset + shape both scale, reused later by Smash's AoE), while dash range is a movement concern (how far the dash actually travels). Bundling them under one "hit geometry" helper — as an earlier pass at this sketch did — was a naming mistake; dash's hitbox already tracks the player's body one-for-one, so "dash range" has to mean travel distance, not hitbox size, to match what the GDD's "+dash range" reward line actually implies (grouped with dash damage/cooldown, i.e. describing the dash ability itself, not its hit geometry).
5. Range stats plug into the existing Minor reward pipeline the same way `normal_attack_damage` etc. do, needing no new reward infrastructure.

## Design

Two independent, run-mutable multiplier stats: `normal_attack_range_scale` and `dash_range_scale`, both defaulting to `1.0`. Minor reward effects add a delta to one or the other, same accrual pattern as existing damage/cooldown stats.

Normal attack's reach has two parts that must grow together: the distance the hitbox is placed away from the player (`aim_dir * attack_range * normal_attack_range_scale`), and the capsule shape's own footprint (uniform node scale). Growing only the offset would place a same-size swing further away and feel like it's whiffing; growing only the shape without the offset would just make attacks fatter in place. Both need to move together to read as "reach." Scaling is applied as a uniform `Node2D.scale` on the hitbox's `CollisionShape2D` and its paired VFX node, not by duplicating and resizing the underlying `Shape2D` resource — uniform scale sidesteps the known Godot pitfall (non-uniform scale distorting circle/capsule collision), and scaling a child `Area2D`/`CollisionShape2D` — as opposed to the player's own `CharacterBody2D` — is standard supported usage.

Dash's hitbox is centered on the player for the whole dash and already moves wherever the player moves, so there is nothing to offset or resize — the only thing "range" can mean here is how far the dash itself travels. `dash_range_scale` multiplies the effective dash speed (`DASH_SPEED * dash_range_scale`) while `DASH_DURATION` stays fixed, so travel distance grows without touching the timing everything else (i-frame window, ghost-trail interval, camera punch) is keyed off. A stacked-up dash build should feel like "I cover more ground per dash," not "my dash hitbox got fatter." Because this moves the player faster through space, very high stacked values raise the risk of the dash's `Area2D` overlap check skipping past a thin enemy within one physics frame (a discrete-collision tunneling risk, not a design question) — worth a sanity-check max clamp on `dash_range_scale`, mirroring the existing `MIN_DASH_COOLDOWN` clamp pattern.

Smash radius, chain count, and one-shot threshold (GDD v0.4 §7.4) stay out of this slice — they belong to the future `PlayerRunBuild` Major/Minor architecture (GDD §7.2, Milestone 3) and Smash doesn't exist as an ability yet. When Smash lands, its AoE radius reuses the normal-attack hit-geometry helper introduced here (offset/shape scaling), not the dash travel-distance mechanism.

## Sketch (non-normative)

`PlayerStatsData` additions:

```gdscript
@export var attack_range := 152.0              # moved from Player.ATTACK_RANGE const
@export var normal_attack_range_scale := 1.0   # Minor-effect-mutable multiplier, hit geometry
@export var dash_range_scale := 1.0            # Minor-effect-mutable multiplier, dash travel distance
```

`player.gd`: drop `ATTACK_RANGE` const (moves to data above); the unused `ATTACK_CAPSULE_RADIUS` / `ATTACK_CAPSULE_HEIGHT` consts are dead already (only the `.tscn` sub-resource values are load-bearing) and can just be deleted rather than migrated, since the scale-based approach never needs to read base shape dimensions in code.

```gdscript
# -- Hit geometry (normal attack today, Smash later) --

func _apply_range_scale(shape_node: Node2D, vfx_node: Node2D, scale: float) -> void:
    shape_node.scale = Vector2.ONE * scale
    if vfx_node != null:
        vfx_node.scale = Vector2.ONE * scale

func _position_attack_shape(aim_dir: Vector2) -> void:
    var scale := get_run_stats().normal_attack_range_scale
    _attack_hitbox.position = aim_dir * get_run_stats().attack_range * scale
    _attack_hitbox.rotation = aim_dir.angle() + PI / 2.0
    _apply_range_scale(_attack_hitbox_collision_shape, _attack_vfx, scale)

func add_attack_range(amount: float) -> void:
    if amount <= 0.0:
        return
    _ensure_run_stats()
    _run_stats.normal_attack_range_scale += amount

# -- Dash travel distance --

func get_dash_speed() -> float:
    _ensure_run_stats()
    return DASH_SPEED * _run_stats.dash_range_scale

func add_dash_range(amount: float) -> void:
    if amount <= 0.0:
        return
    _ensure_run_stats()
    _run_stats.dash_range_scale = min(_run_stats.dash_range_scale + amount, MAX_DASH_RANGE_SCALE)
```

`player_dash_state.gd`: both call sites currently reading `player.DASH_SPEED` directly (`_enter()` and `_physics_update()`) switch to `player.get_dash_speed()` so the scaled value is what actually drives `velocity`. `enable_dash_hitbox()` is untouched — dash's hitbox shape and position stay exactly as they are today.

Note: `_apply_range_scale` needs a node reference to the `AttackHitbox`'s `CollisionShape2D` child, not just the `Hitbox` (`Area2D`) itself — grab it via the existing `%CollisionShape2D` unique-name pattern already used elsewhere in `player.gd`, or expose it through `Hitbox.collision_shape` (already an `@export var collision_shape: Node` on the component).

`WaveRewardEffectDefinition.Kind` additions:

```gdscript
ADD_PLAYER_ATTACK_RANGE,
ADD_PLAYER_DASH_RANGE,
```

`WaveRewardApplier._apply_effect()` additions:

```gdscript
WaveRewardEffectDefinition.Kind.ADD_PLAYER_ATTACK_RANGE:
    if _player != null:
        _player.add_attack_range(effect.total_magnitude())
WaveRewardEffectDefinition.Kind.ADD_PLAYER_DASH_RANGE:
    if _player != null:
        _player.add_dash_range(effect.total_magnitude())
```

`wave_reward_choice_generator.gd`: register two Minor card definitions, e.g. `"attack_range_up"` / "Longer Reach" and `"dash_range_up"` / "Longer Dash", following the existing `attack_up` entry's shape (id, kind, tier, display name, description template, point value, magnitude, max stacks, min wave, allowed profiles).

Migration steps:

1. Add `attack_range`, `normal_attack_range_scale`, `dash_range_scale` to `PlayerStatsData`; remove the three now-redundant range/shape consts from `player.gd`.
2. Add the `_apply_range_scale` helper and wire it into `_position_attack_shape`; confirm `AttackVfx` scales in step with `AttackHitbox`.
3. Add `get_dash_speed()` and repoint `player_dash_state.gd`'s two `DASH_SPEED` reads at it; pick and add a `MAX_DASH_RANGE_SCALE` clamp constant.
4. Add `add_attack_range` / `add_dash_range` to `player.gd`.
5. Add the two new `Kind` entries, `WaveRewardApplier` branches, and reward-generator card entries.
6. Extend `test_player_stats.gd` with run-stat default/accrual coverage for both new stats (including the dash-range max clamp) and a reward-applier routing test, mirroring the existing dash-damage routing test.

## Non-Goals

1. No Smash radius, chain count, or one-shot threshold stat — deferred to the future Major/Minor build system.
2. No change to dash's hitbox shape, size, or centered positioning — only its travel distance scales.
3. No change to `Hitbox.set_collision_shape()` or the underlying `Shape2D` resources — normal attack scaling happens at the node-transform level only.
4. No continuous-collision / swept-shape fix for dash hit detection — the `MAX_DASH_RANGE_SCALE` clamp is a stopgap against tunneling at extreme stacks, not a general fix; revisit if playtesting still finds missed hits within the clamp.

## Acceptance Criteria

1. Normal attack's hitbox placement distance and shape size grow together when `normal_attack_range_scale` increases, and the VFX visually matches the hitbox at every scale.
2. Dash covers proportionally more distance per activation when `dash_range_scale` increases, while dash duration, hitbox size, and hitbox positioning stay unchanged.
3. A Minor reward can grant `normal_attack_range_scale` or `dash_range_scale` increases through the same reward flow as existing numeric Minor cards, without new reward infrastructure.
4. No player-facing behavior regresses at the default `1.0` scale — normal attack and dash behave exactly as they do today.
