# Tick Artifact Rewards 01: Data Model

## Goal

Replace the tier-split reward-effect class hierarchy with one composed artifact concept: an artifact carries identity plus a list of effect contributions, and rarity/stack/exclusivity/curse become data instead of subclasses. This is the foundation the roll, cadence, and inspection children read.

## Requirements

1. One artifact type replaces the `WaveRewardEffectDefinition` tier hierarchy; Minor and Major stop being separate classes and become the same concept with different data.
2. An artifact's behavior is a list of effect contributions, not a hard-coded `apply()` body, so a new reward is authored as data (identity + effect list) rather than a new subclass.
3. The run-wide Major cap generalizes to a rarity-keyed legendary-slot cap; offer eligibility becomes one rule for every artifact.
4. The legacy real-time-player seam leaves the reward context in the same pass, since the artifact context is being rebuilt anyway and no artifact reads a legacy player.

## Design

The offered content stays behaviorally identical to today's shipped pool (same channels, same amounts, same Major behaviors); only the class shape changes. Curses are just artifacts whose contributions are negative/pressure channel amounts — the curse pool wiring is child 02's concern, but the data shape that lets a curse exist lives here.

## Sketch (non-normative)

Composition replaces inheritance — the artifact *has* effects rather than *being* a typed effect:

```gdscript
# artifact.gd — one class, replaces WaveRewardEffectDefinition + every concrete effect subclass
class Artifact:
    id: StringName
    display_name: String
    description_template: String
    icon: Texture2D                     # one AI placeholder each
    rarity: Rarity                      # COMMON / RARE / LEGENDARY — roll weight + card color
    max_stacks: int                     # 1 = unique (old Major), N = stackable (old Minor)
    exclusivity_group: StringName       # &"" = none
    is_curse: bool                      # routes to the milestone curse pool
    min_wave: int                       # optional pacing knob, not the Major gate
    effects: Array[ArtifactEffect]

# artifact_effect.gd — three concrete kinds, replace one-subclass-per-channel
class ArtifactEffect (abstract):
    func apply(run_build, stacks) -> void

class ChannelArtifactEffect:            # old Minors + every curse
    channel: StringName
    amount: float
    unit_scale: float                   # 1.0 flat, 0.01 for percent-authored pressure channels
    func apply(rb, stacks): rb.record(channel, amount * unit_scale * stacks)

class PayloadArtifactEffect:            # old Smash
    payload: StringName
    func apply(rb, _stacks): rb.set_mobility_payload_override(payload)

class TriggerArtifactEffect:            # old Guard Shredder / Execution / Flowing Strike
    trigger: StringName
    func apply(rb, _stacks): rb.set_mobility_trigger(trigger, true)
```

- A runtime **owned artifact** is `{ artifact, stacks }` (today's `WaveRewardEffect` wrapper repurposed): `total_points`-style helpers disappear with pricing; `description()` and stack math stay.
- **Apply pipeline collapses** to one loop: `for e in artifact.effects: e.apply(run_build, stacks)`. `WaveRewardApplier` (a three-line loop class) is deleted; the choice controller inlines it.
- **RunBuild generalization:** keep `_entries` / `record` / `total`, `_mobility_payload_override`, and `_mobility_triggers` as-is. Rename/repurpose `_major_entries` + `MAJOR_CAP` into an owned-artifact registry with a legendary-slot cap keyed on rarity; `add_major`/`can_add_major`/`has_major`/`has_major_conflict` become `add_artifact`/`can_add_legendary`/`has_artifact`/`has_exclusivity_conflict`. Unique non-legendary artifacts still register for the "already owned" check.
- **One eligibility predicate** replaces `MajorEffect.is_applicable` and the Minor pass-through: `wave >= min_wave and not (max_stacks == 1 and owned) and not exclusivity_conflict and (rarity != LEGENDARY or legendary_slot_free)`.
- **Deletions:** every `*_effect.gd` channel subclass, `major_effect.gd`, `major_placeholder_effect.gd` (or move to test), `player_stat_effect.gd`, `attack_range_effect.gd`, `wave_reward_applier.gd`, and the `Tier` enum. The four Major subclasses (Smash/Guard Shredder/Execution/Flowing Strike) become authored `Artifact` instances with a `PayloadArtifactEffect` or `TriggerArtifactEffect`, not classes.
- **Context:** `WaveRewardContext` drops its legacy `player` field, becoming `(grid, run_build)`; `AttackRangeEffect` and its `PlayerStatEffect` gate go with it. Update the run controller's construction site and every unit-test call.
- **Authoring:** artifacts can stay code-constructed in a pool builder first (like today's `_make_default_effect_definitions`); moving them to `.tres` resources is a later follow-on, out of scope here.

## Non-Goals

1. No roll, cadence, or curse-pool wiring — child 02.
2. No inspection UI — child 03.
3. No `.tres` data authoring migration in this child.

## Acceptance Criteria

1. One artifact type with a composed effect list replaces the tier hierarchy and every concrete effect subclass.
2. Smash, Guard Shredder, Execution, and Flowing Strike apply identically to today, now as authored artifacts.
3. The reward context carries no legacy player, and no build code references one.
4. RunBuild exposes one artifact registry with a rarity-keyed legendary cap and one eligibility predicate; lint and unit tests pass.
