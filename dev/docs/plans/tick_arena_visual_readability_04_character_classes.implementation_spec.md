# Tick Arena Visual Readability 04: Mobility-Locked Character Classes

Parent Plan: `tick_arena_visual_readability_and_identity.md`

## Goal

Add Ninja and Viking as distinct run-start combat identities built around fixed class-exclusive Mobility, different Speed fill, readable player bodies and weapon cues, and Mobility-filtered Major rewards. Keep the shared one-cell normal attack unchanged so this slice proves class identity without simultaneously redesigning basic attack geometry.

## Summary

The tick arena gains one active character-class resource selected before a run and held constant until the next reset. Ninja is the default class: it uses the Green Ninja body, Katana attack cue, 20 base Speed fill, and Dash. Viking uses the Shaman body as a placeholder, Hammer attack cue, 10 base Speed fill, and Smash. Debug-only class buttons select the next run's class and restart cleanly; this slice does not add production character-selection UI.

Class Mobility is baseline data, not reward state. RunBuild stops owning or resetting a payload override, the Smash replacement artifact and PayloadArtifactEffect are removed, and action/preview/HUD/build inspection read the selected class's fixed Mobility. Normal attacks remain the current one-cell cardinal strike for both classes.

Artifacts gain optional required-Mobility eligibility. Guard Shredder, Execution, and Chain Dash require Dash and therefore appear only for Ninja. The existing Flowing Strike/Mobility Free Action content becomes Chain Dash: a Dash that produces any back-angle hit, guard break, hit on an already-staggered target, or kill refunds that Dash's world advancement, giving the player an immediate extra action opportunity without storing a separate move token. Viking has no class-exclusive Major in this slice; its Smash Knockback Major belongs to child 03 of the separate enemy-mobility plan, and normal milestone fallback behavior supplies Minors when no eligible Viking Major exists.

Player presentation uses the authored Character body sheets and CharacterAnimated weapon sheets. The body may display movement/feedback direction but never becomes combat-facing truth; the visible weapon/aim cue uses the exact resolved cardinal aim shared by preview and committed normal attacks. Attack VFX are presentation-only and never delay or schedule hit resolution.

## Relational Context

- TickArena is the composition authority for the active CharacterClassData reference. It distributes the same immutable resource to player, action, preview, run/reward, HUD, and build-inspection collaborators; no consumer copies class fields into a second mutable class store.
- CharacterClassData owns authored baseline identity: id, display name, base Speed fill, fixed Mobility id, body texture, and normal-attack weapon texture. RunBuild continues to own only acquired reward contributions, owned artifacts, and active artifact triggers.
- TickPlayer owns live Speed meter state. Its per-action gain uses the active class's base fill plus the existing Speed reward contribution and preserves the existing meter maximum, per-action cap, spend timing, eligible-action set, and free-action behavior.
- TickActionController and TickPreviewController dispatch/read the selected class's fixed Mobility. They must not query a reward-owned payload override, and normal attack commit/preview remain the same one-cell cardinal contract.
- TickPreviewController already owns the shared resolved aim used by preview. It also sends that resolved cardinal direction to the player visual presenter; the presenter must not calculate a raw mouse angle or create a competing aim result.
- Player body and weapon VFX are non-authoritative presentation. They may select frames or play one-shot cues but never schedule damage, world advancement, cooldowns, Smash windup, or class selection.
- Artifact.required_mobility is offer eligibility, not effect dispatch. An empty requirement remains generic; a non-empty requirement must equal the active class Mobility carried by WaveRewardContext before the artifact can be offered, and the selected class cannot change while that offer is pending.
- Dash-only triggers are applied and previewed only by Dash. Smash must no longer inherit Guard Shredder, Execution, or Chain Dash merely because their current trigger storage is payload-agnostic.
- Chain Dash reuses the existing per-action world-advance refund shape. It adds the already-staggered outcome as a qualifier but does not create a banked token, force the next verb to Move, auto-target, auto-dash, or grant more than one refund for a multi-victim Dash.
- Selecting a different class through debug controls first cancels armed Smash state, then applies the new class and performs the existing full run reset. Ordinary restart preserves the currently selected class while clearing RunBuild and live player state.
- Build inspection and HUD display class-owned Mobility without recording it as an acquired artifact or channel contribution. Viking's empty eligible Major pool must continue through the existing milestone Minor fallback rather than producing a disabled or empty offer.

## Scope

### Included

- Authored Ninja and Viking class resources with fixed stats, Mobility, body texture, and weapon VFX texture.
- Run-start class ownership, Ninja default, debug class selection, and reset behavior.
- Class-aware Speed fill, fixed Mobility dispatch/preview, HUD/build display, and reward eligibility.
- Sprite-based player body, resolved cardinal aim marker, and class weapon normal-attack VFX.
- Chain Dash conversion and Dash-only assignment of the existing Dash-themed Majors.
- Removal of reward-driven Mobility replacement.

### Excluded

- Production class-selection UI, unlocks, saves, or permanent progression.
- Normal-attack footprint variants, damage changes, or cooldown/windup changes.
- Samurai.
- Viking Smash Knockback or general forced-displacement behavior.
- Final Viking art; Shaman is an explicit placeholder.

## Files to Change

| File | Change Size | Purpose |
| ---- | ----------- | ------- |
| `data/player/definitions/character_class_data.gd` | New Medium | Define authored class identity, fixed Mobility constants, Speed fill, and presentation textures. |
| `game/tick_arena/player/data/ninja.tres` | New Small | Author Ninja with 20 Speed fill, Dash, Green Ninja body, and Katana weapon cue. |
| `game/tick_arena/player/data/viking.tres` | New Small | Author Viking with 10 Speed fill, Smash, Shaman placeholder body, and Hammer weapon cue. |
| `game/tick_arena/player/tick_player_visual_presenter.gd` | New Medium | Render class body, resolved cardinal aim marker, and one-shot weapon attack presentation without owning combat timing. |
| `game/tick_arena/player/tick_player.gd` | Medium | Hold the active class reference for player-owned Speed and visual presentation while preserving live meter/cooldown state ownership. |
| `game/tick_arena/tick_arena.tscn` | Medium | Wire class resources and persistent player visual nodes/presenter into the arena composition. |
| `game/tick_arena/tick_arena.gd` | Large | Own/distribute active class data, replace payload debug controls with class controls, coordinate class resets, and build class-aware HUD snapshots. |
| `game/tick_arena/combat/tick_action_controller.gd` | Medium | Dispatch fixed class Mobility, keep Dash-only triggers out of Smash, and play committed class weapon cues. |
| `game/tick_arena/combat/tick_preview_controller.gd` | Medium | Preview fixed class Mobility and forward the shared resolved cardinal aim to player presentation. |
| `game/tick_arena/combat/tick_combat_projection.gd` | Small | Rename the generic free-action read to Chain Dash semantics and keep Dash-specific trigger reads explicit. |
| `game/tick_arena/combat/tick_hit_resolver.gd` | Small | Extend the existing refund qualifier with already-staggered outcomes and name it for Chain Dash. |
| `game/tick_arena/run/run_build.gd` | Medium | Remove payload override state/API and rename the Mobility Free Action trigger as Chain Dash while preserving reward-channel and artifact ownership. |
| `game/tick_arena/run/tick_run_controller.gd` | Medium | Carry active class data into reward context and preserve it across ordinary run resets. |
| `game/tick_arena/reward/wave_reward_context.gd` | Small | Expose the active class Mobility to artifact eligibility. |
| `game/tick_arena/reward/build_inspection_formatter.gd` | Medium | Format class-owned Mobility separately from RunBuild totals. |
| `game/tick_arena/reward/build_inspection_panel.gd` | Small | Receive the active class alongside RunBuild for live inspection refreshes. |
| `game/tick_arena/hud/tick_arena_hud.gd` | Small | Render class name and the class-owned Mobility/cooldown chip from the root snapshot. |
| `game/tick_arena/hud/tick_arena_hud.tscn` | Small | Add a compact class identity label without destabilizing the status layout. |
| `data/rewards/definitions/artifact.gd` | Small | Add optional required-Mobility authoring and eligibility validation. |
| `data/rewards/definitions/effects/payload_artifact_effect.gd` | Delete | Remove the obsolete artifact path that replaced class Mobility. |
| `data/rewards/artifacts/smash.tres` | Delete | Remove Smash as a reward replacement because Viking owns Smash at baseline. |
| `data/rewards/artifacts/mobility_free_action.tres` | Delete | Replace generic Flowing Strike content with the Dash-only Chain Dash artifact. |
| `data/rewards/artifacts/chain_dash.tres` | New Small | Author the Dash-only Chain Dash Major and trigger. |
| `data/rewards/artifacts/guard_shredder.tres` | Small | Mark Guard Shredder as Dash-required. |
| `data/rewards/artifacts/execution.tres` | Small | Mark Execution as Dash-required. |
| `data/rewards/default_artifact_registry.tres` | Small | Remove Smash/Flowing Strike entries and catalog Chain Dash. |
| `test/unit/test_artifact_registry.gd` | Small | Update the default authored artifact ids and validation expectations. |
| `test/unit/test_build_inspection_formatter.gd` | Medium | Cover class-owned Mobility formatting without RunBuild payload state. |
| `test/unit/test_run_build_reset.gd` | Small | Remove payload-reset expectations while preserving reward/trigger reset coverage. |
| `test/unit/test_tick_player_speed_meter.gd` | Medium | Cover Ninja/Viking base fills, reward additions, caps, spend, and reset. |
| `test/unit/test_tick_action_controller_verbs.gd` | Medium | Cover class-fixed Dash/Smash dispatch and Chain Dash world-advance refunds. |
| `test/unit/test_tick_hit_resolver_mobility_free_action.gd` | Rename/Medium | Rename for Chain Dash and cover back, guard break, stagger, death, non-qualifiers, and multi-victim single-refund folding. |
| `test/unit/test_mobility_free_action_major_effect.gd` | Rename/Medium | Rename for Chain Dash and cover Dash requirement plus trigger application. |
| `test/unit/test_smash_major_effect.gd` | Delete | Remove replacement-artifact tests made obsolete by Viking's fixed Smash. |
| `test/unit/test_wave_reward_choice_generator.gd` | Medium | Prove Ninja receives only Dash Majors and Viking falls back cleanly when no Smash Major is eligible. |
| `test/unit/test_guard_shredder_major_effect.gd` | Small | Add Dash-required eligibility coverage. |
| `test/unit/test_execution_major_effect.gd` | Small | Add Dash-required eligibility coverage. |

## Execution Outline

1. Add CharacterClassData and the two authored resources first, including validation for non-empty ids, supported Mobility, positive Speed fill, and assigned presentation textures.
2. Make TickArena own and distribute the active class, update TickPlayer Speed projection, and add debug class switching through a full reset while keeping Ninja as the default and preserving the selected class on ordinary restart.
3. Switch action, preview, HUD, and inspection consumers from RunBuild payload state to the active class Mobility, then delete payload override state, its debug buttons, PayloadArtifactEffect, and the Smash replacement artifact.
4. Add persistent player visual nodes and the presenter, drive its aim from TickPreviewController's resolved cardinal direction, and play class-specific Katana/Hammer cues from committed normal attacks without changing one-cell hit resolution.
5. Add required-Mobility artifact eligibility, assign existing Dash Majors to Dash, replace Flowing Strike with Chain Dash, and restrict every Dash trigger/preview path so Smash cannot inherit it.
6. Update focused resource, reward, Speed, verb, resolver, HUD/formatter, and reset tests; then run standards lint and the narrow project test set covering the touched tick-arena units.

## Implementation Notes

- Use `assets/Ninja Adventure - Asset Pack/Actor/Character/NinjaGreen/SpriteSheet.png` and `assets/Ninja Adventure - Asset Pack/Actor/Character/Shaman/SpriteSheet.png` for bodies. Shaman must be labeled as placeholder Viking presentation in authored data/comments.
- Use `assets/Ninja Adventure - Asset Pack/Actor/CharacterAnimated/Weapon/Katana.png` and `assets/Ninja Adventure - Asset Pack/Actor/CharacterAnimated/Weapon/Hammer.png` for normal-attack presentation. Inspect their actual sheet layout during implementation; isolate frame-coordinate knowledge inside the presenter.
- Base Speed fill is 20 for Ninja and 10 for Viking. The existing Speed reward still adds 10 per stack and the existing per-action cap remains 75, so one Speed stack intentionally doubles Viking's baseline fill.
- Empty `required_mobility` means the artifact is class-generic. Do not encode class filtering by display name or infer it from artifact ids/descriptions.
- Chain Dash is the renamed replacement for the existing Mobility Free Action Major, not an additional fifth Legendary. Its qualifying Dash refunds at most one world advancement even when several victims qualify.
- Keep the current milestone offer's per-slot Minor fallback unchanged. Viking therefore receives valid Minor fallback choices until the enemy-mobility plan's child 03 adds its first Smash-required Major.
- Do not reuse `DirectionalSpriteFrameView` directly for the player; its visual-state and sheet-row contract is enemy-specific. Share only low-level frame-selection ideas if useful.

## Edge Cases

| Case | Expected Handling |
| ---- | ----------------- |
| Debug class switch while Smash is armed | Smash is cancelled before the class changes, then the run resets with no stale target or cooldown state. |
| Viking reaches a milestone before Smash Knockback exists | Ineligible Dash Majors are filtered out and existing Minor fallback fills the offer without disabled cards. |
| Chain Dash hits several qualifying enemies | The Dash refunds world advancement once, not once per victim. |
| Dash hits an already-staggered target from the front without killing it | Chain Dash still triggers because stagger is an independent qualifier. |
| Aim sits exactly diagonal or on the player cell | Weapon marker uses the same last-aim fallback as preview and commit. |
| Class texture is missing | Show a developer-visible error and retain the existing grey-box player fallback rather than rendering an invisible player. |

## Acceptance Criteria

1. A new arena starts as Ninja with Green Ninja body, Katana attack cue, 20 Speed fill, Dash, and the unchanged one-cell normal attack.
2. Debug selection restarts as Viking with Shaman placeholder body, Hammer attack cue, 10 Speed fill, Smash, and no residual Ninja or prior-run state.
3. Ordinary run restart preserves the selected class while clearing Speed, cooldowns, rewards, triggers, and armed Smash state.
4. Dash and Smash are class baselines and cannot be replaced by rewards or debug payload toggles.
5. Ninja can roll only Dash-required Majors; Viking cannot roll them and receives valid Minor fallback until a Smash Major exists.
6. Chain Dash refunds a qualifying Dash on back hit, guard break, already-staggered hit, or kill, at most once per Dash.
7. Player body, resolved cardinal aim marker, and Katana/Hammer attack cues communicate class and attack direction without creating player combat facing or delaying combat resolution.
8. Normal attack commit, preview, auto-attack-on-move, damage, and one-cell footprint remain unchanged for both classes.
