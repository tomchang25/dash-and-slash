# Reward Effect Rework — Unified Effect Objects & Run-Scoped Modifier Store

## Goal

Migrate the reward pipeline from a single effect-type enum branched on by three separate switch statements to one self-contained object per effect that owns its own offer-eligibility and application. All effect contributions — player stats and future-enemy pressure alike — land in one run-scoped modifier store (`RunBuild`); `Player` and `WaveController` each project their own values from it on read. Behavior-preserving: every effect that exists today is offered under the same risk tiers and produces identical results for any pick order.

## Relational Context

- `RunBuild` (new, `game/scenes/stages/run_build.gd`, `RefCounted`) is the single run-scoped owner of applied reward-effect contributions. It is pure data with no engine dependency: it holds an ordered entry list and exposes `record(channel, delta)` and `total(channel)`, where `total` sums the signed deltas of matching entries recomputed on demand. It owns the channel-name constants. It applies no clamps and holds no base values — each consumer owns its own base and clamp rules. The list form (not a single accumulator) is deliberate: it is what lets a future replace-mode effect (Phase 5) supersede earlier entries and what lets a future effect-summary display read applied effects back, so do not collapse it to a per-channel running total.
- `RunBuild` is constructed once per run by `DashAndSlashArena` (`game/scenes/stages/dash_and_slash_arena.gd`) and injected into three readers/writers: `Player`, `WaveController`, and the reward `WaveRewardContext`. A run restarts by full scene reload (`SceneRouter.go_to_arena()`), so a fresh `RunBuild` is created each run; `RunBuild.clear()` exists for tests and in-place reset, not for the production restart path.
- `WaveRewardContext` (new, `game/scenes/stages/rewards/wave_reward_context.gd`, `RefCounted`) is the one context shape both the generator (offer-eligibility) and the applier (application) read. It carries `grid: GridArena`, `player: Player`, and `run_build: RunBuild`. `DashAndSlashArena` builds it once and hands the same instance to `WaveRewardChoiceController`, which uses it both for rolling and for applying. This replaces the generator's old `{grid, player}` `Dictionary` and the applier's constructor-held owner references. Typed fields (not a Dictionary) are required so each effect reaches only the owner it legitimately mutates, per `dev/foundation/core/standards/runtime_ownership.md`.
- `WaveRewardEffectDefinition` (`game/scenes/stages/rewards/wave_reward_effect_definition.gd`) becomes an `@abstract` base holding only metadata (id, tier, display strings, point value, per-stack magnitude, stack cap, min wave, allowed profiles) plus the `Profile`/`Tier` enums and their query helpers. It gains a virtual `is_applicable(context) -> bool` defaulting to `true` and an `@abstract apply(context, stacks) -> void`. The `Kind` enum, the `kind` field, and the `init_kind` constructor argument are removed. Balance numbers stay authored as constructor arguments in the pool builder — never hardcoded as constants inside the subclasses.
- Effect subclasses live under `game/scenes/stages/rewards/effects/`. `PlayerStatEffect` (`@abstract`) is an intermediate base that overrides `is_applicable` once to require `context.player != null` and leaves `apply` abstract; its seven leaf subclasses each implement only a one-line `apply` that calls the matching `Player` mutator with `magnitude * stacks`. `FutureEnemyEffect` keeps the default always-true `is_applicable` and its `apply` records to `RunBuild`'s future-enemy channel. `MajorPlaceholderEffect` keeps the default `is_applicable` and implements an empty `apply`.
- `Player` (`game/entities/player/player.gd`) stays the sole gateway for player-stat mutation and keeps its seven narrow mutator methods as the effect-facing API — this is required because two mutations carry runtime side effects a pure store cannot own: reducing dash cooldown must re-clamp any in-flight cooldown to the newly projected maximum, and adding max health must push the same delta into the `Health` component. `Player` holds a required `RunBuild` reference injected by the arena before stat access; missing injection should fail fast rather than silently creating a divergent private store that would break the run-wide shared-store invariant. The six run-projected getters read `base + RunBuild.total(channel)` and apply their existing clamp at the final combined value. The mutators record a signed delta to `RunBuild` (reductions record negative) instead of mutating `_run_stats`; `_run_stats` becomes the immutable authored-base snapshot. `max_health` is not a `RunBuild` channel: `Health` is its runtime authority, so `add_max_health` only pushes the delta into `Health` and records nothing in the store.
- `WaveController` (`game/scenes/stages/waves/wave_controller.gd`) stops owning `_future_enemy_count_modifier` and its `add_future_enemy_count()` adder. It holds an injected `RunBuild` reference and, in `get_support_spawn_count()`, adds `int(max(0.0, RunBuild.total(future-enemy channel)))` on top of the `WaveScaling` formula. The `max(…, 0)` floor that the old adder applied per-call now applies at the read. `reset()` no longer zeroes pressure (the store owns it). This makes `WaveController` a reader of run-build truth rather than a second owner of pressure state — the promotion sanctioned by `runtime_ownership.md` §3 when state becomes cross-system truth.
- `WaveRewardApplier` (`game/scenes/stages/rewards/wave_reward_applier.gd`) collapses to a uniform loop: for each `WaveRewardEffect` in the choice, call `effect.apply(context)`. It holds no owners and no rng; the context is passed to `apply(choice, context)`. `WaveRewardEffect` (`wave_reward_effect.gd`) delegates `apply(context)` to `definition.apply(context, stacks)` and keeps `total_points`/`total_magnitude`/`description` unchanged.
- `WaveRewardChoiceGenerator` (`wave_reward_choice_generator.gd`) builds the pool from the subclasses, and `_is_definition_applicable` becomes `definition.is_applicable(context)` with its switch deleted. `roll_choices` takes a `WaveRewardContext` instead of a `Dictionary`. The point-budget roll math, profile constraints, and fallback path are untouched — this change is dispatch only.
- `WaveRewardChoiceController` (`wave_reward_choice_controller.gd`) receives the `WaveRewardContext` at construction (replacing its separate `grid`/`player` params), passes it to `roll_choices`, and passes it to `applier.apply`.

## Scope

### Included

- Convert `WaveRewardEffectDefinition` into an `@abstract` base plus a `PlayerStatEffect` intermediate and one leaf subclass per existing effect (seven player-stat, one future-enemy, one major placeholder), each owning `is_applicable`/`apply`.
- Dissolve the `Kind` enum and all three switch statements.
- Add `RunBuild` and `WaveRewardContext`; wire them through the arena into `Player`, `WaveController`, generator, applier, and controller.
- Reproject `Player`'s six run-stat getters and reroute its seven mutators through `RunBuild`, preserving every clamp and both documented side effects.
- Migrate the existing future-enemy-count effect to the `RunBuild` channel read; remove `WaveController._future_enemy_count_modifier`/`add_future_enemy_count()` and the arena's `_add_future_enemy_bonus` callback.

### Excluded

- The three new enemy-toughness pressure effects (health/damage/defense) — Phase 4.
- The Major cap/exclusivity specialization and any effect-identity tracking in `RunBuild` beyond numeric channels — Phase 5.
- Any change to the roll algorithm, point-budget constraints, or per-effect balance numbers.
- Any player-facing effect-summary display.
- Any change to `WaveScaling` or the milestone land-expansion grant.

## Files to Change

| File | Change Size | Purpose |
| --- | --- | --- |
| `game/scenes/stages/run_build.gd` | Medium (new) | Run-scoped channel store: signed-entry list, `record`/`total`/`clear`, channel-name constants. Pure data. |
| `game/scenes/stages/rewards/wave_reward_context.gd` | Small (new) | Typed context carrying `grid`, `player`, `run_build`; built once by the arena. |
| `game/scenes/stages/rewards/wave_reward_effect_definition.gd` | Large | Become the `@abstract` effect base: metadata + `Profile`/`Tier`, virtual `is_applicable`, abstract `apply`; drop `Kind`/`kind`/`init_kind`. |
| `game/scenes/stages/rewards/effects/` | Medium (new) | `player_stat_effect.gd` (`@abstract`) + seven player leaves + `future_enemy_effect.gd` + `major_placeholder_effect.gd`. |
| `game/scenes/stages/rewards/wave_reward_choice_generator.gd` | Medium | Pool builds subclasses; `_is_definition_applicable` → `is_applicable(context)`; `roll_choices` takes `WaveRewardContext`; roll math untouched. |
| `game/scenes/stages/rewards/wave_reward_applier.gd` | Medium | Collapse to `effect.apply(context)` loop; drop owner/rng constructor state; `apply(choice, context)`. |
| `game/scenes/stages/rewards/wave_reward_effect.gd` | Small | Add `apply(context)` delegating to the prototype; keep points/magnitude/description. |
| `game/scenes/stages/rewards/wave_reward_choice_controller.gd` | Small | Take `WaveRewardContext` at construction; use it for rolling and applying. |
| `game/entities/player/player.gd` | Medium | Hold injected `RunBuild`; reproject six getters; reroute seven mutators; `_run_stats` becomes base snapshot; preserve clamps and both side effects. |
| `game/scenes/stages/waves/wave_controller.gd` | Small | Read future-enemy pressure from `RunBuild`; remove the modifier field, adder, and reset line; add `RunBuild` injection. |
| `game/scenes/stages/dash_and_slash_arena.gd` | Small | Construct `RunBuild`; inject into player, wave controller, context; build `WaveRewardContext`; drop the future-enemy callback. |
| `test/unit/test_player_stats.gd` | Medium | Update applier/effect/context construction; add combined-reduction projection coverage. No existing assertion changes result. |
| `test/unit/test_wave_controller.gd` | Small | Replace `add_future_enemy_count` with `RunBuild` record + injection; reset test uses `RunBuild.clear()`. |

## Implementation Notes

- Read `dev/foundation/platforms/godot/skills/gdscript_abstract.md` before writing the `@abstract` base and `@abstract apply`. `PlayerStatEffect` stays `@abstract` because it inherits the still-abstract `apply`; only the leaves are concrete.
- Channel identifiers are `StringName` constants centralized on `RunBuild` (e.g. `CH_NORMAL_ATTACK_DAMAGE`, `CH_NORMAL_ATTACK_COOLDOWN`, `CH_DASH_ATTACK_DAMAGE`, `CH_DASH_COOLDOWN`, `CH_ATTACK_RANGE`, `CH_DASH_RANGE`, `CH_FUTURE_ENEMY_COUNT`). `Player` and `FutureEnemyEffect` reference these constants — no string literals at call sites. `max_health` has no channel.
- Cooldown reductions record a negative delta; the getter is `max(base + total, MIN)`. Dash-range records a positive delta; the getter caps with `min(base + total, MAX_DASH_RANGE_BONUS_PERCENT)`. For every effect that exists today the change from per-mutation clamping to final-value clamping is arithmetically identical because all current effects are monotonic — state this in a comment so a reviewer does not read it as a behavior change. The store/projection exists for the non-monotonic replace effects of later phases, not for any observable change now.
- Recompute `total(channel)` from the entry list on each read (or on each write into a small cache). Do not drive `Health` from any recomputed total: `add_max_health` pushes exactly the per-call delta to `Health`, independent of any store sum.
- Effect subclasses add no per-instance fields, so they inherit the base `_init` unchanged (minus the `kind` argument). The pool builder calls e.g. `NormalAttackDamageEffect.new(id, tier, name, template, points, magnitude, max_stacks, min_wave, profiles)`.
- Each new `.gd` needs the `# filename` + one-line-purpose header and `##` GDDoc on public/non-obvious methods. Run `python dev/tools/lint_standards.py --files <changed>` before finishing.

## Edge Cases

| Case | Expected Handling |
| --- | --- |
| The same stat mutation is applied more than once in a run. | The store accumulates all entries; the getter projects their full sum, identical to today's repeated addition. |
| Two cooldown reductions only breach a floor when combined. | The floor applies to the projected combined value, not to either entry. |
| Reducing dash cooldown while one is counting down. | The mutator re-clamps in-flight remaining cooldown to the newly projected maximum, identical to today. |
| Adding max health. | Pushes the per-call delta to `Health` only; records nothing in `RunBuild`. |
| Future-enemy pressure read before any is applied, or a negative total. | `WaveController` reads `int(max(0.0, total))`, matching the old per-call `max(amount, 0)` floor. |

## Acceptance Criteria

1. The effect-type enum and all three switch statements branching on it no longer exist; each effect's eligibility and application live on its own object.
2. Every effect that exists today is offered under the same risk tiers and applies identically to before the migration, including the future-enemy-count effect.
3. Every run-projected player stat returns the same value for any call sequence as today's direct-mutation approach, with contributions recorded in the store and every clamp and both side effects preserved.
4. Future-enemy pressure is read by `WaveController` from the shared run store; no wave-pressure modifier state or future-enemy callback remains outside that store.
