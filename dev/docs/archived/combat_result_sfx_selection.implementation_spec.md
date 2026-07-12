# Unified Combat Result SFX Selection

Parent Plan: none (standalone spec)

## Goal

Replace layered per-target combat SFX with a single, deterministic Result SFX for each resolved hit. Keep player action sounds and visual feedback intact while making Guard Break, death, mobility kills, and Majors immediately readable without competing audio.

## Summary

The current hit path plays generic damaged audio before health is reduced, then a kill immediately enters the Dead state and plays another death event. Guard Break also deliberately layers damaged and break events, while Major feedback adds a third event after hit resolution. This slice makes the resolved target outcome select one Result SFX instead.

| Resolved result                  | Result SFX                             |
| -------------------------------- | -------------------------------------- |
| Execution kill                   | Execution event                        |
| Dash or Smash kill               | `stab_flesh` mobility-kill event       |
| Other kill or non-combat death   | The enemy's existing death event       |
| Guard Shredder guard break       | Guard Shredder event                   |
| Ordinary guard break             | Guard Break event                      |
| Stagger burst or ordinary damage | Damaged event                          |
| Blocked hit                      | Existing angle-sensitive blocked event |
| Whiff                            | None                                   |

Action-origin sounds, including normal/Dash whooshes and Smash impact, remain separate from target-result feedback. Major VFX remains, but Major SFX moves into the single Result SFX selection so it no longer layers with a generic or death sound.

## Requirements

1. Every non-whiff player hit resolves to at most one target-result SFX, because the player should hear the combat result rather than several competing descriptions of the same target.
2. A kill must not play generic damaged audio; the Dead state plays exactly one selected death event instead.
3. Both mobility actions, Dash and Smash, use `stab_flesh` for ordinary mobility kills, while Execution retains priority and uses its existing event.
4. Guard Break uses only its dedicated break event, and Guard Shredder uses only its Major event; both retain their current VFX.
5. Death outside a committed player hit, including forced and debug deaths, retains the enemy's existing death event.
6. All target-result playback continues to use `SpatialAudioEvent` resources through `AudioManager.play_event()`.

## Relational Context

- The action controller resolves committed player hits and creates a per-action SFX context for Dash and Smash from player-owned event references; normal attacks pass no override context. The context is immutable input data, not a playback owner and not a second hit resolver.
- The enemy remains the single authority that maps a committed hit outcome plus its optional context to one target Result SFX. It must use the already-resolved outcome rather than call prediction or resolution a second time for audio.
- The enemy owns the transient selected death event between a lethal hit and Dead-state entry. It queues that event before damage is applied, because the health death signal transitions into the Dead state synchronously; it clears the queue when the damage does not actually kill the target.
- The Dead state remains the only death-audio caller. It asks the enemy to consume the queued death event, which falls back to the enemy's authored death event and clears the queue before playback so no prior override leaks into a later force or debug death.
- Non-lethal target feedback plays immediately from the enemy. Lethal target feedback queues death audio instead, but retains the existing full-damage VFX before the health transition.
- The combat-feedback presenter continues to receive every resolved outcome after the enemy hit call, but becomes VFX-only. It must not play Major audio, choose target-result audio, or retain a player audio-reference export.
- Player scenes own the mobility-kill, Guard Shredder, and Execution event assignments. Enemy scenes continue to own generic damaged, blocked, death, and Guard Break event assignments; missing optional special events fall back to the next applicable generic result event rather than producing silence.
- The former Dash stagger-burst event is renamed and repurposed as the shared mobility-kill event. Its `stab_flesh` source stays owned by the existing shared audio asset path and is not duplicated or regenerated.

## Scope

### Included

- A single-result SFX selection contract for player hits.
- Mobility-kill, Guard Shredder, Execution, Guard Break, ordinary hit, and death fallback selection.
- Dead-state consumption of a queued death override.
- Removal of Major SFX layering and Dash-only stagger-burst audio replacement.
- Focused selection and death-override lifecycle tests.

### Excluded

- Timing, assets, or mix tuning for action whooshes, Smash impact, enemy attacks, and UI audio.
- Changes to hit math, Major eligibility, VFX, death tween behavior, or rate-limit values beyond renaming the repurposed event's limiter key.
- New audio source files or the generated UI-event pipeline.

## Files to Change

| File                                                                                                      | Change Size | Purpose                                                                                                        |
| --------------------------------------------------------------------------------------------------------- | ----------- | -------------------------------------------------------------------------------------------------------------- |
| `game/tick_arena/combat/tick_hit_sfx_context.gd`                                                          | New Small   | Carry player-owned optional result-event overrides from a committed mobility action to one target hit.         |
| `game/entities/enemies/grid_enemy.gd`                                                                     | Large       | Select one result event, queue and consume lethal overrides, and preserve existing VFX behavior.               |
| `game/tick_arena/combat/tick_action_controller.gd`                                                        | Medium      | Build and pass mobility SFX contexts for Dash and Smash instead of the Dash stagger-burst override.            |
| `game/tick_arena/combat/tick_combat_feedback.gd`                                                          | Small       | Retain Major VFX and remove Major audio playback plus its player dependency.                                   |
| `game/tick_arena/player/tick_player.gd`                                                                   | Small       | Rename the player-owned Dash stagger event export to the shared mobility-kill event.                           |
| `game/tick_arena/player/tick_player.tscn`                                                                 | Small       | Rename and keep the player event assignment under its new mobility-kill meaning.                               |
| `game/tick_arena/tick_arena.tscn`                                                                         | Small       | Remove the combat-feedback presenter's obsolete player node-path assignment.                                   |
| `game/tick_arena/player/audio/dash_stagger_hit.tres` -> `game/tick_arena/player/audio/mobility_kill.tres` | Small       | Repurpose the existing `stab_flesh` spatial event and rename its limiter key for mobility kills.               |
| `test/unit/test_grid_enemy_hit_audio_selection.gd`                                                        | Medium      | Replace layered-event assertions with single-result priority, fallback, and death-override lifecycle coverage. |
| `TODO.md`                                                                                                 | Small       | Point the pending combat-audio work at this replacement standalone implementation spec.                        |

## Execution Outline

1. Introduce the lightweight hit SFX context and repurpose the player `stab_flesh` event as a mobility-kill event, then update player scene wiring.
2. Convert enemy target-result selection from event arrays to one selected event, adding the one-use queued death override while preserving existing non-audio feedback branches.
3. Pass one context from each committed mobility action, remove the Dash stagger-burst override, and make the post-hit Major presenter VFX-only with its scene wiring cleaned up.
4. Rewrite the focused audio-selection tests for the new priority table and queue-clearing behavior, update the TODO pointer, then run the standards linter on all changed Markdown, GDScript, scene, and resource files.

## Implementation Notes

- Result selection priority is Execution Major, mobility kill, default death, Guard Shredder Major, Guard Break, then the existing ordinary hit branches. A missing special event falls through to the next applicable event; a missing generic event remains silent.
- Execution outcomes are already lethal, and Guard Shredder outcomes are already Guard Break outcomes. Use the outcome's Major trigger to select the specialized event; do not infer a Major from action type alone.
- Queue a death event only for a resolved `KILL`; after applying damage, clear it if health is still alive. This covers invulnerability and the debug No-Damage or Undead modes, whose predicted damage can look lethal but must not affect a future death.
- The queued value is consumed and cleared before attempting playback, including when it is null or the selected resource is missing. `force_death()` therefore always begins with no stale override and falls back to authored enemy death audio.
- Keep `AudioManager.play_event()` as the sole playback route. Event gain, pitch, and limiting remain authored on resources; rename the repurposed event limiter from `dash_stagger_hit` to `mobility_kill` without altering its existing tuning.

## Edge Cases

| Case                                                            | Expected Handling                                                                           |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| A normal attack kills                                           | No damaged sound; one default enemy death event plays from the Dead state.                  |
| Dash or Smash kills                                             | No damaged sound; one `stab_flesh` mobility-kill event plays from the Dead state.           |
| Dash Execution kills                                            | One Execution event plays; it replaces the mobility-kill event.                             |
| Dash Guard Shredder breaks guard                                | One Guard Shredder event plays; it replaces the ordinary Guard Break event.                 |
| Ordinary Guard Break                                            | One Guard Break event plays with the existing Guard Break VFX.                              |
| A predicted kill is prevented by health mode or invulnerability | No death audio plays and the queued mobility or Major override is cleared.                  |
| Forced or debug death after any prevented hit                   | The enemy's default death event plays, never a stale special override.                      |
| Missing special event assignment                                | Fall back to the applicable mobility, generic Guard Break, damaged, or default death event. |

## Acceptance Criteria

1. Each resolved player hit produces no more than one target-result SFX, while action whooshes and Smash impact continue at their current action-level timing.
2. Ordinary damage, blocked hits, Guard Breaks, Guard Shredder, mobility kills, Execution kills, and default deaths each select the specified distinct result event without generic-hit layering.
3. Kills never emit damaged audio before their selected death audio.
4. Dash and Smash both use `stab_flesh` for non-Execution mobility kills.
5. Forced, debug, invulnerable, and debug-protected health paths cannot reuse a stale special death event.
6. Major and generic combat VFX remain visible, and all SFX playback continues through spatial audio events and the audio manager.
