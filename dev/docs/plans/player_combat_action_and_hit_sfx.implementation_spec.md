# Player Combat Action And Hit SFX

Parent Plan: none (standalone spec)

## Goal

Add missing action whooshes for normal attacks and Dash, distinguish an unblocked Dash hit on a staggered enemy with a flesh stab, and add a dedicated layered Guard Break sound. Audio must follow the existing spatial event pipeline and remain correct for whiffs, blocked hits, and multi-target Dash.

## Summary

- Every legal committed normal attack and Dash plays one spatial whoosh at the player's action origin, whether it hits or whiffs. Both actions share one five-stream event built from `whoosh-001.wav` through `whoosh-005.wav` with repeat avoidance.
- Dash keeps existing blocked-hit audio. When Dash produces a stagger-burst/unblocked outcome, `stab_flesh.wav` replaces that victim's generic damaged sound; normal attack and Smash retain their current hit audio.
- Every Guard Break layers a dedicated event based on `window-break-sfx-333914.wav` over the existing generic Guard Break hit sound and VFX. Its gain is authored on the event resource and tuned down there if the source is too loud.

## Requirements

1. Every legal normal attack and Dash must play one whoosh even on a whiff because it communicates the committed action rather than hit confirmation.
2. Illegal or denied attacks and Dashes must play no whoosh.
3. A multi-target Dash must play one action whoosh total, not one per victim.
4. A Dash against a guarding enemy must preserve the current blocked-hit event and must not substitute the flesh stab.
5. A Dash that hits an already staggered/unblocked enemy and resolves as a stagger burst must replace that victim's generic damaged event with the flesh stab event.
6. Every Guard Break must add the dedicated breaking event while preserving the existing generic hit audio and Guard Break VFX.
7. All playback must use spatial audio events through the audio manager, with volume, pitch variation, stream choice, and limiting authored in event resources.

## Relational Context

- Root `assets/SFX/` is reference/vendor input only. Runtime WAV files must be copied into owned project asset folders without copying `.import` sidecars; no shipped resource may reference `res://assets/`.
- Existing shared whoosh streams 001–003 remain reusable. Streams 004–005 join the same shared preset asset family because the set is used by player combat while earlier entries are already shared by other audio events.
- `TickPlayer` owns the player-combat event references. Its scene assigns the shared normal/Dash whoosh event and Dash stagger-hit override.
- `TickActionController` owns legal action commitment. It plays one whoosh outside the Dash victim loop and supplies the Dash-only stagger-burst SFX override when applying Dash hits; normal attack and Smash do not supply that override.
- `GridEnemy` remains the owner of per-victim fallback hit feedback. Its hit path may accept an optional stagger-burst event override, but blocked, damaged, kill, and Guard Break selection remain enemy-side responsibilities.
- Guard Break is generic enemy feedback, not a Dash-only Major. Every base enemy scene assigns the dedicated break event; inherited Small-enemy variants receive it through their base scene.
- `TickCombatFeedback` continues layering only Major-specific Guard Shredder and Execution feedback. Do not move ordinary action whoosh or generic Guard Break playback into that Major presenter.
- Source gain differences are solved with each `SpatialAudioEvent.volume_db`, never a call-site multiplier or direct raw-stream playback.

## Scope

### Included

- Normal/Dash action whoosh, Dash stagger-burst flesh override, generic dedicated Guard Break layer, owned source copies, event resources, wiring, and focused behavior tests.

### Excluded

- Movement, footstep, normal-hit replacement, Smash audio changes, enemy attack audio, or final mastering of the whole SFX mix.
- Synthesizing replacement sounds through the UI-event YAML pipeline.

## Files to Change

| File                                                       | Change Size | Purpose                                                                                                  |
| ---------------------------------------------------------- | ----------- | -------------------------------------------------------------------------------------------------------- |
| `common/audio/presets/assets/whoosh-004.wav`               | New Binary  | Complete the shared whoosh variant set from the supplied reference source.                               |
| `common/audio/presets/assets/whoosh-005.wav`               | New Binary  | Complete the shared whoosh variant set from the supplied reference source.                               |
| `common/audio/presets/assets/stab_flesh.wav`               | New Binary  | Own the Dash stagger-burst hit source.                                                                   |
| `common/audio/presets/assets/window-break-sfx-333914.wav`  | New Binary  | Own the Guard Break source.                                                                              |
| `game/tick_arena/player/audio/normal_dash_whoosh.tres`     | New Small   | Define the five-stream spatial action event.                                                             |
| `game/tick_arena/player/audio/dash_stagger_hit.tres`       | New Small   | Define the Dash-only stagger-burst flesh event.                                                          |
| `common/audio/presets/sfx/default_guard_broken_audio.tres` | New Small   | Define the generic layered Guard Break event.                                                            |
| `game/tick_arena/player/tick_player.gd`                    | Small       | Expose player-owned whoosh and Dash stagger-hit events.                                                  |
| `game/tick_arena/player/tick_player.tscn`                  | Small       | Assign the two player-combat events.                                                                     |
| `game/tick_arena/combat/tick_action_controller.gd`         | Medium      | Play committed-action whooshes and pass the Dash-only stagger override.                                  |
| `game/entities/enemies/grid_enemy.gd`                      | Medium      | Select an optional stagger-burst override and layer dedicated Guard Break audio.                         |
| `game/entities/enemies/small_enemy.tscn`                   | Small       | Assign generic Guard Break audio to the Small-enemy base.                                                |
| `game/entities/enemies/charge_enemy.tscn`                  | Small       | Assign generic Guard Break audio.                                                                        |
| `game/entities/enemies/mode_enemy.tscn`                    | Small       | Assign generic Guard Break audio.                                                                        |
| `game/entities/enemies/puff_enemy.tscn`                    | Small       | Assign generic Guard Break audio.                                                                        |
| `test/unit/test_tick_action_controller_verbs.gd`           | Medium      | Cover one whoosh per committed action and none for denied actions.                                       |
| `test/unit/test_grid_enemy_hit_audio_selection.gd`         | New Medium  | Cover blocked preservation, Dash stagger override, generic fallback, and Guard Break layering selection. |

## Execution Outline

1. Copy the four missing WAV sources into the shared owned asset folder without sidecars, create the three spatial event resources, and wire player/enemy scene exports.
2. Add one action-whoosh call to the shared normal-attack resolution and one to legal Dash resolution outside the victim loop; cover hit, whiff, auto-attack, denied, and multi-target boundaries.
3. Thread an optional stagger-burst audio override through committed Dash hit application while leaving normal attack and Smash on generic feedback; add selection-focused tests.
4. Layer the dedicated Guard Break event in the generic enemy feedback branch, tune its event-level volume against the existing hit event, then run focused tests and standards lint.

## Implementation Notes

- Reuse existing owned whoosh 001–003 and add owned copies of 004–005. The whoosh event includes all five streams, keeps `avoid_repeat` enabled, and starts from the existing slash event's `-20 dB` playback level before any event-resource-only tuning.
- Play the normal-attack whoosh from the shared attack resolver so mouse confirm and auto-attack-on-move behave identically. Play it only after the attack is legally committed.
- Play the Dash whoosh at the pre-move player position after plan legality is confirmed and before moving the player. Empty-victim Dash still plays it.
- Pass `dash_stagger_hit_sfx_event` only for Dash. In enemy feedback, use it only for `STAGGER_BURST`; `BLOCKED` keeps `_get_blocked_hit_sfx()`, while ordinary `DAMAGED`, `KILL`, and non-Dash stagger bursts retain the generic damaged event.
- In `GUARD_BREAK`, preserve the current generic damaged event and VFX, then play the dedicated break event as an additional layer. Give the event its own limiter key so the generic hit limiter does not suppress it.
- Tune the window-break event down via `volume_db` until it is distinct without overpowering the base hit. Do not trim or rewrite the supplied source during this slice.

## Edge Cases

| Case                               | Expected Handling                                                          |
| ---------------------------------- | -------------------------------------------------------------------------- |
| Normal attack whiffs               | One whoosh, no hit event.                                                  |
| Dash crosses no enemy              | One whoosh, no hit event.                                                  |
| Dash crosses several enemies       | One whoosh; each victim resolves its own hit feedback.                     |
| Dash is denied                     | No whoosh or hit event.                                                    |
| Dash hits guarding enemy           | Existing blocked event remains.                                            |
| Dash hits staggered enemy          | Flesh stab replaces generic damaged audio for that stagger-burst victim.   |
| Normal attack hits staggered enemy | Existing generic stagger-burst audio remains.                              |
| Any attack breaks Guard            | Existing generic hit audio plus dedicated break event and Guard Break VFX. |

## Acceptance Criteria

1. Legal normal attacks and Dashes always produce exactly one audible whoosh, including whiffs, while denied actions remain silent.
2. The whoosh event selects among all five supplied variants without immediate repeats.
3. Multi-target Dash does not multiply the action whoosh.
4. Dash blocked hits retain blocked audio, while Dash stagger-burst hits use the flesh stab instead of generic damaged audio.
5. Every Guard Break audibly layers the dedicated break event without removing existing hit feedback or VFX.
6. All runtime resources reference owned project assets and all playback routes through spatial audio events and the audio manager.
