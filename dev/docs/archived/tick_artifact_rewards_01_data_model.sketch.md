# Tick Artifact Rewards 01: Data Model

Parent Plan: `tick_artifact_rewards.md`

## Goal

Replace the tier-split reward-effect class hierarchy with one composed artifact concept: an artifact carries identity plus a list of effect contributions, and rarity/stack/exclusivity/curse become data instead of subclasses. This is the foundation the roll, cadence, and inspection children read.

## Summary

- **Shape pressure:** The current reward model splits Minor and Major into parallel type paths, so adding or inspecting rewards requires understanding class hierarchy instead of one artifact concept.
- **Likely direction:** Use one artifact object with identity, rarity, stack/exclusivity/curse metadata, optional pacing gates, and a list of effect contributions. Contributions cover build-store channel amounts, mobility payload replacement, and mobility trigger activation.
- **Context cleanup:** The reward context likely drops its legacy real-time-player field during this pass, because the new artifact context should only need the grid and run build.
- **Expected result:** Existing reward behavior stays the same, but authored rewards become data-shaped artifacts with composed effects, one eligibility predicate, and one owned-artifact registry that later roll and inspection work can read.

## Sketch

Composition replaces inheritance — the artifact has effects rather than being a typed effect:

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

- A runtime owned artifact is likely `{ artifact, stacks }` using the current reward wrapper shape where possible; total-points helpers disappear with pricing, while description and stack math stay.
- The apply pipeline likely collapses to one loop over `artifact.effects`; verify whether the current applier class still earns its own file or should be inlined into the choice controller.
- Run-build state likely keeps the existing channel entries, mobility payload override, and mobility triggers, while the Major registry generalizes into an owned-artifact registry with a rarity-keyed legendary-slot cap.
- One eligibility predicate replaces split Minor/Major applicability: within minimum wave, not already owned if unique, no exclusivity conflict, and a free legendary slot for legendary artifacts.
- Candidate deletions to verify during spec writing: one-subclass-per-channel effects, the abstract Major layer, placeholder/test-only Major files, player-stat gate effects, the tiny reward applier, and the reward Tier enum.
- Context likely becomes `(grid, run_build)`; verify current construction sites and tests before deleting the legacy player field.
- Authoring can stay code-constructed in the current pool builder first; moving artifacts to `.tres` resources is a later follow-on.
- Curses are just artifacts whose contributions are negative or enemy-pressure channel amounts. Child 02 owns the curse-pool wiring, but this child owns the data shape that lets curses exist.

## Non-Goals

1. No roll, cadence, or curse-pool wiring — child 02.
2. No inspection UI — child 03.
3. No `.tres` data authoring migration in this child.

## Acceptance Criteria

1. One artifact type with a composed effect list replaces the tier hierarchy and every concrete effect subclass.
2. Smash, Guard Shredder, Execution, and Flowing Strike apply identically to today, now as authored artifacts.
3. The reward context carries no legacy player, and no build code references one.
4. RunBuild exposes one artifact registry with a rarity-keyed legendary cap and one eligibility predicate; lint and unit tests pass.
